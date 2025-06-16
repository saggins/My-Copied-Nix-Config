{
  config,
  isWorkstation,
  hostname,
  lib,
  pkgs,
  ...
}:
let
  installOn = [ "blackchungus"];
in
{
  services.syncthing = {
    enable = true;
  };
}
