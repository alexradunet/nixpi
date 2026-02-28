# ttyd module — web terminal interface over SSH.
#
# When enabled, provisions ttyd on a configurable port, authenticating
# via localhost OpenSSH login. Firewall restricts access to Tailscale only.
{ config, pkgs, lib, ... }:

let
  cfg = config.nixpi.ttyd;
  primaryUser = config.nixpi.primaryUser;
in
{
  options.nixpi.ttyd = {
    enable = lib.mkEnableOption "ttyd web terminal (SSH-based)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 7681;
      description = "Port for the ttyd web terminal.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.ttyd = {
      enable = true;
      port = cfg.port;
      user = primaryUser;
      writeable = true;
      checkOrigin = true;
      entrypoint = [
        "${lib.getExe' pkgs.openssh "ssh"}"
        "-o"
        "StrictHostKeyChecking=accept-new"
        "${primaryUser}@127.0.0.1"
      ];
    };

    networking.firewall.extraInputRules = let mkRules = config.nixpi._internal.mkTailscaleFirewallRules; in ''
      # Allow ttyd from Tailscale only
      ${mkRules { port = cfg.port; }}
    '';
  };
}
