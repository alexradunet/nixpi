# mkNixpiService — factory for Nixpi systemd services with shared boilerplate.
#
# Extracts common patterns: User, Group, WorkingDirectory, Environment, journal logging.
#
# Usage:
#   mkNixpiService {
#     name = "nixpi-heartbeat";
#     description = "Nixpi heartbeat — periodic agent observation cycle";
#     serviceType = "oneshot";
#     execStart = "/path/to/script";
#     workingDirectory = repoRoot;    # optional, defaults to repoRoot
#     extraEnv = [ "EXTRA=value" ];   # optional additional env vars
#     execStartPre = "...";           # optional
#     restart = "on-failure";         # optional, for long-running services
#     restartSec = "30s";             # optional
#     timeoutStartSec = "5min";       # optional
#     after = [ "network.target" ];   # optional
#     wants = [ "network.target" ];   # optional
#     wantedBy = [ "multi-user.target" ];  # optional, for long-running services
#   }
{ config, pkgs, lib }:

{ name
, description
, serviceType
, execStart
, workingDirectory ? config.nixpi.repoRoot
, extraEnv ? []
, execStartPre ? null
, restart ? null
, restartSec ? null
, timeoutStartSec ? null
, after ? []
, wants ? []
, wantedBy ? []
}:

let
  primaryUser = config.nixpi.primaryUser;
  repoRoot = config.nixpi.repoRoot;
  piDir = config.nixpi.piDir;

  baseEnv = [
    "PI_CODING_AGENT_DIR=${piDir}"
    "NIXPI_OBJECTS_DIR=${config.nixpi.objects.dataDir}"
    "HOME=/home/${primaryUser}"
  ];
in
{
  systemd.services.${name} = {
    inherit description;
    inherit after wants wantedBy;

    serviceConfig = {
      Type = serviceType;
      User = primaryUser;
      Group = "users";
      WorkingDirectory = workingDirectory;
      Environment = baseEnv ++ extraEnv;
      ExecStart = execStart;
      StandardOutput = "journal";
      StandardError = "journal";
    } // lib.optionalAttrs (execStartPre != null) {
      ExecStartPre = execStartPre;
    } // lib.optionalAttrs (restart != null) {
      Restart = restart;
    } // lib.optionalAttrs (restartSec != null) {
      RestartSec = restartSec;
    } // lib.optionalAttrs (timeoutStartSec != null) {
      TimeoutStartSec = timeoutStartSec;
    };
  };
}
