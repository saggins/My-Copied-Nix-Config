# Binary cache for the other hosts, served over Tailscale as workhorse.comet-court.ts.net.
# The github-runner mixin builds into this store; clients trust it in features/nix.
#  - Signing key: `nix-store --generate-binary-cache-key workhorse.comet-court.ts.net-1 priv.pem pub.pem`,
#    priv.pem goes in secrets/workhorse.yaml as `nix-serve-key`, pub.pem in features/nix.
{
  config,
  lib,
  hostname,
  ...
}:
let
  installOn = [ "workhorse" ];
in
lib.mkIf (builtins.elem hostname installOn) {
  services.nix-serve = {
    enable = true;
    secretKeyFile = config.sops.secrets.nix-serve-key.path;
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts = {
      "workhorse.comet-court.ts.net" = {
        locations."/".proxyPass =
          "http://${config.services.nix-serve.bindAddress}:${toString config.services.nix-serve.port}";
      };
    };
  };

  # nginx owns :80 for the cache, so keep Caddy's HTTP->HTTPS redirect listener off it
  services.caddy.globalConfig = lib.mkIf config.services.caddy.enable ''
    auto_https disable_redirects
  '';

  # Only reachable over the tailnet
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 80 ];

  sops.secrets.nix-serve-key = {
    sopsFile = ../../../../secrets/workhorse.yaml;
  };
}
