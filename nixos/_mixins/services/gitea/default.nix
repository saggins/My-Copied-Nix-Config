# Gitea for Obsidian notes (obsidian-git over HTTPS), tailnet-only at
# https://workhorse.<tailNet>:8445 behind Caddy with the Tailscale cert. Sign-in is via
# Authentik (blueprints/gitea.yaml in the authentik mixin); members of "authentik Admins"
# become Gitea admins. Git over SSH is off: Obsidian mobile only speaks HTTPS, so clients
# push with a Gitea access token.
#
# Recovery: the nightly `gitea dump` on the NAS holds the database, repositories and
# custom/ (including Gitea's generated secret keys). The Authentik login source is
# re-created from this file by gitea-authentik-sso.
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
  cfg = config.services.gitea;
  domain = "${hostname}.${tailNet}";
  publicPort = 8445; # 8444 is Authentik
  httpPort = 3001; # 3000 is taken on workhorse
  rootUrl = "https://${domain}:${toString publicPort}/";
  discoveryUrl = "https://${domain}:8444/application/o/gitea/.well-known/openid-configuration";
  backupDir = "/mnt/workhorse-backup/gitea";

  # Must match GITEA_OIDC_CLIENT_SECRET in the authentik env file
  oidcSecretFile = config.sops.secrets.gitea-oidc-secret.path;

  giteaEnv = {
    USER = cfg.user;
    HOME = cfg.stateDir;
    GITEA_WORK_DIR = cfg.stateDir;
    GITEA_CUSTOM = cfg.customDir;
  };
in
lib.mkIf (lib.elem hostname installOn) {
  services.gitea = {
    enable = true;
    database.type = "postgres";
    settings = {
      server = {
        DOMAIN = domain;
        ROOT_URL = rootUrl;
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = httpPort;
        DISABLE_SSH = true;
      };
      # Accounts only come from Authentik
      service = {
        DISABLE_REGISTRATION = false;
        ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
        SHOW_REGISTRATION_BUTTON = false;
      };
      oauth2_client = {
        ENABLE_AUTO_REGISTRATION = true;
        USERNAME = "nickname"; # Authentik sends the username as nickname
        ACCOUNT_LINKING = "auto";
      };
      openid = {
        ENABLE_OPENID_SIGNIN = false;
        ENABLE_OPENID_SIGNUP = false;
      };
      repository.DEFAULT_PRIVATE = "private";
      session.COOKIE_SECURE = true;
    };
    dump = {
      enable = true;
      inherit backupDir;
      type = "tar.zst";
    };
  };

  sops.secrets.gitea-oidc-secret = {
    owner = cfg.user;
    group = cfg.group;
    mode = "0400";
    sopsFile = ../../../../secrets/workhorse.yaml;
    restartUnits = [ "gitea-authentik-sso.service" ];
  };

  # Create or update the Authentik login source from config; reruns whenever this
  # script changes
  systemd.services.gitea-authentik-sso = {
    description = "Configure Gitea's Authentik login source";
    after = [ "gitea.service" ];
    requires = [ "gitea.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [
      cfg.package
      pkgs.gawk
    ];
    environment = giteaEnv;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = cfg.user;
      Group = cfg.group;
    };
    script = ''
      args=(
        --name authentik
        --provider openidConnect
        --key gitea
        --secret "$(cat ${oidcSecretFile})"
        --auto-discover-url ${discoveryUrl}
        --scopes openid --scopes email --scopes profile
        --group-claim-name groups
        --admin-group "authentik Admins"
        --skip-local-2fa
      )
      id=$(gitea admin auth list | awk '$2 == "authentik" { print $1 }')
      if [ -n "$id" ]; then
        gitea admin auth update-oauth --id "$id" "''${args[@]}"
      else
        gitea admin auth add-oauth "''${args[@]}"
      fi
    '';
  };

  # Dumps go to the NAS share (nixos/workhorse/backup.nix). The module's tmpfiles rule
  # can run before the share is up, so the job makes its own dir; "-" lets the
  # pre-start step run before the dir exists. Keeps two weeks of dumps.
  users.users.${cfg.user}.extraGroups = [ "nas-backup" ];
  # The module also lists the dump dir in gitea.service's ReadWritePaths, which makes
  # Gitea itself fail to start when the NAS is down or the dir isn't there yet. Only
  # gitea-dump writes there, so leave it out (the rest mirrors the module's list).
  systemd.services.gitea.serviceConfig.ReadWritePaths = lib.mkForce [
    cfg.customDir
    cfg.repositoryRoot
    cfg.stateDir
    cfg.lfs.contentDir
  ];
  systemd.services.gitea-dump = {
    unitConfig.RequiresMountsFor = backupDir;
    preStart = "mkdir -p ${backupDir}";
    serviceConfig = {
      WorkingDirectory = lib.mkForce "-${backupDir}";
      ExecStartPost = "${pkgs.findutils}/bin/find ${backupDir} -name 'gitea-dump-*' -mtime +14 -delete";
    };
  };

  # tailscale0 is a trusted interface, so publicPort is reachable on the tailnet only
  services.caddy = lib.mkIf config.services.tailscale.enable {
    enable = true;
    virtualHosts."${domain}:${toString publicPort}" = {
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString httpPort}
      '';
    };
  };
}
