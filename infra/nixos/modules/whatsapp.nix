# WhatsApp channel module — Baileys bridge service for WhatsApp messaging.
#
# When enabled, a systemd service runs the WhatsApp bridge that connects
# Baileys to Pi print mode. Messages from allowed numbers are processed
# sequentially through Pi and responses sent back via WhatsApp.
{ config, pkgs, lib, ... }:

let
  cfg = config.nixpi.channels.whatsapp;
  primaryUser = config.nixpi.primaryUser;
  repoRoot = config.nixpi.repoRoot;
  piDir = config.nixpi.piDir;
  bridgeDir = "${repoRoot}/services/whatsapp-bridge";
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

  config = lib.mkIf cfg.enable {
    systemd.services.nixpi-whatsapp = {
      description = "Nixpi WhatsApp bridge (Baileys → Pi)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = primaryUser;
        Group = "users";
        WorkingDirectory = bridgeDir;
        Environment = [
          "PI_CODING_AGENT_DIR=${piDir}"
          "NIXPI_OBJECTS_DIR=${config.nixpi.objects.dataDir}"
          "NIXPI_REPO_ROOT=${repoRoot}"
          "NIXPI_WHATSAPP_ALLOWED=${lib.concatStringsSep "," cfg.allowedNumbers}"
          "HOME=/home/${primaryUser}"
          "NODE_ENV=production"
        ];
        ExecStartPre = "${pkgs.nodejs_22}/bin/npm install --omit=dev";
        ExecStart = "${pkgs.nodejs_22}/bin/node dist/index.js";
        Restart = "on-failure";
        RestartSec = "30s";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
  };
}
