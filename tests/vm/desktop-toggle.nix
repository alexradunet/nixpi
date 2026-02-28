# VM test: Desktop module toggles on/off correctly.
#
# Note: We only test the disabled state in VM since GNOME is heavy.
{ pkgsUnstableForTests }:

{
  name = "vm-desktop-toggle";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    nixpi.desktop.enable = false;
  };

  testScript = ''
    # --- Disabled node ---
    machine.wait_for_unit("multi-user.target")

    # GDM should not be active
    machine.fail("systemctl is-active display-manager.service")

    # GNOME session should not exist
    machine.fail("test -f /run/current-system/sw/share/xsessions/gnome.desktop")
  '';
}
