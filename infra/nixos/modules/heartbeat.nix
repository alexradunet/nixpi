# Heartbeat module — periodic agent wake cycle via systemd timer.
#
# When enabled, a systemd timer fires at the configured interval and runs
# a Pi non-interactive session with the heartbeat skill. The agent observes
# recent objects, checks overdue tasks, writes reflections, and detects
# evolution opportunities.
{ config, pkgs, lib, ... }:

let
  cfg = config.nixpi.heartbeat;
  repoRoot = config.nixpi.repoRoot;

  mkNixpiService = import ../lib/mk-nixpi-service.nix { inherit config pkgs lib; };

  heartbeatPrompt = ''
    You are running in heartbeat mode — a periodic wake cycle.

    Run the heartbeat skill. Review recent objects, check for overdue tasks,
    note patterns, and decide if any action is needed. Be brief. If nothing
    needs attention, say so and exit.
  '';

  piWrapper = pkgs.writeShellScript "nixpi-heartbeat-run" ''
    set -euo pipefail
    export npm_config_update_notifier=false
    export npm_config_audit=false
    export npm_config_fund=false
    export npm_config_cache="''${XDG_CACHE_HOME:-$HOME/.cache}/nixpi-npm"
    export npm_config_prefix="''${XDG_DATA_HOME:-$HOME/.local/share}/nixpi-npm-global"
    mkdir -p "$npm_config_cache" "$npm_config_prefix"
    ${pkgs.nodejs_22}/bin/npx --yes @mariozechner/pi-coding-agent@0.55.1 \
      -p "${heartbeatPrompt}" \
      --skill "${repoRoot}/infra/pi/skills/heartbeat/SKILL.md"
  '';

  serviceConfig = mkNixpiService {
    name = "nixpi-heartbeat";
    description = "Nixpi heartbeat — periodic agent observation cycle";
    serviceType = "oneshot";
    execStart = "${piWrapper}";
    timeoutStartSec = "5min";
  };
in
{
  options.nixpi.heartbeat = {
    enable = lib.mkEnableOption "Nixpi heartbeat (periodic agent wake cycle)";

    intervalMinutes = lib.mkOption {
      type = lib.types.int;
      default = 30;
      example = 15;
      description = ''
        How often the heartbeat fires, in minutes.
      '';
    };

    onCalendar = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "*-*-* 08:00:00";
      description = ''
        Optional systemd calendar expression override.
        When set, takes precedence over intervalMinutes.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    serviceConfig
    {
      assertions = [
        {
          assertion = cfg.intervalMinutes > 0;
          message = "nixpi.heartbeat.intervalMinutes must be positive.";
        }
      ];

      systemd.timers.nixpi-heartbeat = {
        description = "Timer for Nixpi heartbeat cycle";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = if cfg.onCalendar != null
            then cfg.onCalendar
            else "*:0/${toString cfg.intervalMinutes}";
          Persistent = true;
          RandomizedDelaySec = "2min";
        };
      };
    }
  ]);
}
