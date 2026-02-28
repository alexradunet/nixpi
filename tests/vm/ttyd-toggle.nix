# VM test: ttyd module toggles on/off correctly.
{ pkgsUnstableForTests }:

{
  name = "vm-ttyd-toggle";
  skipTypeCheck = true;
  skipLint = true;

  nodes.enabled = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    networking.hostName = "enabled";
    nixpi.ttyd.enable = true;
  };

  nodes.disabled = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    networking.hostName = "disabled";
    nixpi.ttyd.enable = false;
  };

  testScript = ''
    # --- Enabled node ---
    enabled.wait_for_unit("multi-user.target")
    enabled.wait_for_unit("ttyd.service")
    enabled.wait_for_open_port(7681)

    ruleset = enabled.succeed("nft list ruleset")
    assert "7681" in ruleset, "Missing ttyd port in firewall when enabled"

    # --- Disabled node ---
    disabled.wait_for_unit("multi-user.target")
    disabled.fail("systemctl is-active ttyd.service")

    ruleset = disabled.succeed("nft list ruleset")
    assert "7681" not in ruleset, "ttyd port present in firewall when disabled"
  '';
}
