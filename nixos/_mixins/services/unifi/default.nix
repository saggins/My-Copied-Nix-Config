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
    # Use the prebuilt MongoDB Community binary instead of compiling mongodb-7_0 from source
    mongodbPackage = pkgs.mongodb-ce;
  };

}