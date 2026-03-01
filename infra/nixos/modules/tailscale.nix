# Tailscale VPN module — optional Tailscale mesh networking.
#
# When enabled, provisions the Tailscale daemon with SSH disabled
# (OpenSSH remains the single SSH control plane) and opens UDP 41641
# for direct WireGuard connections.
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.nixpi.tailscale;
in
{
  options.nixpi.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN mesh networking";
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      extraSetFlags = [ "--ssh=false" ];
    };

    networking.firewall.allowedUDPPorts = [ 41641 ];

    environment.systemPackages = [ pkgs.tailscale ];
  };
}
