{ pkgs, username, ... }:
{
  # taken from https://nixos.wiki/wiki/Steam#gamescope
  # TODO: Enable username checking. just in case, multiple nixos becoems a thing
  boot.kernelPackages = pkgs.linuxPackages;
  programs = {
    gamescope = {
      enable = true;
      capSysNice = true;
    };
    steam = {
      enable = true;
      gamescopeSession.enable = true;
      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };
  };

  hardware.xone.enable = true; # xbox cvontroler
  environment = {
    systemPackages = [ pkgs.mangohud ];
  };

}
