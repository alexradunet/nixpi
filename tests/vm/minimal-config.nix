# VM test: minimal config with ALL optional modules disabled.
# Only SSH + NetworkManager + core should be running.
{ pkgsUnstableForTests }:

{
  name = "vm-minimal-config";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    # Disable everything optional
    nixpi.tailscale.enable = false;
    nixpi.syncthing.enable = false;
    nixpi.ttyd.enable = false;
    nixpi.passwordPolicy.enable = false;
    nixpi.desktop.enable = false;
    nixpi.objects.enable = false;
    nixpi.heartbeat.enable = false;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Core services still running
    machine.wait_for_unit("sshd.service")
    machine.wait_for_unit("NetworkManager.service")
    machine.wait_for_open_port(22)

    # All optional services should NOT be running
    machine.fail("systemctl is-active tailscaled.service")
    machine.fail("systemctl is-active ttyd.service")
    machine.fail("systemctl is-active syncthing.service")
    machine.fail("systemctl is-active display-manager.service")

    # Firewall should only have SSH rules
    ruleset = machine.succeed("nft list ruleset")
    assert "22" in ruleset, "SSH port missing from minimal config"
    assert "7681" not in ruleset, "ttyd port leaked into minimal config"
    assert "8384" not in ruleset, "Syncthing port leaked into minimal config"
    assert "41641" not in ruleset, "Tailscale port leaked into minimal config"

    # Password policy not enforced
    machine.succeed("echo 'testuser:short1!' | chpasswd")
  '';
}
