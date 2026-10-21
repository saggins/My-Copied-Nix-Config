 
{
  config,
  hostname,
  isLightweight,
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
    packages = lib.mkIf (isLinux && !isLima && !isLightweight) [
      pkgs.zotero
      pkgs.libreoffice
      pkgs.discord
    ];
  };
  wayland.windowManager.hyprland = {
    # Appended to the hyprland.lua written by the hyprland mixin.
    extraConfig = lib.mkIf (isLinux && !isLima) ''
      hl.on("hyprland.start", function()
          hl.exec_cmd("/home/sangmin/share/gs.sh", { workspace = "8 silent" })
      end)
    '';
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

