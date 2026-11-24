# Nextcloud + WebDAV, tailnet-only at https://workhorse.<tailNet>:8447 behind
# Caddy with the Tailscale cert (same pattern as Gitea on 8445). The Nextcloud
# module builds its own nginx + php-fpm stack bound to loopback on <nginxPort>;
# Caddy terminates TLS and proxies. Admin login is the local `nextcloud-admin`
# user whose password comes from sops (nextcloud-admin-pass in workhorse.yaml);
# create app passwords in the web UI for WebDAV clients. WebDAV lives at
# /remote.php/webdav (files) and /remote.php/dav (CalDAV/CardDAV).
#
# Storage: the datadir (config/ and data/) lives on the NAS over NFS, under
# FamilyShare so the NAS's own backup covers it. The database stays in the local
# PostgreSQL. The export must squash workhorse to nextcloud's ids, e.g. the Unraid
# rule `<workhorse tailnet IP>(rw,sec=sys,all_squash,anonuid=980,anongid=977)`,
# and FamilyShare/nextcloud must exist and be owned by 980:977. Root (tmpfiles)
# then also writes as nextcloud, and nextcloud-setup's ownership check passes.
#
# Requires the sops key `nextcloud-admin-pass` in secrets/workhorse.yaml before
# switching, or nextcloud-setup and sops fail. Never write that file yourself:
# the user edits secrets/ directly.
{
  config,
  hostname,
  lib,
  pkgs,
  tailNet,
  ...
}:
let
  installOn = [ "workhorse" ];
  cfg = config.services.nextcloud;
  domain = "${hostname}.${tailNet}";
  publicPort = 8447; # 8444 is Authentik, 8445 Gitea, 8446 pebble-ring
  nginxPort = 41080; # loopback-only; 80 is nginx's for nix-serve
  # Pinned so files on the NAS keep matching after a reinstall; must match the
  # export's anonuid/anongid
  uid = 980;
  gid = 977;
  nfsDevice = "cheesecake.${tailNet}:/mnt/user/FamilyShare/nextcloud";
  datadir = "/mnt/nextcloud";
in
lib.mkIf (lib.elem hostname installOn) {
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud34;
    # Only names the nginx vhost; it must differ from nix-serve's (named after
    # domain), or the two merge and the cache moves off :80
    hostName = "nextcloud.internal";
    inherit datadir;
    maxUploadSize = "16G";
    https = false; # Caddy terminates TLS
    database.createLocally = true;
    config = {
      # Must be set explicitly (module assertion); db password is auto-managed
      dbtype = "pgsql";
      adminuser = "nextcloud-admin";
      adminpassFile = config.sops.secrets.nextcloud-admin-pass.path;
    };
    settings = {
      # Everything arrives through Caddy on this https URL
      "overwrite.cli.url" = "https://${domain}:${toString publicPort}/";
      overwriteprotocol = "https";
      trusted_domains = [ domain ];
      trusted_proxies = [ "127.0.0.1" ];
      maintenance_window_start = 1;
    };
  };

  users.users.nextcloud.uid = uid;
  users.groups.nextcloud.gid = gid;

  # Mounted at boot but nofail, so a NAS outage doesn't hold up boot; the units
  # below need the mount instead, so they never run against the empty mountpoint.
  fileSystems.${datadir} = {
    device = nfsDevice;
    fsType = "nfs";
    options = [
      "nfsvers=4"
      "hard"
      "_netdev"
      "nofail"
      "x-systemd.after=tailscaled.service"
      "x-systemd.mount-timeout=30s"
    ];
  };
  systemd.services =
    lib.genAttrs
      [
        "nextcloud-setup"
        "nextcloud-cron"
        "nextcloud-update-db"
        "phpfpm-nextcloud"
      ]
      (_: {
        unitConfig.RequiresMountsFor = datadir;
      });

  # The module's nginx vhost defaults to :80, where nix-serve's vhost lives; pin
  # Nextcloud's to a loopback port for Caddy. It's the only vhost on that port, so
  # it answers whatever Host Caddy forwards.
  services.nginx.virtualHosts.${cfg.hostName}.listen = lib.mkForce [
    {
      addr = "127.0.0.1";
      port = nginxPort;
    }
  ];

  sops.secrets.nextcloud-admin-pass = {
    owner = "nextcloud";
    group = "nextcloud";
    mode = "0400";
    sopsFile = ../../../../secrets/workhorse.yaml;
    restartUnits = [ "nextcloud-setup.service" ];
  };

  services.caddy = lib.mkIf config.services.tailscale.enable {
    enable = true;
    virtualHosts."${domain}:${toString publicPort}" = {
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString nginxPort}
      '';
    };
  };
}
