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
  hardware.nvidia.nvidiaSettings = lib.mkForce true;
  services.logind.lidSwitch="ignore";

  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "ahci"
      "xhci_pci"
      "usbhid"
      "uas"
      "sd_mod"
    ];
  };

  nix.settings.trusted-users = ["sangmin"];
}
