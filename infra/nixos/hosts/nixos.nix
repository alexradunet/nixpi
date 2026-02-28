# Host file for the "nixos" machine — hardware-specific config (boot, disks, CPU).
{ lib, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usbhid" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/643fa494-9fd0-4301-bd5c-8c43e486d2f0";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/9887-C995";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  networking.hostName = "nixos";
  nixpi.primaryUser = "alex";
  nixpi.repoRoot = "/home/alex/Nixpi";
  nixpi.timeZone = "Europe/Bucharest";
  # Bootloader (UEFI / systemd-boot)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nixpi.channels.matrix = {
    enable = true;
    humanUser = "alex";  # @alex:nixpi.local — default is "human"
  };      
}
