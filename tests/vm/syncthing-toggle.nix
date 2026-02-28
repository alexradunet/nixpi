# VM test: Syncthing module toggles on/off correctly.
{ pkgsUnstableForTests }:

{
  name = "vm-syncthing-toggle";

  nodes.enabled = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    nixpi.syncthing.enable = true;
  };

  nodes.disabled = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    nixpi.syncthing.enable = false;
  };

  testScript = ''
    # --- Enabled node ---
    enabled.wait_for_unit("multi-user.target")
    enabled.wait_for_unit("syncthing.service")

    # Shared directory created
    enabled.succeed("test -d /home/testuser/Shared")

    # Firewall rules present
    ruleset = enabled.succeed("nft list ruleset")
    assert "8384" in ruleset, "Missing Syncthing GUI port when enabled"
    assert "22000" in ruleset, "Missing Syncthing sync port when enabled"

    # --- Disabled node ---
    disabled.wait_for_unit("multi-user.target")
    disabled.fail("systemctl is-active syncthing.service")

    # Shared directory should NOT be created
    disabled.fail("test -d /home/testuser/Shared")

    ruleset = disabled.succeed("nft list ruleset")
    assert "8384" not in ruleset, "Syncthing GUI port present when disabled"
    assert "22000" not in ruleset, "Syncthing sync port present when disabled"
  '';
}
