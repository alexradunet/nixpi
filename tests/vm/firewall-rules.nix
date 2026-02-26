# VM test: nftables loaded with per-service IP-range rules.
{ pkgsUnstableForTests }:

{
  name = "vm-firewall-rules";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # nftables ruleset is loaded
    ruleset = machine.succeed("nft list ruleset")

    # Tailscale + LAN IP ranges present
    assert "100.0.0.0/8" in ruleset, "Missing Tailscale IPv4 range in nft ruleset"
    assert "fd7a:115c:a1e0::/48" in ruleset, "Missing Tailscale IPv6 range in nft ruleset"
    assert "192.168.0.0/16" in ruleset, "Missing LAN range 192.168.0.0/16"
    assert "10.0.0.0/8" in ruleset, "Missing LAN range 10.0.0.0/8"

    # Service-specific port rules
    assert "22" in ruleset, "Missing SSH port in ruleset"
    assert "7681" in ruleset, "Missing ttyd port in ruleset"
    assert "8384" in ruleset, "Missing Syncthing GUI port in ruleset"
    assert "22000" in ruleset, "Missing Syncthing sync port in ruleset"

    # Tailscale WireGuard UDP port
    assert "41641" in ruleset, "Missing Tailscale WireGuard port"
  '';
}
