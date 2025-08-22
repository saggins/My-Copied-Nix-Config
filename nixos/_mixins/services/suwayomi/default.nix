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
      ip = lib.mkIf (config.services.tailscale.enable) "${hostname}.${tailNet}" || "127.0.0.1";
      port = 25039;
    };
  };
}
