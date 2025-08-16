{
  hostname,
  lib,
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

  services.caddy = lib.mkIf (config.services.actual.enable && config.services.tailscale.enable ) {
    enable = true;
    virtualHosts."${hostname}.${tailNet}" = {
      extraConfig = ''
        redir ${basePath} ${basePath}/
        handle_path ${basePath}/* {
          reverse_proxy ${config.services.actual.hostname}:${config.services.actual.port}
          header_up ${config.services.actual.hostname}
        }
      '';
    }
  };
  # networking.firewall.trustedInterfaces = [ "enp0s31f6" ];
}
