{
  hostname,
  lib,
  pkgs,
  config,
  tailNet,
  ...
}:
let
  installOn = [ "workhorse" ];
  basePath = "/tachidesk";
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  services.suwayomi-server = {
    enable = true;
    settings.server = {
      ip = "127.0.0.1";
      port = 25039;
    };
  };

  services.caddy =
    lib.mkIf (config.services.suwayomi-server.enable && config.services.tailscale.enable)
      {
        enable = true;
        virtualHosts."${hostname}.${tailNet}" = {
          extraConfig = ''
            handle_path ${basePath}/* {
              reverse_proxy ${config.services.suwayomi-server.settings.server.ip}:${builtins.toString config.services.suwayomi-server.settings.server.port} {
                header_up Host ${config.services.actual.settings.hostname}:${builtins.toString config.services.actual.settings.port}
              }
            }
          '';
        };
      };
}
