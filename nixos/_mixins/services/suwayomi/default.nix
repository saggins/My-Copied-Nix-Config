{
  hostname,
  lib,
  pkgs,
  config,
  tailNet,
  ...
}:
let
  installOn = [ "workhorse" ];
  basePath = "/tachidesk";
  smbPath = "/mnt/manga";
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  services.suwayomi-server = {
    enable = true;
    package = pkgs.unstable.suwayomi-server;
    settings.server = {
      ip = if config.services.tailscale.enable then "${hostname}.${tailNet}" else "127.0.0.1";
      port = 25039;
      downloadAsCbz = true;
    };
  };

  services.komga = {
    enable = true;
    settings.server.port = 44857;
  };

  environment.systemPackages = lib.mkIf config.services.suwayomi-server.enable [ pkgs.cifs-utils ];
  fileSystems."${smbPath}" = lib.mkIf config.services.suwayomi-server.enable {
    device = "//10.0.0.166/manga";
    fsType = "cifs";
    options =
      let
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
        user_perms = "uid=1000,gid=1000,file_mode=0777,dir_mode=0777";
      in
      [ "${automount_opts},${user_perms},credentials=/etc/nixos/smb-secrets" ];
  };
  sops = {
    secrets = {
      workhorse-smb-secrets = lib.mkIf config.services.suwayomi-server.enable {
        mode = "600";
        owner = "root";
        group = "root";
        path = "/etc/nixos/smb-secrets";
        sopsFile = ../../../../secrets/workhorse.yaml;
      };
    };
  };
}
