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

  # The provider has no DHCP; static IPv4 from the control panel.
  # Matched by name pattern so it works whatever the NIC ends up being called.
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "en* eth*";
    address = [ "107.172.75.145/25" ];
    routes = [ { Gateway = "107.172.75.129"; } ];
    linkConfig.RequiredForOnline = "routable";
  };

  # Keep the 20GB disk from filling up with store paths
  nix = {
    optimise.automatic = true;
    settings = {
      min-free = 1024 * 1024 * 1024;
      max-free = 3 * 1024 * 1024 * 1024;
      trusted-users = [ "sangmin" ];
    };
  };
  # Allow workhorse to log in, in addition to the keys from the user mixin
  users.users.sangmin.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMohOkwkbAVpIyMRuTadGYhreqPHFIwal5qWGKTdWQCU sangmin@workhorse"
  ];

  programs.nh.clean.extraArgs = lib.mkForce "--keep-since 7d --keep 3";
}
