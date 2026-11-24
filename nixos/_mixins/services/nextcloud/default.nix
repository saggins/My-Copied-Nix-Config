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
# Sign-in: "Log in with Authentik" via the user_oidc app (blueprints/nextcloud.yaml in
# the authentik mixin). Accounts are created on first login and named after the
# Authentik username; members of "authentik Admins" (akadmin) land in Nextcloud's
# admin group. The local nextcloud-admin stays as a break-glass login.
#
# Requires the sops keys `nextcloud-admin-pass` and `nextcloud-oidc-secret` in
# secrets/workhorse.yaml (the latter also as NEXTCLOUD_OIDC_CLIENT_SECRET in
# authentik-env) before switching, or nextcloud-setup and sops fail. Never write that file yourself:
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
  discoveryUrl = "https://${domain}:8444/application/o/nextcloud/.well-known/openid-configuration";
  # Must match NEXTCLOUD_OIDC_CLIENT_SECRET in the authentik env file
  oidcSecretFile = config.sops.secrets.nextcloud-oidc-secret.path;
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
    extraApps = { inherit (cfg.package.packages.apps) user_oidc; };
    extraAppsEnable = true;
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
      # Authentik is reached on a tailnet (100.64.0.0/10) address, which Nextcloud's
      # HTTP client refuses as "local" otherwise
      allow_local_remote_servers = true;
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
      })
    // {
      # Create or update the Authentik provider in user_oidc from config; reruns
      # whenever this script changes. Retries while Authentik is still starting.
      nextcloud-authentik-sso = {
        description = "Configure Nextcloud's Authentik login";
        after = [
          "nextcloud-setup.service"
          "authentik.service"
        ];
        requires = [ "nextcloud-setup.service" ];
        wants = [ "authentik.service" ];
        wantedBy = [ "multi-user.target" ];
        startLimitIntervalSec = 600;
        startLimitBurst = 20;
        unitConfig.RequiresMountsFor = datadir;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = 15;
          User = "nextcloud";
          Group = "nextcloud";
        };
        script = ''
          ${lib.getExe cfg.occ} user_oidc:provider authentik \
            --clientid=nextcloud \
            --clientsecret-file=${oidcSecretFile} \
            --discoveryuri=${discoveryUrl} \
            --scope="openid email profile nextcloud" \
            --unique-uid=0 \
            --mapping-uid=preferred_username \
            --mapping-display-name=name \
            --mapping-email=email \
            --group-provisioning=1 \
            --mapping-groups=nextcloud_groups
        '';
      };
    };

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

  sops.secrets.nextcloud-oidc-secret = {
    owner = "nextcloud";
    group = "nextcloud";
    mode = "0400";
    sopsFile = ../../../../secrets/workhorse.yaml;
    restartUnits = [ "nextcloud-authentik-sso.service" ];
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
