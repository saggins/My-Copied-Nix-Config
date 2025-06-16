{
  config,
  isWorkstation,
  lib,
  pkgs,
  hostname,
  ...
}:
let
  installOn = [ "bigchungus" ];
in
lib.mkIf (builtins.elem hostname installOn) {
  services.radicale= {
    enable=true;
  };
}
