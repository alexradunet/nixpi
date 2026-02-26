# VM test: PAM rejects weak passwords and accepts strong ones via chpasswd.
{ pkgsUnstableForTests }:

{
  name = "vm-password-policy";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Too short (< 16 chars) — rejected
    machine.fail("echo 'testuser:Short1!@#' | chpasswd")

    # No digits — rejected
    machine.fail("echo 'testuser:NoDigitsHereSpecial!@#' | chpasswd")

    # No special character — rejected
    machine.fail("echo 'testuser:NoSpecialChars12345678' | chpasswd")

    # Valid password (>= 16 chars, has digit, has special) — accepted
    machine.succeed("echo 'testuser:ValidPassword123!@#ok' | chpasswd")
  '';
}
