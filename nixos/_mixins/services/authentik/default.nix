# Authentik SSO (later the IdP for Immich and Nextcloud), tailnet-only. The server and
# worker run on workhorse with a local PostgreSQL and listen on localhost; Caddy
# terminates TLS with the Tailscale cert at https://workhorse.<tailNet>:8444. It gets a
# port of its own because Authentik doesn't sit well under a subpath.
#
# Recovering after a reinstall comes from three places:
#  - ./blueprints (git): groups, users, flow/stage settings, later providers and apps.
#    Applied by the worker on start and whenever the files change.
#  - the env file (sops): AUTHENTIK_SECRET_KEY, the akadmin bootstrap password and the
#    OIDC client secrets the blueprints read with !Env.
#  - the nightly pg_dump: passwords, MFA devices, signing certs, anything clicked in the
#    UI. Restore before first start:
#      sudo systemctl stop authentik authentik-worker
#      zstdcat /mnt/workhorse-backup/postgresql/authentik.sql.zstd | sudo -u postgres psql authentik
#      sudo systemctl start authentik
#    Without a dump, the blueprints rebuild the config and akadmin logs in with the
#    bootstrap password; users then reset passwords and re-enrol MFA.
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
  publicPort = 8444; # 8443 is the UniFi controller
  httpListen = "127.0.0.1:9000";
  # On the NAS share from nixos/workhorse/backup.nix
  backupDir = "/mnt/workhorse-backup/postgresql";

  # Upstream's blueprints plus ours under nix/. Copied rather than symlinked: Python's
  # recursive glob doesn't follow symlinked directories. Directories are made fresh and
  # only files copied, since the sandbox refuses chmod on the copied store dirs.
  blueprints = pkgs.runCommand "authentik-blueprints" { } ''
    cd ${config.services.authentik.authentikComponents.staticWorkdirDeps}/blueprints
    find . -type d -exec mkdir -p $out/{} \;
    find . -type f -exec cp {} $out/{} \;
    mkdir $out/nix
    cp ${./blueprints}/*.yaml $out/nix/
  '';
in
lib.mkIf (lib.elem hostname installOn) {
  services.authentik = {
    enable = true;
    environmentFile = config.sops.secrets.authentik-env.path;
    settings = {
      blueprints_dir = "${blueprints}";
      # Since 2026.8 each listener is a list of addresses
      listen = {
        http = [ httpListen ];
        https = [ "127.0.0.1:9443" ];
        metrics = [ "127.0.0.1:9300" ];
        # Only Caddy on this host may set X-Forwarded-For
        trusted_proxy_cidrs = [
          "127.0.0.0/8"
          "::1/128"
        ];
      };
      disable_startup_analytics = true;
      avatars = "initials";
    };
  };

  # Dotenv file with AUTHENTIK_SECRET_KEY, AUTHENTIK_BOOTSTRAP_PASSWORD (only takes effect
  # when akadmin is first created) and GITEA_OIDC_CLIENT_SECRET
  sops.secrets.authentik-env = {
    mode = "0400";
    owner = "root";
    group = "root";
    sopsFile = ../../../../secrets/workhorse.yaml;
    restartUnits = [
      "authentik.service"
      "authentik-worker.service"
      "authentik-migrate.service"
    ];
  };

  services.postgresqlBackup = {
    enable = true;
    databases = [ "authentik" ];
    location = backupDir;
    compression = "zstd";
  };
  # Only run with the share mounted (pulls the mount in, fails the job if it can't). The
  # module's tmpfiles rule can fire before the share is up, so make the dir on it here.
  systemd.services.postgresqlBackup-authentik = {
    unitConfig.RequiresMountsFor = backupDir;
    preStart = "mkdir -p ${backupDir}";
  };
  users.users.postgres.extraGroups = [ "nas-backup" ];

  # tailscale0 is a trusted interface, so publicPort is reachable on the tailnet only
  services.caddy = lib.mkIf config.services.tailscale.enable {
    enable = true;
    virtualHosts."${hostname}.${tailNet}:${toString publicPort}" = {
      extraConfig = ''
        reverse_proxy http://${httpListen}
      '';
    };
  };
}
