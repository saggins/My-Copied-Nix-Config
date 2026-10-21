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
  buildHost = pkgs.writeScriptBin "build-host" ''nh-host build'';
  switchHost = pkgs.writeScriptBin "switch-host" ''nh-host switch'';
  # Build bastion here and push it over Tailscale SSH; the VPS is too small to build itself
  switchVpsHost = pkgs.writeScriptBin "switch-vps-host" ''nh-host switch bastion.${tailNet}'';
in
{
  environment.systemPackages = with pkgs; [
    shellApplication
    buildHost
    switchHost
    switchVpsHost
  ];
}
