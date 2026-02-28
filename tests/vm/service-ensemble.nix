# VM test: core services are active when all modules enabled.
{ pkgsUnstableForTests }:

{
  name = "vm-service-ensemble";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    # Explicitly enable all optional modules
    nixpi.tailscale.enable = true;
    nixpi.syncthing.enable = true;
    nixpi.ttyd.enable = true;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Core services (always on)
    machine.wait_for_unit("sshd.service")
    machine.wait_for_unit("NetworkManager.service")

    # Optional services (explicitly enabled)
    machine.wait_for_unit("tailscaled.service")
    machine.wait_for_unit("ttyd.service")
    machine.wait_for_unit("syncthing.service")

    # Key ports are listening
    machine.wait_for_open_port(22)
    machine.wait_for_open_port(7681)
  '';
}
