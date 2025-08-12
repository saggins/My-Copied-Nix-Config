{
  hostname,
  lib,
  pkgs,
  ...
}:
let
  installOn = [ "workhorse" ];

in
lib.mkIf (lib.elem "${hostname}" installOn) {
  services.caddy = {
    enable = true;
    package = pkgs.xcaddy;
    email = "sangmin@sagg.in";
    acmeCA = throw "haven't set the acmeCA, consider going off branch";
  };

  services.step-ca = {
    enable = true;
    openFirewall = true;
    settings = ''
      # TODO: Just make sure caddy CA root authority and caddy CA 
      # OR: have a intermediate CA only for cadyCA
    '';

  };
}
