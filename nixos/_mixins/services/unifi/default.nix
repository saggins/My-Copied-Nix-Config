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
    "workhorse"
  ];
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  services.unifi = {
    enable=true;
    openFirewall=true;
  };

}