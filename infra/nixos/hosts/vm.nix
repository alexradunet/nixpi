# Generic VM host template.
# After installing NixOS in a VM, run `nixos-generate-config` and copy the
# root filesystem UUID from the generated hardware-configuration.nix into
# the fileSystems block below.
{ modulesPath, lib, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Host-specific boot and disk layout — adjust for your VM.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/REPLACE-WITH-YOUR-ROOT-UUID";
    fsType = "ext4";
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  networking.hostName = "nixpi-vm";
}
