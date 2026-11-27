{
  config,
  hostname,
  lib,
  pkgs,
  ...
}:
let
  name = builtins.baseNameOf (builtins.toString ./.);
  installOn = [ "blackchungus" ];
  shellApplication = pkgs.writeShellApplication {
    inherit name;
    # $vars inside single-quoted jq filters are jq variables, not shell ones
    excludeShellChecks = [ "SC2016" ];
    runtimeInputs = with pkgs; [
      jq
      procps
    ];
    text = ''
      MONADO_JSON="${config.services.monado.package}/share/openxr/1/openxr_monado.json"
      XRIZER_DIR="${pkgs.xrizer}/lib/xrizer"
    ''
    + builtins.readFile ./${name}.sh;
  };
in
lib.mkIf (lib.elem hostname installOn && config.services.monado.enable) {
  environment.systemPackages = [ shellApplication ];
}
