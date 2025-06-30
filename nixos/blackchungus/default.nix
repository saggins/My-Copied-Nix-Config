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
#    loader = {
#      systemd-boot.enable = lib.mkForce false;
#      grub = {
#      devices = ["nodev"];
#      enable=true;
#      extraEntriesBeforeNixOS=true;
#      extraEntries = ''
#      menuentry "Windows" {
#        insmod part_gpt
#        insmod fat
#        insmod search_fs_uuid
#        insmod chain
#        search --fs-uuid --set=root $FS_UUID
#        chainloader /EFI/Microsoft/Boot/bootmgfw.efi
#      }
#    '';
#      };
#    };
    loader.grub.extraConfig = ''
      # Look for hardware switch device by its hard-coded filesystem ID
    search --no-floppy --fs-uuid --set hdswitch 0000-1234

    # If found, read dynamic config file and select appropriate entry for each position
    if [ "''${hdswitch}" ] ; then
      source (''${hdswitch})/switch_position_grub.cfg

      if [ "''${os_hw_switch}" == 0 ] ; then
	# Boot Linux
	set default="1"
      elif [ "''${os_hw_switch}" == 1 ] ; then
	# Boot Windows
	set default="0"
      fi
    fi


    ''; 
    kernelModules = [
      "amdgpu"
      "kvm-amd"
    ];

    kernelParams = [
      "video=HDMI-A-1:3840x2160@60"
     #"video=DP-1:3440x1440@100"
    ];
  };

  hardware = {
  };
  services.xserver.videoDrivers = [
    "amdgpu"
  ];


  nix.settings.trusted-users = ["sangmin"];
}
