# VM test: Matrix bridge error handling and access control.
#
# Tests:
# 1. Unauthorized user is blocked (no response)
# 2. Pi command failure → error message returned
# 3. Service restart → bot resumes responding
{ pkgsUnstableForTests }:

{
  name = "vm-matrix-bridge-errors";

  nodes.machine = { config, pkgs, lib, ... }:
    let
      piMock = pkgs.writeShellScript "pi-mock" ''
        input="$2"
        case "$input" in
          *[Ee]rror*)
            echo "Pi crashed!" >&2
            exit 1
            ;;
          *)
            echo "ok: $input"
            ;;
        esac
      '';
    in
    {
      imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];

      nixpi.channels.matrix = {
        enable = true;
        humanUser = "testuser";
        conduit.allowRegistration = true;
        accessTokenFile = "/tmp/nixpi-matrix-token";
      };

      systemd.services.nixpi-matrix-bridge.serviceConfig.Environment = lib.mkForce [
        "PI_CODING_AGENT_DIR=${config.nixpi.piDir}"
        "NIXPI_OBJECTS_DIR=${config.nixpi.objects.dataDir}"
        "HOME=/home/${config.nixpi.primaryUser}"
        "NIXPI_REPO_ROOT=${config.nixpi.repoRoot}"
        "NIXPI_PI_COMMAND=${piMock}"
        "NIXPI_MATRIX_HOMESERVER=http://localhost:6167"
        "NIXPI_MATRIX_ALLOWED_USERS=@testuser:nixpi.local"
        "NIXPI_MATRIX_STORAGE_DIR=/var/lib/nixpi-matrix/storage"
        "NODE_ENV=production"
      ];

      systemd.services.nixpi-matrix-bridge.serviceConfig.EnvironmentFile = lib.mkForce [];
      systemd.services.nixpi-matrix-bridge.wantedBy = lib.mkForce [];

      system.activationScripts.testDirs = lib.stringAfter [ "users" ] ''
        install -d -o testuser -g users /home/testuser/Nixpi/.pi/agent
        install -d -o testuser -g users /home/testuser/Nixpi/data/objects
        chmod o+x /home/testuser /home/testuser/Nixpi /home/testuser/Nixpi/.pi /home/testuser/Nixpi/.pi/agent
        chmod o+x /home/testuser/Nixpi/data /home/testuser/Nixpi/data/objects
      '';

      environment.systemPackages = with pkgs; [ curl jq ];
    };

  testScript = let
    hs = "http://localhost:6167";
    sn = "nixpi.local";
  in ''
    import json, time

    HOMESERVER = "${hs}"
    SERVER_NAME = "${sn}"

    def write_json(path, data):
        payload = json.dumps(data)
        machine.succeed(f"printf '%s' {repr(payload)} > {path}")

    def register_user(username, password):
        write_json("/tmp/reg.json", {"username": username, "password": password})
        init = machine.succeed(
            "curl -s -X POST "
            + HOMESERVER
            + "/_matrix/client/v3/register "
            + "-H 'Content-Type: application/json' "
            + "-d @/tmp/reg.json"
        )
        resp = json.loads(init)
        if "access_token" in resp:
            return resp
        session = resp["session"]
        write_json("/tmp/reg.json", {
            "username": username,
            "password": password,
            "auth": {"type": "m.login.dummy", "session": session},
        })
        result = machine.succeed(
            "curl -sf -X POST "
            + HOMESERVER
            + "/_matrix/client/v3/register "
            + "-H 'Content-Type: application/json' "
            + "-d @/tmp/reg.json"
        )
        return json.loads(result)

    def matrix_api(method, path, token, data=None):
        cmd = (
            f"curl -sf -X {method} '{HOMESERVER}{path}' "
            f"-H 'Authorization: Bearer {token}' "
            f"-H 'Content-Type: application/json'"
        )
        if data is not None:
            write_json("/tmp/matrix_req.json", data)
            cmd += " -d @/tmp/matrix_req.json"
        return json.loads(machine.succeed(cmd))

    def wait_for_bot_join(room_id, bot_token, timeout=30):
        for _ in range(timeout):
            joined = matrix_api("GET", "/_matrix/client/v3/joined_rooms", bot_token)
            if room_id in joined.get("joined_rooms", []):
                return
            time.sleep(1)
        raise Exception(f"Bot did not join room {room_id} within {timeout}s")

    def get_bot_responses(room_id, token, timeout=15):
        """Collect bot responses from room messages within timeout."""
        responses = []
        for _ in range(timeout):
            msgs = matrix_api(
                "GET",
                f"/_matrix/client/v3/rooms/{room_id}/messages?dir=b&limit=20",
                token,
            )
            for event in msgs.get("chunk", []):
                sender = event.get("sender", "")
                body = event.get("content", {}).get("body", "")
                if sender == f"@nixpi:{SERVER_NAME}" and body:
                    responses.append(body)
            if responses:
                return responses
            time.sleep(1)
        return responses

    # --- Setup ---
    machine.wait_for_unit("conduit.service")
    machine.wait_for_open_port(6167)

    bot_resp = register_user("nixpi", "botpass123456789!")
    bot_token = bot_resp["access_token"]

    machine.succeed(
        f"printf 'NIXPI_MATRIX_ACCESS_TOKEN=%s' '{bot_token}' > /tmp/nixpi-matrix-token"
    )
    machine.succeed("chmod 644 /tmp/nixpi-matrix-token")
    machine.succeed(
        f"systemctl set-environment NIXPI_MATRIX_ACCESS_TOKEN={bot_token}"
    )
    machine.succeed("systemctl start nixpi-matrix-bridge")
    machine.wait_for_unit("nixpi-matrix-bridge.service")
    time.sleep(3)

    # --- Register authorized and unauthorized users ---
    human_resp = register_user("testuser", "humanpass123456789!")
    human_token = human_resp["access_token"]

    unauth_resp = register_user("eviluser", "evilpass123456789!")
    unauth_token = unauth_resp["access_token"]

    # --- Test 1: Unauthorized user is blocked ---
    unauth_room = matrix_api("POST", "/_matrix/client/v3/createRoom", unauth_token, {
        "preset": "private_chat",
        "name": "Unauthorized Room",
    })
    unauth_room_id = unauth_room["room_id"]
    matrix_api("POST", f"/_matrix/client/v3/rooms/{unauth_room_id}/invite", unauth_token, {
        "user_id": f"@nixpi:{SERVER_NAME}",
    })
    wait_for_bot_join(unauth_room_id, bot_token)

    matrix_api(
        "PUT",
        f"/_matrix/client/v3/rooms/{unauth_room_id}/send/m.room.message/txn_unauth",
        unauth_token,
        {"msgtype": "m.text", "body": "hack the planet"},
    )
    # Wait and verify NO response from bot
    time.sleep(10)
    responses = get_bot_responses(unauth_room_id, unauth_token, timeout=5)
    assert len(responses) == 0, f"Bot should not respond to unauthorized user, got: {responses}"

    # --- Test 2: Pi command failure → error message ---
    auth_room = matrix_api("POST", "/_matrix/client/v3/createRoom", human_token, {
        "preset": "private_chat",
        "name": "Error Test Room",
    })
    auth_room_id = auth_room["room_id"]
    matrix_api("POST", f"/_matrix/client/v3/rooms/{auth_room_id}/invite", human_token, {
        "user_id": f"@nixpi:{SERVER_NAME}",
    })
    wait_for_bot_join(auth_room_id, bot_token)

    matrix_api(
        "PUT",
        f"/_matrix/client/v3/rooms/{auth_room_id}/send/m.room.message/txn_error",
        human_token,
        {"msgtype": "m.text", "body": "trigger error"},
    )
    responses = get_bot_responses(auth_room_id, human_token, timeout=30)
    assert len(responses) > 0, "Bot should respond to error with error message"
    assert any("Sorry" in r or "error" in r.lower() for r in responses), (
        f"Expected error message from bot, got: {responses}"
    )

    # --- Test 3: Service restart → bot resumes responding ---
    machine.succeed("systemctl restart nixpi-matrix-bridge")
    machine.wait_for_unit("nixpi-matrix-bridge.service")
    time.sleep(3)

    resume_room = matrix_api("POST", "/_matrix/client/v3/createRoom", human_token, {
        "preset": "private_chat",
        "name": "Resume Test Room",
    })
    resume_room_id = resume_room["room_id"]
    matrix_api("POST", f"/_matrix/client/v3/rooms/{resume_room_id}/invite", human_token, {
        "user_id": f"@nixpi:{SERVER_NAME}",
    })
    wait_for_bot_join(resume_room_id, bot_token)

    matrix_api(
        "PUT",
        f"/_matrix/client/v3/rooms/{resume_room_id}/send/m.room.message/txn_resume",
        human_token,
        {"msgtype": "m.text", "body": "hello after restart"},
    )
    responses = get_bot_responses(resume_room_id, human_token, timeout=30)
    assert len(responses) > 0, "Bot should respond after service restart"
    assert any("ok: hello after restart" in r for r in responses), (
        f"Expected 'ok: hello after restart' from bot, got: {responses}"
    )
  '';
}
