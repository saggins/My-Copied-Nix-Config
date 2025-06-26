{
  config,
  isWorkstation,
  lib,
  pkgs,
  hostname,
  ...
}:
let
  installOn = [ "blackchungus" ];
in
lib.mkIf (builtins.elem hostname installOn) {
services.nix-serve = {
  enable = true;
  secretKeyFile = "/var/lib/private/binarycache/cache-priv-key.pem";
};


services.nginx = {
  enable = true;
  recommendedProxySettings = true;
  virtualHosts = {
    # ... existing hosts config etc. ...
    "binarycache.sagg.in" = {
      locations."/".proxyPass = "http://${config.services.nix-serve.bindAddress}:${toString config.services.nix-serve.port}";
    };
  };
};

}
