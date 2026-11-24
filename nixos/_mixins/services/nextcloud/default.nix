# Nextcloud + WebDAV, tailnet-only at https://workhorse.<tailNet>:8447 behind
# Caddy with the Tailscale cert (same pattern as Gitea on 8445). The Nextcloud
# module builds its own nginx + php-fpm stack bound to loopback on <nginxPort>;
# Caddy terminates TLS and proxies. Admin login is the local `nextcloud-admin`
# user whose password comes from sops (nextcloud-admin-pass in workhorse.yaml);
# create app passwords in the web UI for WebDAV clients. WebDAV lives at
# /remote.php/webdav (files) and /remote.php/dav (CalDAV/CardDAV).
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
  nginxPort = 41080; # loopback-only; 80 is Caddy's on all interfaces
in
lib.mkIf (lib.elem hostname installOn) {
  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud34;
    hostName = domain;
    datadir = "/var/lib/nextcloud/data";
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
      overwrite.cli.url = "https://${domain}:${toString publicPort}/";
      overwriteprotocol = "https";
      trusted_proxies = [ "127.0.0.1" ];
      maintenance_window_start = 1;
    };
  };

  # The module's nginx vhost defaults to serving on :80; Caddy owns 80 on all
  # interfaces, so pin the vhost to a loopback port and re-list caddy there.
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
