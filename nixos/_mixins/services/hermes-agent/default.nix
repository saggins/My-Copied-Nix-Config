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
# - Miyo: search over the notes Miyo indexes, via its stdio MCP server (see mcpServers below).
{
  config,
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

    # Miyo (services.miyo, a user service for ${username}). `miyo mcp` is stdio and forwards
    # tool calls to the engine's local API, so it works from the hermes user without access
    # to ~/.config/Miyo. It starts with nothing shared: after Hermes calls it once, run
    # `miyo connections` and `miyo connections share <app> <folder>`.
    mcpServers.miyo = lib.mkIf config.services.miyo.enable {
      command = lib.getExe config.services.miyo.package;
      args = [ "mcp" ];
      env.MIYO_URL = "http://127.0.0.1:8742";
    };
  };

  # sops.secrets.hermes-env = {
  #   sopsFile = ../../../../secrets/hermes.yaml;
  #   key = "env";
  #   owner = "hermes";
  #   restartUnits = [ "hermes-agent.service" ];
  # };

  users.users.${username}.extraGroups = [ "hermes" ];
}
