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
    ./thermal.nix
  ];
  hardware.nvidia = {
    nvidiaSettings = lib.mkForce true;
    # The Quadro P3000 (Pascal) was dropped after the 580 branch; nixos-hardware
    # pins `stable`, which ignores this GPU.
    package = lib.mkForce config.boot.kernelPackages.nvidiaPackages.legacy_580;
    # Headless: keep the driver initialised so nvidia-smi doesn't cold-start the
    # GPU every time the fan controller polls it.
    nvidiaPersistenced = true;
  };
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
    # Firmware advertises a TPM2 ACPI table but tpm_tis fails to probe it, so
    # /dev/tpm0 never appears and systemd-tpm2-generator makes boot wait 90s
    # for it (initrd + stage 2). Nothing here uses the TPM.
    kernelParams = [ "systemd.tpm2_wait=0" ];
  };

  nix.settings.trusted-users = [ "sangmin" ];
}
