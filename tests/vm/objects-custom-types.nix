# VM test: custom object types including hyphenated names.
#
# Verifies that the objects module correctly creates subdirectories for
# user-defined types, including those with hyphens (e.g. health-metric).
{ pkgsUnstableForTests }:

{
  name = "vm-objects-custom-types";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];

    nixpi.objects.types = [
      "journal"
      "task"
      "note"
      "person"
      "health-metric"
    ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    data_dir = "/home/testuser/Nixpi/data/objects"

    # All custom type subdirectories exist
    for obj_type in ["journal", "task", "note", "person", "health-metric"]:
        machine.succeed(f"test -d {data_dir}/{obj_type}")
        owner = machine.succeed(f"stat -c '%U' {data_dir}/{obj_type}").strip()
        assert owner == "testuser", f"Expected {obj_type}/ owned by testuser, got: {owner}"

    # Default type 'evolution' should NOT be present (custom list replaces defaults)
    machine.fail(f"test -d {data_dir}/evolution")
  '';
}
