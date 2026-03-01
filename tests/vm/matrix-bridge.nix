# VM test: full Matrix bridge round-trip (Conduit → bridge → mock Pi → response).
#
# Boots a NixOS VM with Conduit + the matrix-bot-sdk bridge, registers
# human and bot accounts via the CS API, sends a message, and asserts
# the bot responds with echoed output from a mock Pi script.
{ pkgsUnstableForTests }:

{
  name = "vm-matrix-bridge";

  nodes.machine =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      piMock = pkgs.writeShellScript "pi-mock" ''
        # Scenario-based mock matching TypeScript PiScenario patterns.
        input="$2"
        case "$input" in
          *[Cc]reate*[Tt]ask*|*[Aa]dd*[Tt]ask*|*[Nn]ew*[Tt]ask*)
            echo "created task/my-task"
            echo "Title: my-task"
            echo "Status: open"
            ;;
          *[Ll]ist*[Tt]ask*|*[Ss]how*[Tt]ask*)
            echo "task/my-task — open"
            echo "task/another-task — done"
            ;;
          *[Hh]eartbeat*)
            echo "heartbeat logged at 2026-03-01T00:00:00Z"
            ;;
          *[Jj]ournal*)
            echo "created journal/2026-03-01"
            echo "Body captured."
            ;;
          *[Ee]rror*)
            echo "Sorry, I encountered an error processing your message. Please try again." >&2
            exit 1
            ;;
          *)
            echo "echo: $input"
            ;;
        esac
      '';
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
      systemd.services.nixpi-matrix-bridge.serviceConfig.EnvironmentFile = lib.mkForce [ ];

      # Disable auto-start so we control the lifecycle
      systemd.services.nixpi-matrix-bridge.wantedBy = lib.mkForce [ ];

      # Create required directories and make them traversable by nixpi-agent.
      # In production repoRoot is under the assistant user's home; in tests
      # it lives under testuser's home, so we open traversal for the service.
      system.activationScripts.testDirs = lib.stringAfter [ "users" ] ''
        install -d -o testuser -g users /home/testuser/Nixpi/.pi/agent
        install -d -o testuser -g users /home/testuser/Nixpi/data/objects
        chmod o+x /home/testuser /home/testuser/Nixpi /home/testuser/Nixpi/.pi /home/testuser/Nixpi/.pi/agent
        chmod o+x /home/testuser/Nixpi/data /home/testuser/Nixpi/data/objects
      '';

      # Tools for API calls in the test script
      environment.systemPackages = with pkgs; [
        curl
        jq
      ];
    };

  testScript =
    let
      # Inline the test as a let-binding to keep the Nix string clean.
      # All Python string literals use double quotes to avoid '' conflicts.
      hs = "http://localhost:6167";
      sn = "nixpi.local";
    in
    ''
      import json, time

      HOMESERVER = "${hs}"
      SERVER_NAME = "${sn}"

      def write_json(path, data):
          """Write a Python dict as JSON to a file inside the VM."""
          payload = json.dumps(data)
          # Escape for shell: write via printf to avoid quote issues
          machine.succeed(f"printf '%s' {repr(payload)} > {path}")

      def register_user(username, password):
          """Register a Matrix user via the CS API (UIA flow)."""
          # Step 1: initiate to get UIA session.
          # Use -s (not -sf) because UIA returns 401 which curl -f treats as error.
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

          # Step 2: complete with dummy auth
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
          """Call the Matrix CS API."""
          cmd = (
              f"curl -sf -X {method} '{HOMESERVER}{path}' "
              f"-H 'Authorization: Bearer {token}' "
              f"-H 'Content-Type: application/json'"
          )
          if data is not None:
              write_json("/tmp/matrix_req.json", data)
              cmd += " -d @/tmp/matrix_req.json"
          return json.loads(machine.succeed(cmd))

      # --- Wait for Conduit ---
      machine.wait_for_unit("conduit.service")
      machine.wait_for_open_port(6167)

      # --- Register bot account ---
      bot_resp = register_user("nixpi", "botpass123456789!")
      bot_token = bot_resp["access_token"]

      # --- Write token env and start the bridge ---
      machine.succeed(
          f"printf 'NIXPI_MATRIX_ACCESS_TOKEN=%s' '{bot_token}' > /tmp/nixpi-matrix-token"
      )
      machine.succeed("chmod 644 /tmp/nixpi-matrix-token")
      machine.succeed(
          f"systemctl set-environment NIXPI_MATRIX_ACCESS_TOKEN={bot_token}"
      )
      machine.succeed("systemctl start nixpi-matrix-bridge")
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

      def send_and_wait(room_id, human_token, txn_id, message, expected_substring, timeout=60):
          """Send a message and wait for the bot to respond with expected text."""
          matrix_api(
              "PUT",
              f"/_matrix/client/v3/rooms/{room_id}/send/m.room.message/{txn_id}",
              human_token,
              {"msgtype": "m.text", "body": message},
          )
          for _ in range(timeout):
              msgs = matrix_api(
                  "GET",
                  f"/_matrix/client/v3/rooms/{room_id}/messages?dir=b&limit=20",
                  human_token,
              )
              for event in msgs.get("chunk", []):
                  content = event.get("content", {})
                  sender = event.get("sender", "")
                  body = content.get("body", "")
                  if sender == f"@nixpi:{SERVER_NAME}" and expected_substring in body:
                      return body
              time.sleep(1)
          raise Exception(
              f"Bot did not respond with '{expected_substring}' to '{message}' within {timeout}s"
          )

      # --- Scenario 1: Echo fallback ---
      body = send_and_wait(room_id, human_token, "txn_echo", "hello from integration test", "echo:")
      assert "hello from integration test" in body, f"Echo mismatch: {body}"

      # --- Scenario 2: Task creation ---
      body = send_and_wait(room_id, human_token, "txn_task", "create a new task please", "created task/my-task")
      assert "Status: open" in body, f"Task response mismatch: {body}"

      # --- Scenario 3: Heartbeat ---
      body = send_and_wait(room_id, human_token, "txn_hb", "heartbeat", "heartbeat logged")
      assert "2026-03-01" in body, f"Heartbeat response mismatch: {body}"

      # --- Scenario 4: List tasks ---
      body = send_and_wait(room_id, human_token, "txn_list", "list all tasks", "task/my-task")
      assert "task/another-task" in body, f"List response mismatch: {body}"
    '';
}
