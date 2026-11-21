# hermes-agent: Nous Research's Hermes Agent, run headless as the gateway systemd service.
# Module comes from the hermes-agent flake input (services.hermes-agent).
#
# - addToSystemPackages puts the `hermes` CLI on PATH and exports HERMES_HOME system-wide, so
#   running `hermes` in a terminal shares config, sessions, skills and cron with the service
#   instead of creating a separate ~/.hermes.
# - State lives in /var/lib/hermes (group-writable by `hermes`); ${username} is added to the
#   group so the CLI can read/write it. Log out/in after the first switch for the group.
# - API keys: run `hermes setup` (writes $HERMES_HOME/.env), or move them to sops and set
#   environmentFiles below.
{
  hostname,
  lib,
  username,
  ...
}:
let
  installOn = [ "workhorse" ];
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;
    # environmentFiles = [ config.sops.secrets.hermes-env.path ];
  };

  # sops.secrets.hermes-env = {
  #   sopsFile = ../../../../secrets/hermes.yaml;
  #   key = "env";
  #   owner = "hermes";
  #   restartUnits = [ "hermes-agent.service" ];
  # };

  users.users.${username}.extraGroups = [ "hermes" ];
}
