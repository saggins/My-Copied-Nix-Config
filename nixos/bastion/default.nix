# VPS:               1GB KVM VPS
# CPU:               1 vCPU
# RAM:               1GB
# Disk:              20GB SSD (virtio)
#
# Derivations are built on a workstation and pushed; nothing heavy runs here.
#  - Install (from the provider's Ubuntu image, as root):
#    nix run github:nix-community/nixos-anywhere -- --flake '.#bastion' --build-on local root@<ip-address>
#  - After install: `sudo tailscale up`, then create the sops host key
#    (/var/lib/private/sops/age/keys.txt) and add it to .sops.yaml
#  - Update:
#    nixos-rebuild switch --flake '.#bastion' --target-host sangmin@bastion --sudo
{
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disks.nix
  ];

  boot = {
    initrd.availableKernelModules = [
      "ahci"
      "sd_mod"
      "sr_mod"
      "virtio_blk"
      "virtio_pci"
      "virtio_scsi"
      "xhci_pci"
    ];
    # GRUB on both the BIOS boot partition and the ESP (as removable media) so it
    # boots regardless of the firmware; disko populates grub.devices.
    loader = {
      efi.canTouchEfiVariables = lib.mkForce false;
      grub = {
        enable = true;
        efiSupport = true;
        efiInstallAsRemovable = true;
        configurationLimit = 5;
      };
      systemd-boot.enable = lib.mkForce false;
      timeout = lib.mkForce 3;
    };
  };

  # Nothing to drive on a virtual machine
  services.hardware.bolt.enable = lib.mkForce false;
  services.fwupd.enable = lib.mkForce false;
  services.smartd.enable = lib.mkForce false;
  services.qemuGuest.enable = true;
  hardware.enableRedistributableFirmware = lib.mkForce false;

  # Most providers hand out the address via DHCP. If yours is static, use the
  # values from the control panel instead, e.g.:
  # networking = {
  #   useDHCP = false;
  #   interfaces.ens3.ipv4.addresses = [ { address = "x.x.x.x"; prefixLength = 24; } ];
  #   defaultGateway = "x.x.x.1";
  # };

  # Keep the 20GB disk from filling up with store paths
  nix = {
    optimise.automatic = true;
    settings = {
      min-free = 1024 * 1024 * 1024;
      max-free = 3 * 1024 * 1024 * 1024;
      trusted-users = [ "sangmin" ];
    };
  };
  programs.nh.clean.extraArgs = lib.mkForce "--keep-since 7d --keep 3";
}
