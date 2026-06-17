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
  services.logind.settings.Login.HandleLidSwitch = "ignore";

  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "ahci"
      "xhci_pci"
      "usbhid"
      "uas"
      "sd_mod"
    ];
    # bcachefs is out-of-tree on the 6.18 kernel; pull its module into the
    # initrd so stage-1 can open the bcachefs root.
    extraModulePackages = [ config.boot.kernelPackages.bcachefs ];
    initrd.supportedFilesystems = [ "bcachefs" ];
  };

  nix.settings.trusted-users = ["sangmin"];
}
