# VM test: full Matrix bridge round-trip (Conduit → bridge → mock Pi → response).
#
# Boots a NixOS VM with Conduit + the matrix-bot-sdk bridge, registers
# human and bot accounts via the CS API, sends a message, and asserts
# the bot responds with echoed output from a mock Pi script.
{ pkgsUnstableForTests }:

{
  name = "vm-matrix-bridge";

  nodes.machine = { config, pkgs, lib, ... }:
    let
      piMock = pkgs.writeShellScript "pi-mock" ''echo "echo: $2"'';
    in
    {
      imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];

      # Enable Matrix channel with registration open for test setup
      nixpi.channels.matrix = {
        enable = true;
        humanUser = "testuser";
        conduit.allowRegistration = true;
        accessTokenFile = "/tmp/nixpi-matrix-token";
      };

      # Override the Pi command in the bridge service to use our mock
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

      # Don't fail on missing token file at service start — we write it during the test
      systemd.services.nixpi-matrix-bridge.serviceConfig.EnvironmentFile = lib.mkForce [];

      # Ensure the bridge can start without the token (we restart it after writing one)
      # and disable auto-start so we control the lifecycle
      systemd.services.nixpi-matrix-bridge.wantedBy = lib.mkForce [];

      # Create required directories via activation script
      system.activationScripts.testDirs = lib.stringAfter [ "users" ] ''
        install -d -o testuser -g users /home/testuser/Nixpi/.pi/agent
        install -d -o testuser -g users /home/testuser/Nixpi/data/objects
      '';

      # Tools for API calls in the test script
      environment.systemPackages = with pkgs; [ curl jq ];
    };

  testScript = ''
    import json, time

    HOMESERVER = "http://localhost:6167"
    SERVER_NAME = "nixpi.local"

    def register_user(username, password):
        """Register a Matrix user via the CS API (UIA flow)."""
        # Step 1: initiate to get UIA session
        init = machine.succeed(
            f'curl -sf -X POST {HOMESERVER}/_matrix/client/v3/register '
            f'-H "Content-Type: application/json" '
            f'''-d '{{"username": "{username}", "password": "{password}"}}'  '''
        )
        resp = json.loads(init)

        # If server returned access_token directly, done
        if "access_token" in resp:
            return resp

        # Step 2: complete with dummy auth
        session = resp["session"]
        result = machine.succeed(
            f'curl -sf -X POST {HOMESERVER}/_matrix/client/v3/register '
            f'-H "Content-Type: application/json" '
            f'''-d '{{"username": "{username}", "password": "{password}", "auth": {{"type": "m.login.dummy", "session": "{session}"}}}}'  '''
        )
        return json.loads(result)

    def matrix_api(method, path, token, data=None):
        """Call the Matrix CS API."""
        cmd = f'curl -sf -X {method} {HOMESERVER}{path} -H "Authorization: Bearer {token}" -H "Content-Type: application/json"'
        if data is not None:
            payload = json.dumps(data).replace("'", "'\\''")
            cmd += f" -d '{payload}'"
        return json.loads(machine.succeed(cmd))

    # --- Wait for Conduit ---
    machine.wait_for_unit("conduit.service")
    machine.wait_for_open_port(6167)

    # --- Register bot account ---
    bot_resp = register_user("nixpi", "botpass123456789!")
    bot_token = bot_resp["access_token"]

    # --- Write token file and start the bridge ---
    machine.succeed(f'echo "NIXPI_MATRIX_ACCESS_TOKEN={bot_token}" > /tmp/nixpi-matrix-token')
    machine.succeed("chmod 644 /tmp/nixpi-matrix-token")

    # Set the token in the service environment and start it
    machine.succeed(
        f'systemctl set-environment NIXPI_MATRIX_ACCESS_TOKEN={bot_token}'
    )
    machine.succeed(
        'systemctl start nixpi-matrix-bridge'
    )
    machine.wait_for_unit("nixpi-matrix-bridge.service")

    # Give the bridge time to connect and start syncing
    time.sleep(3)

    # --- Register human account ---
    human_resp = register_user("testuser", "humanpass123456789!")
    human_token = human_resp["access_token"]

    # --- Human creates a room and invites bot ---
    room_resp = matrix_api("POST", "/_matrix/client/v3/createRoom", human_token, {
        "preset": "private_chat",
        "name": "Test Room",
    })
    room_id = room_resp["room_id"]

    matrix_api("POST", f"/_matrix/client/v3/rooms/{room_id}/invite", human_token, {
        "user_id": f"@nixpi:{SERVER_NAME}",
    })

    # Wait for bot to auto-join (AutojoinRoomsMixin)
    for _ in range(30):
        joined = matrix_api("GET", "/_matrix/client/v3/joined_rooms", bot_token)
        if room_id in joined.get("joined_rooms", []):
            break
        time.sleep(1)
    else:
        raise Exception(f"Bot did not join room {room_id} within 30s")

    # --- Human sends a message ---
    txn_id = "test_txn_001"
    matrix_api(
        "PUT",
        f"/_matrix/client/v3/rooms/{room_id}/send/m.room.message/{txn_id}",
        human_token,
        {"msgtype": "m.text", "body": "hello from integration test"},
    )

    # --- Poll for bot response ---
    bot_replied = False
    for _ in range(60):
        msgs = matrix_api(
            "GET",
            f"/_matrix/client/v3/rooms/{room_id}/messages?dir=b&limit=10",
            human_token,
        )
        for event in msgs.get("chunk", []):
            content = event.get("content", {})
            sender = event.get("sender", "")
            body = content.get("body", "")
            if sender == f"@nixpi:{SERVER_NAME}" and "echo:" in body:
                assert "hello from integration test" in body, (
                    f"Expected echoed input in bot response, got: {body}"
                )
                bot_replied = True
                break
        if bot_replied:
            break
        time.sleep(1)

    assert bot_replied, "Bot did not respond with echoed message within 60s"
  '';
}
