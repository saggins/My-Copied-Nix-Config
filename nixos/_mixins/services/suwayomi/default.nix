{
  hostname,
  lib,
  pkgs,
  config,
  tailNet
  ...
}:
let
  installOn = [ "workhorse" ];
  basePath = "tachidesk";
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  services.suwayomi-server = {
    enable = true;
  };

  services.caddy =
    lib.mkIf (config.services.suwayomi-server.enable && config.services.tailscale.enable)
      {
        enable = true;
        virtualHosts."${hostname}.${tailNet}" = {
          extraConfig = ''
            handle_path ${basePath}/* {
              reverse_proxy ${config.services.suwayomi-server.settings.ip}:${builtins.toString config.services.suwayomi-server.settings.port} {
            }
          '';
        };
      };
}
