{
  pkgs,
  ...
}:
let
  prepare-rpi-usb = pkgs.writeShellApplication {
    name = "prepare-rpi-usb";
    runtimeInputs = with pkgs; [
      curl
      gawk
      gnugrep
      openssl
      util-linux
      uutils-coreutils-noprefix
      xz
    ];
    text = builtins.readFile ./prepare-rpi-usb.sh;
  };
in
{
  environment.systemPackages = with pkgs; [ prepare-rpi-usb ];
}
