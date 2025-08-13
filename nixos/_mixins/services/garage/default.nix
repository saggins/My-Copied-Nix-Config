{
  hostname,
  lib,
  config,
  pkgs,
  ...
}:
let
  installOn = [ "workhorse" ];
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  sops.secrets= {
    garage-config= {
      group ="garage";
      user = "garage";
      mode = "0644";
      path = "/mnt/data/garage/garage-config.ini";
      sopsFile = ../../../../secrets/garage.yaml;
    };
  };
  services.garage = {
    enable= true;
    package= pkgs.garage_2;
    settings = builtins.readFile config.sops.secrets.garage-config.path;
  };
}
