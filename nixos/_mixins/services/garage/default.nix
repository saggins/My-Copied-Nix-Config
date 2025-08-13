{
  hostname,
  lib,
  config,
  pkgs,
  ...
}:
let
  installOn = [ "workhorse" ];
  smbPath = "/mnt/cheesecakeExternalHdd";
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  # mounting smb 
  environment.systemPackages = lib.mkIf config.services.garage.enable [pkgs.cifs-utils];
  fileSystems."${smbPath}" = lib.mkIf config.services.garage.enable {
    device = "//10.0.0.166/8dgjdweh/garage";
    fsType = "cifs";
    options = let 
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
      user_perms = "uid=1000,gid=1000,file_mode=0777,dir_mode=0777";
    in ["${automount_opts},${user_perms},credentials=/etc/nixos/smb-secrets"];
  };

  services.garage = {
    enable= true;
    package= pkgs.garage_2;
    settings = {
      data_dir = [
        {
          path = smbPath;
          capacity = "10T";
        }
      ];
      db_engine = "sqlite";
      replication_factor = 1;
      rpc_bind_addr = "[::]:3901";
      rpc_public_addr = "100.99.219.83:3901";

      s3_api= {
        s3_region = "garage";
        api_bind_addr = "[::]:3900";
        root_domain = ".s3.garage.internal.sagg.in";
      };

      s3_web= {
        bind_addr = "[::]:3902";
        root_domain = ".web.garage.internal.sagg.in";
        index = "index.html";
      };

      k2v_api = {
        api_bind_addr = "[::]:3904";
      };

      admin= {
        api_bind_addr = "[::]:3903";
      };

    };
    environmentFile = config.sops.secrets.garage-env.path;
  };
  networking.firewall = lib.mkIf config.services.garage.enable {allowedTCPPorts = [3900];};
  sops = {
    secrets = {
      garage-smb-secrets = lib.mkIf config.services.garage.enable {
        mode= "600";
        owner = "root";
        group = "root";
        path = "/etc/nixos/smb-secrets";
        sopsFile = ../../../../secrets/garage.yaml;
      };
      garage-env  = lib.mkIf config.services.garage.enable {
        mode= "0644";
        sopsFile = ../../../../secrets/garage.yaml;
      };
    };
  };
}
