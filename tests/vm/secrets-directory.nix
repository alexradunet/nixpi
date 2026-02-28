# VM test: /etc/nixpi/secrets/ directory exists with correct permissions.
{ pkgsUnstableForTests }:

{
  name = "vm-secrets-directory";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Secrets directory exists
    machine.succeed("test -d /etc/nixpi/secrets")

    # Owned by root
    owner = machine.succeed("stat -c '%U' /etc/nixpi/secrets").strip()
    assert owner == "root", f"Secrets dir owned by {owner}, expected root"

    # Mode 0700
    mode = machine.succeed("stat -c '%a' /etc/nixpi/secrets").strip()
    assert mode == "700", f"Secrets dir mode is {mode}, expected 700"

    # Not world-readable
    machine.fail("su -s /bin/sh testuser -c 'ls /etc/nixpi/secrets'")
  '';
}
