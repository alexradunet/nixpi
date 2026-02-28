# Matrix channel module — matrix-bot-sdk bridge service for Matrix messaging.
#
# When enabled, a systemd service runs the pre-built Matrix bridge that
# connects matrix-bot-sdk to Pi print mode. Messages from allowed users are
# processed sequentially through Pi and responses sent back via Matrix.
#
# Optionally provisions a local Conduit homeserver (lightweight Rust Matrix
# server) for fully self-hosted operation.
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
    execStart = "${pkgs.nodejs_22}/bin/node dist/index.js";
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
      example = "/run/secrets/nixpi-matrix-token";
      description = ''
        Path to an EnvironmentFile containing NIXPI_MATRIX_ACCESS_TOKEN.
        This keeps the secret out of the Nix store.
      '';
    };

    allowedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "@alex:nixpi.local" ];
      description = ''
        Matrix user IDs allowed to message the agent (format: @localpart:domain).
        Empty list means all users are allowed (not recommended for production).
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
          allow_registration = false;
          allow_federation = false;
        };
      };

      # Conduit port accessible from Tailscale only
      networking.firewall.extraInputRules = ''
        # Allow Conduit (port 6167) from Tailscale only
        ip saddr 100.0.0.0/8 tcp dport 6167 accept
        ip6 saddr fd7a:115c:a1e0::/48 tcp dport 6167 accept
        tcp dport 6167 drop
      '';
    })
  ]);
}
