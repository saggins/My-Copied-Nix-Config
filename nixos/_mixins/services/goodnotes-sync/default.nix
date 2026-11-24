# GoodNotes -> Obsidian sync for the school vault. GoodNotes Auto-Backup uploads one PDF
# per notebook to Nextcloud (files/sangmin/GoodNotes/); every 5 minutes the vault's
# Scripts/goodnotes_sync.py renders new or changed pages to JPGs under Assets/GoodNotes,
# writes a fleeting note per new page, then commits only its own paths and pushes. Which
# notebooks sync, and the WebDAV URL, live in the vault's Scripts/goodnotes_config.json.
#
# - Runs as the goodnotes-sync user from its own clone in /var/lib/goodnotes-sync/school,
#   cloned on first run. The script and its config come from that clone, so changes to
#   them land with the next pull, no rebuild needed.
# - Pushes over Gitea's SSH (gitea@workhorse.<tailNet>) with a write deploy key on the
#   school-notes repo only. Connects by the tailnet name: the gitea sshd Match only
#   accepts keys from tailnet addresses.
# - Secrets in secrets/workhorse.yaml: goodnotes-sync/webdav-password (a Nextcloud app
#   password for sangmin) and goodnotes-sync/deploy-key (the private key). Both reach
#   the unit via LoadCredential, never the store.
# - goodnotes-sync-dry-run runs the same thing with --dry-run (no pull, no writes).
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
  user = "goodnotes-sync";
  stateDir = "/var/lib/goodnotes-sync";
  vault = "${stateDir}/school";
  gitHost = "workhorse.${tailNet}";
  remote = "gitea@${gitHost}:sangmin/school-notes.git";

  secrets = {
    webdav-password = "goodnotes-sync/webdav-password";
    deploy-key = "goodnotes-sync/deploy-key";
  };

  mkService = description: args: {
    inherit description;
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [
      pkgs.git
      pkgs.openssh
      pkgs.poppler-utils
      pkgs.python3
    ];
    environment = {
      HOME = stateDir;
      GIT_AUTHOR_NAME = "GoodNotes Sync";
      GIT_AUTHOR_EMAIL = "goodnotes-sync@${hostname}";
      GIT_COMMITTER_NAME = "GoodNotes Sync";
      GIT_COMMITTER_EMAIL = "goodnotes-sync@${hostname}";
    };
    serviceConfig = {
      Type = "oneshot";
      User = user;
      Group = user;
      StateDirectory = "goodnotes-sync";
      StateDirectoryMode = "0750";
      LoadCredential = lib.mapAttrsToList (
        name: secret: "${name}:${config.sops.secrets.${secret}.path}"
      ) secrets;
    };
    script = ''
      # Pin Gitea's host key to this host's own sshd key, which is what it presents
      echo "${gitHost} $(cat /etc/ssh/ssh_host_ed25519_key.pub)" > ${stateDir}/known_hosts
      export GIT_SSH_COMMAND="ssh -i $CREDENTIALS_DIRECTORY/deploy-key -o IdentitiesOnly=yes -o UserKnownHostsFile=${stateDir}/known_hosts -o StrictHostKeyChecking=yes"
      if [ ! -d ${vault}/.git ]; then
        git clone ${remote} ${vault}
      fi
      exec python3 ${vault}/Scripts/goodnotes_sync.py ${args}
    '';
  };
in
lib.mkIf (lib.elem hostname installOn) {
  users.users.${user} = {
    isSystemUser = true;
    group = user;
    home = stateDir;
  };
  users.groups.${user} = { };

  sops.secrets = lib.genAttrs (lib.attrValues secrets) (_: {
    sopsFile = ../../../../secrets/workhorse.yaml;
  });

  systemd.services.goodnotes-sync = mkService "Sync GoodNotes backups into the school vault" "--git";
  systemd.services.goodnotes-sync-dry-run = mkService "GoodNotes sync dry run" "--git --dry-run";

  systemd.timers.goodnotes-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/5";
      RandomizedDelaySec = 30;
    };
  };
}
