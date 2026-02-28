# VM test: mk-nixpi-service security hardening properties.
#
# Verifies that services built with the mkNixpiService factory get the
# expected systemd sandboxing: ProtectSystem, ProtectHome, NoNewPrivileges,
# PrivateTmp, User/Group, and restart rate-limiting.
{ pkgsUnstableForTests }:

{
  name = "vm-service-hardening";

  nodes.machine = {
    imports = [ (import ./_base-test-config.nix { inherit pkgsUnstableForTests; }) ];
    nixpi.heartbeat.enable = true;
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    props = machine.succeed("systemctl show nixpi-heartbeat.service")

    # Security sandboxing
    assert "ProtectSystem=strict" in props, f"Missing ProtectSystem=strict in:\n{props}"
    assert "ProtectHome=read-only" in props, f"Missing ProtectHome=read-only in:\n{props}"
    assert "NoNewPrivileges=yes" in props, f"Missing NoNewPrivileges=yes in:\n{props}"
    assert "PrivateTmp=yes" in props, f"Missing PrivateTmp=yes in:\n{props}"

    # User and group
    assert "User=nixpi-agent" in props, f"Missing User=nixpi-agent in:\n{props}"
    assert "Group=nixpi" in props, f"Missing Group=nixpi in:\n{props}"

    # Restart rate-limiting
    assert "StartLimitBurst=5" in props, f"Missing StartLimitBurst=5 in:\n{props}"
    assert "StartLimitIntervalUSec=1min" in props, f"Missing StartLimitIntervalUSec=1min in:\n{props}"
  '';
}
