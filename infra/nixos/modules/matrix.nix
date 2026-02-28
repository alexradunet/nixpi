# Matrix channel module — matrix-bot-sdk bridge service for Matrix messaging.
#
# When enabled, a systemd service runs the pre-built Matrix bridge that
# connects matrix-bot-sdk to Pi print mode. Messages from allowed users are
# processed sequentially through Pi and responses sent back via Matrix.
#
# Optionally provisions a local Conduit homeserver (lightweight Rust Matrix
# server) for fully self-hosted operation.
#
# Setup flow:
#   1. Enable with conduit.allowRegistration = true
#   2. nixos-rebuild switch
#   3. Run: scripts/matrix-setup.sh
#   4. Set conduit.allowRegistration = false
#   5. nixos-rebuild switch
{ config, pkgs, lib, ... }:

let
  cfg = config.nixpi.channels.matrix;
  repoRoot = config.nixpi.repoRoot;

  matrixBridge = import ../packages/matrix-bridge.nix { inherit pkgs; };
  bridgeLib = "${matrixBridge}/lib/nixpi-matrix-bridge";

  mkNixpiService = import ../lib/mk-nixpi-service.nix { inherit config pkgs lib; };

  serviceConfig = mkNixpiService {
    name = "nixpi-matrix-bridge";
    description = "Nixpi Matrix bridge (matrix-bot-sdk → Pi)";
    serviceType = "simple";
    workingDirectory = bridgeLib;
    execStart = "${lib.getExe pkgs.nodejs_22} dist/index.js";
    extraEnv = [
      "NIXPI_REPO_ROOT=${repoRoot}"
      "NIXPI_PI_COMMAND=${config.nixpi._internal.piWrapperBin}"
      "NIXPI_MATRIX_HOMESERVER=${cfg.homeserverUrl}"
      "NIXPI_MATRIX_ALLOWED_USERS=${lib.concatStringsSep "," cfg.allowedUsers}"
      "NIXPI_MATRIX_STORAGE_DIR=/var/lib/nixpi-matrix/storage"
      "NODE_ENV=production"
    ];
    restart = "on-failure";
    restartSec = "30s";
    after = [ "network-online.target" ] ++ lib.optional cfg.conduit.enable "conduit.service";
    wants = [ "network-online.target" ] ++ lib.optional cfg.conduit.enable "conduit.service";
    wantedBy = [ "multi-user.target" ];
    stateDirectory = "nixpi-matrix";
    readWritePaths = [ config.nixpi.piDir ];
  };
in
{
  # `channels` namespace is intentional — future channel adapters (Telegram,
  # Signal, etc.) would live under nixpi.channels.<name>.
  options.nixpi.channels.matrix = {
    enable = lib.mkEnableOption "Nixpi Matrix channel (matrix-bot-sdk bridge)";

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "nixpi.local";
      example = "matrix.example.com";
      description = ''
        Matrix server name used by Conduit. This is the domain part of Matrix
        user IDs (e.g. @user:nixpi.local).
      '';
    };

    homeserverUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:6167";
      example = "https://matrix.example.com";
      description = ''
        URL of the Matrix homeserver the bridge connects to.
      '';
    };

    accessTokenFile = lib.mkOption {
      type = lib.types.path;
      default = "/run/secrets/nixpi-matrix-token";
      example = "/run/secrets/nixpi-matrix-token";
      description = ''
        Path to an EnvironmentFile containing NIXPI_MATRIX_ACCESS_TOKEN.
        This keeps the secret out of the Nix store. Created by scripts/matrix-setup.sh.
      '';
    };

    humanUser = lib.mkOption {
      type = lib.types.str;
      default = "human";
      example = "alex";
      description = ''
        Matrix localpart for the human user account. The full Matrix ID
        will be @<humanUser>:<serverName>. Change this to your preferred
        username before running scripts/matrix-setup.sh.
      '';
    };

    botUser = lib.mkOption {
      type = lib.types.str;
      default = "nixpi";
      example = "assistant";
      description = ''
        Matrix localpart for the bot account. The full Matrix ID will be
        @<botUser>:<serverName>. The bridge authenticates as this user.
      '';
    };

    allowedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "@${cfg.humanUser}:${cfg.serverName}" ];
      example = [ "@alex:nixpi.local" ];
      description = ''
        Matrix user IDs allowed to message the agent (format: @localpart:domain).
        Defaults to the configured humanUser on the configured serverName.
      '';
    };

    conduit = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to provision a local Conduit Matrix homeserver.
          Disable if using an external homeserver.
        '';
      };

      allowRegistration = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Temporarily enable Matrix account registration on Conduit.
          Set to true before running scripts/matrix-setup.sh, then set
          back to false and rebuild.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    serviceConfig
    {
      # Inject access token via EnvironmentFile (keeps secret out of Nix store)
      systemd.services.nixpi-matrix-bridge.serviceConfig.EnvironmentFile = cfg.accessTokenFile;

      assertions = [
        {
          assertion = cfg.allowedUsers != [];
          message = "nixpi.channels.matrix.allowedUsers must not be empty when the Matrix channel is enabled. Specify at least one allowed Matrix user ID.";
        }
      ];
    }
    # Optional local Conduit homeserver
    (lib.mkIf cfg.conduit.enable {
      services.matrix-conduit = {
        enable = true;
        settings.global = {
          server_name = cfg.serverName;
          database_backend = "rocksdb";
          port = 6167;
          address = "127.0.0.1";
          allow_registration = cfg.conduit.allowRegistration;
          allow_federation = false;
        };
      };

      # Conduit port accessible from Tailscale only
      networking.firewall.extraInputRules = let mkRules = config.nixpi._internal.mkTailscaleFirewallRules; in ''
        # Allow Conduit (port 6167) from Tailscale only
        ${mkRules { port = 6167; }}
      '';
    })
  ]);
}
