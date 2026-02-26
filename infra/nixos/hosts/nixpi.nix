# Host file for the "nixpi" machine — hardware-specific config (boot, disks, CPU).
# Each host gets its own file in hosts/. The flake auto-discovers them by filename,
# and `nixos-rebuild switch --flake .` picks the right one based on the current hostname.
{ lib, modulesPath, ... }:

{
  imports = [
    # not-detected.nix adds sensible defaults for hardware detection (firmware,
    # kernel modules for common controllers). It comes from the NixOS installer.
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Boot configuration (systemd-boot for EFI)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # initrd (initial ramdisk) modules: loaded early in boot before the root
  # filesystem is mounted. These drivers are needed to access the boot disk.
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "uas" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Disk layout — devices referenced by UUID so they're stable across reboots
  # even if device names (/dev/sda etc.) change.
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/6695a473-5bf8-465b-83a3-2ec51d0b6191";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/0980-52EA";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [ ];

  # lib.mkDefault sets a value with low priority, so a more specific module
  # (like base.nix or the user's overrides) can easily replace it without
  # needing lib.mkForce. It's the standard pattern for hardware-detected defaults.
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;

  # networking.hostName must match the filename (nixpi.nix → "nixpi").
  # The flake uses the filename to look up the host, and nixos-rebuild uses
  # this hostname to select which configuration to apply.
  networking.hostName = "nixpi";
  nixpi.timeZone = "Europe/Bucharest";
}
