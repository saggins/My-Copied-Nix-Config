# Hermes Agent (Nous Research): CLI + Electron desktop app.
# No daemon and no managed API key: the provider/model and key are set on first run
# with `hermes config`, which writes ~/.hermes/.env.
{
  inputs,
  isWorkstation,
  lib,
  username,
  ...
}:
let
  installFor = [ "sangmin" ];
  enable = isWorkstation && lib.elem username installFor;
in
{
  imports = [ inputs.hermes-agent.homeManagerModules.default ];

  programs.hermes-agent = lib.mkIf enable {
    enable = true;
    desktop.enable = true;
  };
}
