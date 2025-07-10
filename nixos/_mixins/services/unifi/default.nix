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
    "workhorse"
  ];
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  services.unifi = {
    enable=true;
    openFirewall=true;
  };

}