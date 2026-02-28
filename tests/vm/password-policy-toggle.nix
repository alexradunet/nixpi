# VM test: Password policy module toggles on/off correctly.
{ pkgsUnstableForTests }:

{
  name = "vm-password-policy-toggle";
  skipTypeCheck = true;

  nodes.enabled = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    nixpi.passwordPolicy.enable = true;
  };

  nodes.disabled = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    nixpi.passwordPolicy.enable = false;
  };

  testScript = ''
    # --- Enabled node ---
    enabled.wait_for_unit("multi-user.target")

    # Reject short password
    enabled.fail("echo 'testuser:Short1!@#' | chpasswd")

    # Reject no digit
    enabled.fail("echo 'testuser:NoDigitsSpecial!@#here' | chpasswd")

    # Reject no special char
    enabled.fail("echo 'testuser:NoSpecialChar12345ab' | chpasswd")

    # Accept valid password
    enabled.succeed("echo 'testuser:ValidPassword123!@#ok' | chpasswd")

    # --- Disabled node ---
    disabled.wait_for_unit("multi-user.target")

    # Short password should be accepted when policy is off
    disabled.succeed("echo 'testuser:short1!' | chpasswd")
  '';
}
