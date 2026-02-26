# VM test: sshd is running, root login rejected, hardened settings active.
{ pkgsUnstableForTests }:

{
  name = "vm-ssh-hardening";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
  };

  testScript = ''
    machine.wait_for_unit("sshd.service")

    # sshd is listening on port 22
    machine.succeed("ss -tlnp | grep ':22 '")

    # Root login is rejected
    machine.fail(
        "sshpass -p 'TestPassword123!@#Strong' "
        "ssh -o StrictHostKeyChecking=no root@localhost echo 'root login succeeded'"
    )

    # Non-root user can log in
    machine.succeed(
        "sshpass -p 'TestPassword123!@#Strong' "
        "ssh -o StrictHostKeyChecking=no testuser@localhost echo 'login ok'"
    )

    # Verify hardened settings in running config
    sshd_config = machine.succeed("sshd -T")
    assert "permitrootlogin no" in sshd_config, "PermitRootLogin not set to no"
    assert "x11forwarding no" in sshd_config, "X11Forwarding not disabled"
    assert "maxauthtries 3" in sshd_config, "MaxAuthTries not set to 3"
  '';
}
