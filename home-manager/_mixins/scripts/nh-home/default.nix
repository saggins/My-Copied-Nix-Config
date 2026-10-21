{ pkgs, tailNet, ... }:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = with pkgs; [
      bc
      uutils-coreutils-noprefix
      nh
    ];
    text = builtins.readFile ./${name}.sh;
  };
  buildHome = pkgs.writeScriptBin "build-home" ''nh-home build'';
  switchHome = pkgs.writeScriptBin "switch-home" ''nh-home switch'';
  # Build bastion here and push it over Tailscale SSH; the VPS is too small to build itself
  switchVpsHome = pkgs.writeScriptBin "switch-vps-home" ''nh-home switch bastion.${tailNet}'';
in
{
  home.packages = with pkgs; [
    shellApplication
    buildHome
    switchHome
    switchVpsHome
  ];
}
