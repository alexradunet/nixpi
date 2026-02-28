# VM test: Tailscale module toggles on/off correctly.
{ pkgsUnstableForTests }:

{
  name = "vm-tailscale-toggle";

  nodes.enabled = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    nixpi.tailscale.enable = true;
  };

  nodes.disabled = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    nixpi.tailscale.enable = false;
  };

  testScript = ''
    # --- Enabled node ---
    enabled.wait_for_unit("multi-user.target")
    enabled.wait_for_unit("tailscaled.service")

    # Tailscale CLI available
    enabled.succeed("which tailscale")

    # WireGuard UDP port in firewall
    ruleset = enabled.succeed("nft list ruleset")
    assert "41641" in ruleset, "Missing Tailscale WireGuard port when enabled"

    # --- Disabled node ---
    disabled.wait_for_unit("multi-user.target")

    # tailscaled should not be running
    disabled.fail("systemctl is-active tailscaled.service")

    # WireGuard port should NOT be in firewall
    ruleset = disabled.succeed("nft list ruleset")
    assert "41641" not in ruleset, "Tailscale WireGuard port present when disabled"
  '';
}
