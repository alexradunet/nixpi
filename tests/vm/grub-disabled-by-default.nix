{ pkgsUnstableForTests }:
{
  name = "vm-grub-disabled-by-default";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    # Intentionally NO boot loader config — base.nix mkDefault should suffice.
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.fail("test -d /boot/grub")
    machine.succeed("test -e /run/current-system")
  '';
}
