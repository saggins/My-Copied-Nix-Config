{
  config,
  hostname,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
  installOn = [
    "blackchungus"
  ];
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  services.unifi = {
    enable=true;
    openFirewall=true;
  };

}