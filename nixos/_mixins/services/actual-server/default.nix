{
  hostname,
  lib,
  ...
}:
let
  installOn = [ "workhorse" ];
in
lib.mkIf (lib.elem hostname installOn) {
  services.actual = {
    enable = true;
  };

  services.caddy = lib.mkIf (config.services.actual.enable) {
    enable = true;
    virtualHosts."actual.${hostname}.ts.net" = {
      extraConfig = ''
        reverse_proxy ${config.services.actual.hostname}:${config.services.actual.port}
      '';
    }

  }
  # networking.firewall.trustedInterfaces = [ "enp0s31f6" ];
}
