{
  config,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
  installFor = [ "sangmin" ];
in
lib.mkIf (lib.elem "${username}" installFor) {
  services.open-webui = {
    enable=true;
    port=8123;
  };
}
