_: {
  disko.devices = {
    disk = {
      mydisk = {
        type = "disk";
        device = "/dev/disk/by-id/ata-KINGSTON_SA400S37240G_50026B767438A3F8";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1024M";
              type = "EF00";
              content = {
                format = "vfat";
                mountOptions = [
                  "defaults"
                  "umask=0077"
                ];
                mountpoint = "/boot";
                type = "filesystem";
              };
            };
            root = {
              size = "100%";
              content = {
                extraArgs = [
                  "-f"
                  "--compression=lz4"
                  "--discard"
                ];
                format = "bcachefs";
                mountOptions = [
                  "defaults"
                  "compression=lz4"
                  "discard"
                  "relatime"
                  "nodiratime"
                ];
                mountpoint = "/";
                type = "filesystem";
              };
            };
          };
        };
      };
    };
  };
}
