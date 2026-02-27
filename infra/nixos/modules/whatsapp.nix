# WhatsApp channel module — Baileys bridge service for WhatsApp messaging.
#
# When enabled, a systemd service runs the pre-built WhatsApp bridge that
# connects Baileys to Pi print mode. Messages from allowed numbers are
# processed sequentially through Pi and responses sent back via WhatsApp.
{ config, pkgs, lib, ... }:

let
  cfg = config.nixpi.channels.whatsapp;
  repoRoot = config.nixpi.repoRoot;

  whatsappBridge = import ../packages/whatsapp-bridge.nix { inherit pkgs; };
  bridgeLib = "${whatsappBridge}/lib/nixpi-whatsapp-bridge";

  mkNixpiService = import ../lib/mk-nixpi-service.nix { inherit config pkgs lib; };

  serviceConfig = mkNixpiService {
    name = "nixpi-whatsapp";
    description = "Nixpi WhatsApp bridge (Baileys → Pi)";
    serviceType = "simple";
    workingDirectory = bridgeLib;
    execStart = "${pkgs.nodejs_22}/bin/node dist/index.js";
    extraEnv = [
      "NIXPI_REPO_ROOT=${repoRoot}"
      "NIXPI_WHATSAPP_ALLOWED=${lib.concatStringsSep "," cfg.allowedNumbers}"
      "NODE_ENV=production"
    ];
    restart = "on-failure";
    restartSec = "30s";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    stateDirectory = "nixpi-whatsapp";
    readWritePaths = [ config.nixpi.piDir ];
  };
in
{
  options.nixpi.channels.whatsapp = {
    enable = lib.mkEnableOption "Nixpi WhatsApp channel (Baileys bridge)";

    allowedNumbers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "1234567890" "0987654321" ];
      description = ''
        Phone numbers allowed to message the agent (without country code prefix +).
        Empty list means all numbers are allowed (not recommended for production).
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    serviceConfig
    {
      assertions = [
        {
          assertion = cfg.allowedNumbers != [];
          message = "nixpi.channels.whatsapp.allowedNumbers must not be empty when the WhatsApp channel is enabled. Specify at least one allowed phone number.";
        }
      ];
    }
  ]);
}
