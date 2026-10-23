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
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-pc
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    ./disks.nix
    ./secureboot.nix
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
    # bcachefs is out-of-tree on the 7.3 kernel; pull its module into the
    # initrd so stage-1 can open the bcachefs root.
    extraModulePackages = [ config.boot.kernelPackages.bcachefs ];
    initrd.supportedFilesystems = [ "bcachefs" ];
    # GRUB instead of systemd-boot: the hardware boot switch needs GRUB scripting
    loader = {
      systemd-boot.enable = lib.mkForce false;
      grub = {
        enable = true;
        efiSupport = true;
        device = "nodev";
        configurationLimit = 10;
        # Windows must be entry 0, firmware setup 1 and NixOS 2 for the switch logic below
        extraEntriesBeforeNixOS = true;
        extraEntries = ''
          menuentry "Windows" {
            insmod part_gpt
            insmod fat
            insmod search_fs_file
            insmod chain
            search --no-floppy --file --set=root /EFI/Microsoft/Boot/bootmgfw.efi
            chainloader /EFI/Microsoft/Boot/bootmgfw.efi
          }
          menuentry "UEFI Firmware Settings" --class efi {
            fwsetup
          }
        '';
        extraConfig = ''
          # Look for hardware switch device by its hard-coded filesystem ID
          search --no-floppy --fs-uuid --set hdswitch 0000-1234

          # If found, read dynamic config file and select appropriate entry for each position
          if [ "''${hdswitch}" ] ; then
            source (''${hdswitch})/switch_position_grub.cfg

            if [ "''${os_hw_switch}" == 0 ] ; then
              # Boot Linux
              set default="2"
            elif [ "''${os_hw_switch}" == 1 ] ; then
              # Boot Windows
              set default="0"
            fi
          fi
        '';
      };
    };
    kernelModules = [
      "amdgpu"
      "kvm-amd"
    ];

    kernelParams = [
      "video=DP-3:1920x1080@144"
      #"video=DP-1:3440x1440@100"
    ];
  };
  users.groups.plugdev = { };
  users.users.sangmin.extraGroups = [
    "plugdev"
    "dialout"
  ];
  services.udev.packages = [ pkgs.openocd ];

  services.udev.extraRules = ''
    # https://raw.githubusercontent.com/raspberrypi/picotool/master/udev/60-picotool.rules
    # Copy this file to /etc/udev/rules.d/
    # You can reload the udev rules with "udevadm control --reload"

    SUBSYSTEM=="usb", \
        ATTRS{idVendor}=="2e8a", \
        ATTRS{idProduct}=="0003", \
        TAG+="uaccess", \
        MODE="660", \
        GROUP="plugdev"
    SUBSYSTEM=="usb", \
        ATTRS{idVendor}=="2e8a", \
        ATTRS{idProduct}=="0009", \
        TAG+="uaccess", \
        MODE="660", \
        GROUP="plugdev"
    SUBSYSTEM=="usb", \
        ATTRS{idVendor}=="2e8a", \
        ATTRS{idProduct}=="000a", \
        TAG+="uaccess", \
        MODE="660", \
        GROUP="plugdev"
    SUBSYSTEM=="usb", \
        ATTRS{idVendor}=="2e8a", \
        ATTRS{idProduct}=="000f", \
        TAG+="uaccess", \
        MODE="660", \
        GROUP="plugdev"
  '';
  hardware = {
  };
  services.xserver.videoDrivers = [
    "amdgpu"
  ];

  nix.settings.trusted-users = [ "sangmin" ];
  programs.nix-ld.enable = true;
}
