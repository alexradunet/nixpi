# VM test: primary user exists with correct home, groups, and UID.
{ pkgsUnstableForTests }:

{
  name = "vm-user-and-groups";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Primary user exists
    machine.succeed("id testuser")

    # Home directory exists and is owned by testuser
    machine.succeed("test -d /home/testuser")
    machine.succeed("stat -c '%U' /home/testuser | grep -q testuser")

    # User is in expected groups
    groups = machine.succeed("groups testuser")
    assert "wheel" in groups, f"testuser not in wheel group: {groups}"
    assert "networkmanager" in groups, f"testuser not in networkmanager group: {groups}"

    # User is a normal user (UID >= 1000)
    uid = int(machine.succeed("id -u testuser").strip())
    assert uid >= 1000, f"testuser UID {uid} is below 1000 (not a normal user)"

    # Home directory path is correct
    home = machine.succeed("getent passwd testuser | cut -d: -f6").strip()
    assert home == "/home/testuser", f"Unexpected home: {home}"
  '';
}
