# Serves the public sjsufood.sagg.in from bastion, proxied over the tailnet to the
# app on workhorse:9012. Caddy gets the sagg.in cert from Let's Encrypt, so the
# DNS record must point at bastion and ports 80/443 must be open publicly.
{
  hostname,
  lib,
  tailNet,
  ...
}:
let
  installOn = [ "bastion" ];
  domain = "sjsufood.sagg.in";
  upstream = "workhorse.${tailNet}:9012";
in
lib.mkIf (lib.elem hostname installOn) {
  services.caddy = {
    enable = true;
    virtualHosts."${domain}" = {
      extraConfig = ''
        reverse_proxy http://${upstream}
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
