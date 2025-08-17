{
  hostname,
  lib,
  config,
  tailNet,
  pkgs,
  ...
}:
let
  installOn = [ "workhorse" ];
  basePath = "/actual";
in
lib.mkIf (lib.elem hostname installOn) {
  services.actual = {
    enable = true;
    package = pkgs.actual-server-updated;
    settings.hostname = "127.0.0.1";
    settings.webRoot = basePath;
  };

  services.caddy = lib.mkIf (config.services.actual.enable && config.services.tailscale.enable) {
    enable = true;
    virtualHosts."${hostname}.${tailNet}" = {
      extraConfig = ''
        handle_path ${basePath}/* {
          reverse_proxy ${config.services.actual.settings.hostname}:${builtins.toString config.services.actual.settings.port} {
        }
      '';
    };
  };
  # networking.firewall.trustedInterfaces = [ "enp0s31f6" ];
}
