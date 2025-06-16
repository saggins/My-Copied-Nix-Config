{pkgs, ...}: {
  home = {
    packages = [
      pkgs.zotero
      pkgs.libreoffice
      pkgs.discord
    ];
  };
  wayland.windowManager.hyprland = {
    extraConfig =''
      exec-once = [workspace 8 silent] /home/sangmin/share/gs.sh
    '';
  };


    programs.git = {
      userEmail = "sangmin@sagg.in";
      userName = "Sangmin Chun";
    };

}

