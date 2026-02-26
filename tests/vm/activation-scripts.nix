# VM test: activation scripts create pi directory tree, SYSTEM.md, and settings.json.
{ pkgsUnstableForTests }:

{
  name = "vm-activation-scripts";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    pi_dir = "/home/testuser/Nixpi/.pi/agent"

    # Pi directory tree was created by activation script
    for subdir in ["sessions", "extensions", "skills", "prompts", "themes"]:
        machine.succeed(f"test -d {pi_dir}/{subdir}")

    # Directories are owned by testuser
    machine.succeed(f"stat -c '%U' {pi_dir} | grep -q testuser")

    # SYSTEM.md was created with expected content
    machine.succeed(f"test -f {pi_dir}/SYSTEM.md")
    system_md = machine.succeed(f"cat {pi_dir}/SYSTEM.md")
    assert "NixOS" in system_md, "SYSTEM.md missing NixOS reference"

    # settings.json was seeded
    machine.succeed(f"test -f {pi_dir}/settings.json")
    settings = machine.succeed(f"cat {pi_dir}/settings.json")
    assert "skills" in settings, "settings.json missing skills key"

    # Shared directory was created
    machine.succeed("test -d /home/testuser/Shared")
  '';
}
