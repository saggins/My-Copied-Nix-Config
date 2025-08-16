{
  hostname,
  lib,
  config,
  ...
}:
let
  installOn = [ "workhorse" ];
in
lib.mkIf (lib.elem hostname installOn) {
  services.actual = {
    enable = true;
  };

  services.caddy = lib.mkIf (config.services.actual.enable && config.services.tailscale.enable ) {
    enable = true;
    virtualHosts."actual.${hostname}.ts.net" = {
      extraConfig = ''
        reverse_proxy ${config.services.actual.settings.hostname}:${builtins.toString config.services.actual.settings.port}
      '';
    };
  };
  # networking.firewall.trustedInterfaces = [ "enp0s31f6" ];
}
