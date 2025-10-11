{
  lib,
  pkgs,
  hostname,
  ...
}:
let
  installOn = [ "blackchungus" ];
in

lib.mkIf (lib.elem "${hostname}" installOn) {

  services.ollama = {
    acceleration = "rocm";
    enable = true;
    package = pkgs.unstable.ollama-rocm;
  };
}
