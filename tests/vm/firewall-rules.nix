# VM test: nftables loaded with per-service IP-range rules.
{ pkgsUnstableForTests }:

{
  name = "vm-firewall-rules";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    # Enable modules to get their firewall rules
    nixpi.tailscale.enable = true;
    nixpi.syncthing.enable = true;
    nixpi.ttyd.enable = true;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    ruleset = machine.succeed("nft list ruleset")

    # SSH rules (always present from base.nix)
    assert "100.0.0.0/8" in ruleset, "Missing Tailscale IPv4 range"
    assert "fd7a:115c:a1e0::/48" in ruleset, "Missing Tailscale IPv6 range"
    assert "192.168.0.0/16" in ruleset, "Missing LAN range 192.168"
    assert "10.0.0.0/8" in ruleset, "Missing LAN range 10.0"
    assert "22" in ruleset, "Missing SSH port"

    # Module-contributed rules
    assert "7681" in ruleset, "Missing ttyd port"
    assert "8384" in ruleset, "Missing Syncthing GUI port"
    assert "22000" in ruleset, "Missing Syncthing sync port"
    assert "41641" in ruleset, "Missing Tailscale WireGuard port"
  '';
}
