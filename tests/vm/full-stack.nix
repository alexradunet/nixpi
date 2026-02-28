# VM test: full stack with ALL optional modules enabled.
# Verifies no conflicts between modules.
{ pkgsUnstableForTests }:

{
  name = "vm-full-stack";

  nodes.machine = { config, pkgs, lib, ... }: {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    # Enable everything (except desktop — too heavy for VM)
    nixpi.tailscale.enable = true;
    nixpi.syncthing.enable = true;
    nixpi.ttyd.enable = true;
    nixpi.passwordPolicy.enable = true;
    nixpi.objects.enable = true;
    nixpi.heartbeat.enable = true;
    nixpi.heartbeat.intervalMinutes = 60;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # All services running
    machine.wait_for_unit("sshd.service")
    machine.wait_for_unit("tailscaled.service")
    machine.wait_for_unit("ttyd.service")
    machine.wait_for_unit("syncthing.service")
    machine.wait_for_unit("NetworkManager.service")

    # Heartbeat timer enabled
    machine.succeed("systemctl is-enabled nixpi-heartbeat.timer")

    # All ports open
    machine.wait_for_open_port(22)
    machine.wait_for_open_port(7681)

    # Object store directories exist
    machine.succeed("test -d /home/testuser/Nixpi/data/objects/journal")

    # Password policy enforced
    machine.fail("echo 'testuser:short1!' | chpasswd")
    machine.succeed("echo 'testuser:ValidPassword123!@#ok' | chpasswd")

    # Firewall has all rules
    ruleset = machine.succeed("nft list ruleset")
    assert "22" in ruleset, "Missing SSH"
    assert "7681" in ruleset, "Missing ttyd"
    assert "8384" in ruleset, "Missing Syncthing"
    assert "41641" in ruleset, "Missing Tailscale"
  '';
}
