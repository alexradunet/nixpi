# VM test: objects module creates data directory tree with correct ownership.
{ pkgsUnstableForTests }:

{
  name = "vm-objects-data-dir";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    data_dir = "/home/testuser/Nixpi/data/objects"

    # Data directory was created by activation script
    machine.succeed(f"test -d {data_dir}")

    # Default object type subdirectories exist
    for obj_type in ["journal", "task", "note"]:
        machine.succeed(f"test -d {data_dir}/{obj_type}")

    # Directories are owned by testuser
    machine.succeed(f"stat -c '%U' {data_dir} | grep -q testuser")
    machine.succeed(f"stat -c '%U' {data_dir}/journal | grep -q testuser")
    machine.succeed(f"stat -c '%U' {data_dir}/task | grep -q testuser")
    machine.succeed(f"stat -c '%U' {data_dir}/note | grep -q testuser")

    # Group is users
    machine.succeed(f"stat -c '%G' {data_dir} | grep -q users")
  '';
}
