# VM test: tailscaled, syncthing, ttyd, sshd, NetworkManager are active.
{ pkgsUnstableForTests }:

{
  name = "vm-service-ensemble";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Core services are active
    machine.wait_for_unit("sshd.service")
    machine.wait_for_unit("tailscaled.service")
    machine.wait_for_unit("ttyd.service")
    machine.wait_for_unit("NetworkManager.service")
    machine.wait_for_unit("syncthing.service")

    # Key ports are listening
    machine.wait_for_open_port(22)
    machine.wait_for_open_port(7681)
  '';
}
