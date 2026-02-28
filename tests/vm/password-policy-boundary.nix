# VM test: password policy boundary values with custom minLength.
#
# Tests exact boundary: password of exactly minLength passes, one character
# shorter fails. Also verifies PAM config exists in both passwd and chpasswd.
{ pkgsUnstableForTests }:

{
  name = "vm-password-policy-boundary";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];

    nixpi.passwordPolicy.minLength = 20;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Exactly 20 chars with digit + special — accepted
    machine.succeed("echo 'testuser:BoundaryTest12345!xx' | chpasswd")

    # Exactly 19 chars with digit + special — rejected (one short of minLength=20)
    machine.fail("echo 'testuser:BoundaryTest1234!xx' | chpasswd")

    # PAM config exists in both passwd and chpasswd
    machine.succeed("test -f /etc/pam.d/passwd")
    machine.succeed("test -f /etc/pam.d/chpasswd")
    machine.succeed("grep -q pam_exec /etc/pam.d/passwd")
    machine.succeed("grep -q pam_exec /etc/pam.d/chpasswd")
  '';
}
