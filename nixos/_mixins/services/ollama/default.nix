{
  config,
  isWorkstation,
  lib,
  pkgs,
  hostname,
  ...
}:
let
  installOn = [ "blackchungus" ];
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  services.open-webui = {
    enable = true;
    port = 8123;
    host = "100.115.55.118";
  };
}
