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
  environment.systemPackages = [ pkgs.rustdesk];
  services.rustdesk-server = {
    enable = true;
    openFirewall = true;
  };
}
