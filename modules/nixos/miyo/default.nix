# NixOS module: services.miyo
# Headless Miyo engine (https://www.miyo.md/docs/headless). The package is pkgs/miyo, added
# to pkgs by overlays.additions.
#
# Runs as a systemd *user* service for `user`, like upstream's `miyo service install`: the
# `miyo` CLI and `miyo mcp` talk to the engine through files in its data dir
# (~/.config/Miyo by default) and 127.0.0.1:8742, so the engine must run as the same
# account that runs the CLI. Lingering is enabled so it starts at boot without a login.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.miyo;
  inherit (lib) mkOption types;
in
{
  options.services.miyo = {
    enable = lib.mkEnableOption "Miyo headless search engine";

    package = mkOption {
      type = types.package;
      default = pkgs.miyo;
      defaultText = lib.literalExpression "pkgs.miyo";
    };

    user = mkOption {
      type = types.str;
      description = "Account that runs the engine (as a user service) and the `miyo` CLI.";
    };

    dataDir = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/srv/miyo";
      description = ''
        Index, settings and logs (MIYO_APP_DATA_DIR). null keeps upstream's default,
        ~/.config/Miyo. When set it is also exported system-wide so the CLI finds it.
      '';
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        MIYO_PORT = "8742";
      };
      description = "Extra environment for the engine (MIYO_PORT, MIYO_MODELS_DIR, ...).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.variables = lib.optionalAttrs (cfg.dataDir != null) {
      MIYO_APP_DATA_DIR = cfg.dataDir;
    };

    # fs.inotify.max_user_watches: NixOS already defaults it to 524288, which is what
    # upstream recommends for libraries with thousands of sub-folders.
    users.users.${cfg.user}.linger = true;

    systemd.user.services.miyo = {
      description = "Miyo";
      wantedBy = [ "default.target" ];
      unitConfig.ConditionUser = cfg.user;
      # `ps` checks stale qdrant pids, `sleep` paces shutdown.
      path = [
        pkgs.procps
        pkgs.coreutils
      ];
      environment =
        cfg.environment
        // lib.optionalAttrs (cfg.dataDir != null) {
          MIYO_APP_DATA_DIR = cfg.dataDir;
        };
      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package} serve";
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStopSec = 30;
      };
    };
  };
}
