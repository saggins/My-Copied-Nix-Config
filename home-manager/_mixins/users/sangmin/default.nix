 
{
  config,
  hostname,
  isLima,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;
in 
 {
  home = {
    packages = lib.mkIf (isLinux && !isLima)  [
      pkgs.zotero
      pkgs.libreoffice
      pkgs.discord
    ];
  };
  wayland.windowManager.hyprland = {
    extraConfig = lib.mkIf (isLinux && !isLima)  ''
      exec-once = [workspace 8 silent] /home/sangmin/share/gs.sh
    '';
  };


    programs.git = {
      userEmail = "sangmin@sagg.in";
      userName = "Sangmin Chun";
    };

    systemd.user.tmpfiles = lib.mkIf (isLinux && !isLima) {
    rules = [
      "d ${config.home.homeDirectory}/Crypt 0755 ${username} users - -"
      "d ${config.home.homeDirectory}/Vaults/HomeworkFolder 0755 ${username} users - -"
      "d ${config.home.homeDirectory}/Vaults/Secrets 0755 ${username} users - -"
    ];
  };

}

