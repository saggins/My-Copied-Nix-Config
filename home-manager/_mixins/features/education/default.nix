{ isLightweight, lib, config, pkgs, ... }: {

  home = {
    packages = lib.optionals (!isLightweight) [
      pkgs.obsidian
    ];
  };
}
