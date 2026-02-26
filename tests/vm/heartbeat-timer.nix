# VM test: heartbeat timer is active when enabled.
#
# Note: we only test that the timer unit is loaded and active. We do not
# test that Pi actually runs (the npx command requires network access and
# a Pi auth token, neither of which is available in the VM test sandbox).
{ pkgsUnstableForTests }:

{
  name = "vm-heartbeat-timer";

  nodes.machine = { config, pkgs, lib, ... }: {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];

    nixpi.heartbeat.enable = true;
    nixpi.heartbeat.intervalMinutes = 15;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Timer unit is loaded and active
    machine.succeed("systemctl is-enabled nixpi-heartbeat.timer")

    # Service unit exists (oneshot, triggered by timer)
    machine.succeed("systemctl cat nixpi-heartbeat.service")

    # Timer configuration matches expected interval
    timer_info = machine.succeed("systemctl show nixpi-heartbeat.timer --property=TimersCalendar")
    assert "0/15" in timer_info, f"expected 15-minute interval in timer config, got: {timer_info}"

    # Service runs as testuser
    svc_info = machine.succeed("systemctl show nixpi-heartbeat.service --property=User")
    assert "testuser" in svc_info, f"expected service to run as testuser, got: {svc_info}"
  '';
}
