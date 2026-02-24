{ modulesPath, lib, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Host-specific boot and disk layout for the current installed VM.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/4e8fd093-5dd8-4e04-bfe7-c241e884c446";
    fsType = "ext4";
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  networking.hostName = "nixpi";
}
