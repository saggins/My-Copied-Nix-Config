{ pkgs, username, lib, ... }:
let
  installFor = [ "sangmin" ];
in
lib.mkIf (lib.elem "${username}" installFor) {

    services.safeeyes.enable = true;
}  
