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
    "workhouse"
  ];
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  services.unifi = {
    enable=true;
    openFirewall=true;
  };

}