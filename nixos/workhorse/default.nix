{
  config,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.dell-precision-7520
    ./disks.nix
  ];

  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "ahci"
      "xhci_pci"
      "usbhid"
      "uas"
      "sd_mod"
    ];
    loader = {
      systemd-boot.enable = lib.mkForce false;
      grub = {
      devices = ["nodev"];
      enable=true;
      extraEntriesBeforeNixOS=true;
      extraEntries = ''
      menuentry "Windows" {
        insmod part_gpt
        insmod fat
        insmod search_fs_uuid
        insmod chain
        search --fs-uuid --set=root $FS_UUID
        chainloader /EFI/Microsoft/Boot/bootmgfw.efi
      }
    '';
      };
    };
    kernelModules = [
      "amdgpu"
      "kvm-amd"
    ];

  };
  services.xserver.videoDrivers = [
    "amdgpu"
  ];

  nix.settings.trusted-users = ["sangmin"];
}
