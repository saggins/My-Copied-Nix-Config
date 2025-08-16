{
  hostname,
  lib,
  config,
  tailNet,
  ...
}:
let
  installOn = [ "workhorse" ];
  basePath = "/actual";
in
lib.mkIf (lib.elem hostname installOn) {
  services.actual = {
    enable = true;
  };

  services.caddy = lib.mkIf (config.services.actual.enable && config.services.tailscale.enable) {
    enable = true;
    virtualHosts."${hostname}.${tailNet}" = {
      extraConfig = ''
        redir ${basePath} ${basePath}/
        handle_path ${basePath}/* {
          reverse_proxy ${config.services.actual.settings.hostname}:${builtins.toString config.services.actual.settings.port}
          header_up ${config.services.actual.hostname}
        }
      '';
    };
  };
  # networking.firewall.trustedInterfaces = [ "enp0s31f6" ];
}
