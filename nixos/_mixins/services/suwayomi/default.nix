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
    package = pkgs.unstable.suwayomi-server;
    settings.server = {
      ip = if config.services.tailscale.enable then "${hostname}.${tailNet}" else "127.0.0.1";
      port = 25039;
    };
  };

  services.komga = {
    enable = true;
    settings.server.port = 44857;
  };
}
