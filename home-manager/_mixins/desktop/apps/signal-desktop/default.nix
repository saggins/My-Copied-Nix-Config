{
  config,
  lib,
  pkgs,
  username,
  isWorkstation,
  ...
}:
let
  # Signal Desktop should only be installed on workstations and laptops, not on servers like bastion or workhorse
  # It's a desktop application meant for end-users, not server environments
  installFor = [ "sangmin" ];
  inherit (pkgs.stdenv) isLinux;
in
{
  home = {
    packages =
      with pkgs;
      lib.optionals (isWorkstation && lib.elem username installFor) [
        signal-desktop
      ];
  };
}
