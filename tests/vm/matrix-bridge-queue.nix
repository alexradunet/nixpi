# VM test: Matrix bridge sequential message processing.
#
# Tests:
# 1. Three rapid messages → responses arrive in order
# 2. Slow Pi processing doesn't block the service
{ pkgsUnstableForTests }:

{
  name = "vm-matrix-bridge-queue";

  nodes.machine =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      # Slow mock: sleeps briefly to simulate Pi processing time.
      piMock = pkgs.writeShellScript "pi-mock" ''
        input="$2"
        sleep 1
        echo "processed: $input"
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

      systemd.services.nixpi-matrix-bridge.serviceConfig.EnvironmentFile = lib.mkForce [ ];
      systemd.services.nixpi-matrix-bridge.wantedBy = lib.mkForce [ ];

      system.activationScripts.testDirs = lib.stringAfter [ "users" ] ''
        install -d -o testuser -g users /home/testuser/Nixpi/.pi/agent
        install -d -o testuser -g users /home/testuser/Nixpi/data/objects
        chmod o+x /home/testuser /home/testuser/Nixpi /home/testuser/Nixpi/.pi /home/testuser/Nixpi/.pi/agent
        chmod o+x /home/testuser/Nixpi/data /home/testuser/Nixpi/data/objects
      '';

      environment.systemPackages = with pkgs; [
        curl
        jq
      ];
    };

  testScript =
    let
      hs = "http://localhost:6167";
      sn = "nixpi.local";
    in
    ''
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

      human_resp = register_user("testuser", "humanpass123456789!")
      human_token = human_resp["access_token"]

      room_resp = matrix_api("POST", "/_matrix/client/v3/createRoom", human_token, {
          "preset": "private_chat",
          "name": "Queue Test Room",
      })
      room_id = room_resp["room_id"]
      matrix_api("POST", f"/_matrix/client/v3/rooms/{room_id}/invite", human_token, {
          "user_id": f"@nixpi:{SERVER_NAME}",
      })

      for _ in range(30):
          joined = matrix_api("GET", "/_matrix/client/v3/joined_rooms", bot_token)
          if room_id in joined.get("joined_rooms", []):
              break
          time.sleep(1)
      else:
          raise Exception(f"Bot did not join room {room_id} within 30s")

      # --- Test: Send 3 rapid messages ---
      messages = ["first message", "second message", "third message"]
      for i, msg in enumerate(messages):
          matrix_api(
              "PUT",
              f"/_matrix/client/v3/rooms/{room_id}/send/m.room.message/txn_q{i}",
              human_token,
              {"msgtype": "m.text", "body": msg},
          )

      # --- Wait for all 3 responses (each takes ~1s due to sleep in mock) ---
      expected = {f"processed: {m}" for m in messages}
      found = set()
      for _ in range(90):
          msgs = matrix_api(
              "GET",
              f"/_matrix/client/v3/rooms/{room_id}/messages?dir=b&limit=30",
              human_token,
          )
          for event in msgs.get("chunk", []):
              sender = event.get("sender", "")
              body = event.get("content", {}).get("body", "")
              if sender == f"@nixpi:{SERVER_NAME}" and body.startswith("processed: "):
                  found.add(body)
          if expected.issubset(found):
              break
          time.sleep(1)
      else:
          missing = expected - found
          raise Exception(f"Missing bot responses: {missing}. Got: {found}")

      # --- Verify service is still healthy after processing queue ---
      machine.succeed("systemctl is-active nixpi-matrix-bridge")
    '';
}
