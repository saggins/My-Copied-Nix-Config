{ config, hostname, lib, ... }:
let
  locale = "en_US.UTF-8";
  consoleKeymap = "us";
  xkbLayout = "us";
in
{
  console = lib.mkIf (config.console.font != null) {
    keyMap = consoleKeymap;
  };
  i18n = {
    defaultLocale = locale;
    extraLocaleSettings = {
      LC_ADDRESS = locale;
      LC_IDENTIFICATION = locale;
      LC_MEASUREMENT = locale;
      LC_MONETARY = locale;
      LC_NAME = locale;
      LC_NUMERIC = locale;
      LC_PAPER = locale;
      LC_TELEPHONE = locale;
      LC_TIME = locale;
    };
  };
  services = {
    kmscon = lib.mkIf config.services.kmscon.enable {
      useXkbConfig = true;
    };
    xserver.xkb.layout = xkbLayout;
  };
}
