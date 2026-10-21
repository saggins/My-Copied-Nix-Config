# Hybrid BIOS/UEFI layout so GRUB boots whichever firmware the KVM host uses.
# Check the device name from the Ubuntu image with `lsblk` before installing.
_: {
  disko.devices = {
    disk = {
      vda = {
        type = "disk";
        device = "/dev/vda";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              name = "boot";
              size = "1M";
              type = "EF02";
            };
            ESP = {
              name = "ESP";
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountOptions = [
                  "defaults"
                  "umask=0077"
                ];
                mountpoint = "/boot";
              };
            };
            root = {
              name = "root";
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountOptions = [
                  "defaults"
                  "noatime"
                ];
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
