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
#     hardening ? true;               # optional, enable security hardening (default: true)
#   }
{
  config,
  pkgs,
  lib,
}:

# Parameters:
#   stateDirectory — systemd-managed dir under /var/lib/, created and owned by
#                    the service user, lifecycle tied to the service.
#   readWritePaths — pre-existing paths (e.g. repoRoot, piDir) that need write
#                    access within ProtectSystem=strict. Not created by systemd.
{
  name,
  description,
  serviceType,
  execStart,
  workingDirectory ? config.nixpi.repoRoot,
  extraEnv ? [ ],
  execStartPre ? null,
  restart ? null,
  restartSec ? null,
  timeoutStartSec ? null,
  after ? [ ],
  wants ? [ ],
  wantedBy ? [ ],
  hardening ? true,
  stateDirectory ? null,
  stateDirectoryMode ? "0700",
  readWritePaths ? [ ],
}:

let
  assistantUser = config.nixpi.assistantUser;
  repoRoot = config.nixpi.repoRoot;
  piDir = config.nixpi.piDir;

  baseEnv = [
    "PI_CODING_AGENT_DIR=${piDir}"
    "NIXPI_OBJECTS_DIR=${config.nixpi.objects.dataDir}"
    "HOME=/var/lib/nixpi"
  ];
in
{
  systemd.services.${name} = {
    inherit description;
    inherit after wants wantedBy;

    serviceConfig = {
      Type = serviceType;
      User = assistantUser;
      Group = "nixpi";
      WorkingDirectory = workingDirectory;
      Environment = baseEnv ++ extraEnv;
      ExecStart = execStart;
      StandardOutput = "journal";
      StandardError = "journal";
    }
    // lib.optionalAttrs (execStartPre != null) {
      ExecStartPre = execStartPre;
    }
    // lib.optionalAttrs (restart != null) {
      Restart = restart;
    }
    // lib.optionalAttrs (restartSec != null) {
      RestartSec = restartSec;
    }
    // lib.optionalAttrs (timeoutStartSec != null) {
      TimeoutStartSec = timeoutStartSec;
    }
    // lib.optionalAttrs (stateDirectory != null) {
      StateDirectory = stateDirectory;
      StateDirectoryMode = stateDirectoryMode;
    }
    // lib.optionalAttrs (readWritePaths != [ ]) {
      ReadWritePaths = readWritePaths;
    }
    // lib.optionalAttrs hardening {
      # Security hardening defaults
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      NoNewPrivileges = true;
      PrivateTmp = true;
      StartLimitBurst = 5;
      StartLimitIntervalSec = 60;
    };
  };
}
