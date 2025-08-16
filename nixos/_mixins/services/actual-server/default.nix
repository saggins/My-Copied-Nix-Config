{
  hostname,
  lib,
  ...
}:
let
  installOn = [ "workhorse" ];
in
lib.mkIf (lib.elem hostname installOn) {
  services.actual = {
    enable = true;
    settings.hostname = "10.0.0.179";
  };
  # networking.firewall.trustedInterfaces = [ "enp0s31f6" ];
}
