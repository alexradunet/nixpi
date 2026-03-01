# VM test: heartbeat timer onCalendar override path.
#
# The existing heartbeat-timer test covers intervalMinutes. This test verifies
# that setting onCalendar takes precedence and produces the expected timer
# configuration.
{ pkgsUnstableForTests }:

{
  name = "vm-heartbeat-oncalendar";

  nodes.machine =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    {
      imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];

      nixpi.heartbeat.enable = true;
      nixpi.heartbeat.onCalendar = "*-*-* 08:00:00";
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Timer unit is loaded
    machine.succeed("systemctl is-enabled nixpi-heartbeat.timer")

    timer_info = machine.succeed("systemctl show nixpi-heartbeat.timer --property=TimersCalendar")

    # onCalendar expression is present
    assert "08:00:00" in timer_info, f"Expected 08:00:00 in timer config, got: {timer_info}"

    # Default interval pattern should NOT be present (onCalendar takes precedence)
    assert "0/30" not in timer_info, f"Default interval 0/30 should not be present, got: {timer_info}"

    # Persistent=yes is still set
    persistent = machine.succeed("systemctl show nixpi-heartbeat.timer --property=Persistent")
    assert "yes" in persistent, f"Expected Persistent=yes, got: {persistent}"
  '';
}
