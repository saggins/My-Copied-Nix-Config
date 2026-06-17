 
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
    # exec-once via settings (merges with the list in the hyprland mixin) instead of
    # a raw extraConfig string.
    settings.exec-once = lib.mkIf (isLinux && !isLima) [
      "[workspace 8 silent] /home/sangmin/share/gs.sh"
    ];
  };


    programs.git = {
      settings.user.email = "sangmin@sagg.in";
      settings.user.name = "Sangmin Chun";
    };

    systemd.user.tmpfiles = lib.mkIf (isLinux && !isLima) {
    rules = [
      "d ${config.home.homeDirectory}/Crypt 0755 ${username} users - -"
      "d ${config.home.homeDirectory}/Vaults/HomeworkFolder 0755 ${username} users - -"
      "d ${config.home.homeDirectory}/Vaults/Secrets 0755 ${username} users - -"
    ];
  };

}

