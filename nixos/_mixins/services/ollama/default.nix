{
  config,
  isWorkstation,
  lib,
  pkgs,
  hostname,
  tailNet,
  ...
}:
let
  installOn = [ "blackchungus" ];
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  services.open-webui = {
    enable = true;
    port = 8123;
    host = if config.services.tailscale.enable then "${hostname}.${tailNet}" else "127.0.0.1";
  };

  # The tailnet hostname only resolves once tailscaled is up
  systemd.services.open-webui = lib.mkIf config.services.tailscale.enable {
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
  };
}
