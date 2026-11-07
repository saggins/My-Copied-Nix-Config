# NAS share for service backups, so they survive a reinstall of workhorse. Mounted with
# the garage SMB user; client-side it's root:nas-backup 0770, so a service writes here by
# joining the nas-backup group. Each backup job should set RequiresMountsFor= on its
# directory and create that directory itself, since tmpfiles can run before the share
# is mounted.
{
  config,
  pkgs,
  tailNet,
  ...
}:
let
  mount = "/mnt/workhorse-backup";
in
{
  users.groups.nas-backup = { };

  environment.systemPackages = [ pkgs.cifs-utils ];
  fileSystems.${mount} = {
    device = "//cheesecake.${tailNet}/FamilyShare/workhorse";
    fsType = "cifs";
    options = [
      "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s"
      "uid=root,gid=nas-backup,file_mode=0660,dir_mode=0770"
      "credentials=${config.sops.secrets.workhorse-backup-smb.path}"
    ];
  };

  # The garage SMB user's credentials, under their own path: garage and suwayomi both
  # write theirs to /etc/nixos/smb-secrets
  sops.secrets.workhorse-backup-smb = {
    key = "garage-smb-secrets";
    mode = "0400";
    sopsFile = ../../secrets/garage.yaml;
  };
}
