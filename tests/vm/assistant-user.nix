# VM test: nixpi-agent system user exists with correct properties.
{ pkgsUnstableForTests }:

{
  name = "vm-assistant-user";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # nixpi-agent system user exists
    machine.succeed("id nixpi-agent")

    # Is a system user (UID < 1000)
    uid = int(machine.succeed("id -u nixpi-agent").strip())
    assert uid < 1000, f"nixpi-agent UID {uid} is not a system user"

    # Has nixpi group
    groups = machine.succeed("groups nixpi-agent")
    assert "nixpi" in groups, f"nixpi-agent not in nixpi group: {groups}"

    # Home is /var/lib/nixpi
    home = machine.succeed("getent passwd nixpi-agent | cut -d: -f6").strip()
    assert home == "/var/lib/nixpi", f"Unexpected home: {home}"

    # Home directory exists
    machine.succeed("test -d /var/lib/nixpi")

    # Primary user is in nixpi group
    primary_groups = machine.succeed("groups testuser")
    assert "nixpi" in primary_groups, f"testuser not in nixpi group: {primary_groups}"

    # No login shell
    shell = machine.succeed("getent passwd nixpi-agent | cut -d: -f7").strip()
    assert "nologin" in shell or "false" in shell, f"nixpi-agent has login shell: {shell}"
  '';
}
