{ config, pkgs, lib, ... }:
let
  repoUrl = "https://github.com/alexradunet/nixpi.git";
  repoDir = "/home/nixpi/nixpi";

  pi = pkgs.writeShellScriptBin "pi" ''
    exec ${pkgs.nodejs_22}/bin/npx --yes @mariozechner/pi-coding-agent@0.54.2 "$@"
  '';
in
{
  networking.hostName = lib.mkDefault "nixpi-vm";

  networking.networkmanager.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Better VM guest integration (QEMU/Boxes/SPICE)
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  # Useful for remote administration later
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";

  # Enable Tailscale daemon (tailscale CLI included via package below)
  services.tailscale.enable = true;

  users.users.nixpi = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "changeme";
  };

  environment.systemPackages = with pkgs; [
    git
    gh
    tailscale
    curl
    wget
    vim
    nodejs_22
    pi
  ];

  # Clone repository on first boot if missing.
  systemd.services.nixpi-repo-bootstrap = {
    description = "Clone nixpi repository";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "nixpi";
      Group = "users";
      WorkingDirectory = "/home/nixpi";
      RemainAfterExit = true;
    };

    path = [ pkgs.git ];
    script = ''
      set -eu
      if [ -d "${repoDir}/.git" ]; then
        exit 0
      fi

      # Do not fail system activation if clone needs authentication
      # (e.g. private repository over HTTPS).
      if ! git clone --depth=1 "${repoUrl}" "${repoDir}"; then
        echo "[nixpi] repo bootstrap skipped (clone failed; auth/network may be required)."
        exit 0
      fi
    '';
  };

  # Keep repo up to date automatically.
  systemd.services.nixpi-repo-update = {
    description = "Update nixpi repository";
    after = [ "network-online.target" "nixpi-repo-bootstrap.service" ];
    wants = [ "network-online.target" "nixpi-repo-bootstrap.service" ];

    serviceConfig = {
      Type = "oneshot";
      User = "nixpi";
      Group = "users";
      WorkingDirectory = "/home/nixpi";
    };

    path = [ pkgs.git ];
    script = ''
      set -eu
      if [ ! -d "${repoDir}/.git" ]; then
        echo "[nixpi] repo update skipped (repository not present)."
        exit 0
      fi

      # Do not fail timer if auth/network is unavailable.
      if ! git -C "${repoDir}" pull --ff-only; then
        echo "[nixpi] repo update skipped (pull failed; auth/network may be required)."
        exit 0
      fi
    '';
  };

  systemd.timers.nixpi-repo-update = {
    description = "Periodic nixpi repository updates";
    wantedBy = [ "timers.target" ];

    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "30min";
      Unit = "nixpi-repo-update.service";
    };
  };

  system.stateVersion = "25.11";
}
