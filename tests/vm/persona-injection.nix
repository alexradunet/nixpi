# VM test: persona layers are injected into SYSTEM.md during activation.
{ pkgsUnstableForTests }:

{
  name = "vm-persona-injection";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    pi_dir = "/home/testuser/Nixpi/.pi/agent"

    # SYSTEM.md exists and contains persona content
    machine.succeed(f"test -f {pi_dir}/SYSTEM.md")
    system_md = machine.succeed(f"cat {pi_dir}/SYSTEM.md")

    # Persona section is present
    assert "Persona" in system_md, "SYSTEM.md missing Persona section"

    # All 4 persona layers are injected
    assert "Soul" in system_md, "SYSTEM.md missing Soul layer"
    assert "Body" in system_md, "SYSTEM.md missing Body layer"
    assert "Faculty" in system_md, "SYSTEM.md missing Faculty layer"
    assert "Skill" in system_md, "SYSTEM.md missing Skill layer"

    # Key persona content is present
    assert "identity" in system_md.lower(), "SYSTEM.md missing identity content from SOUL"
    assert "channel" in system_md.lower(), "SYSTEM.md missing channel content from BODY"
    assert "PARA" in system_md, "SYSTEM.md missing PARA content from FACULTY"
    assert "object" in system_md.lower(), "SYSTEM.md missing object content from SKILL"
  '';
}
