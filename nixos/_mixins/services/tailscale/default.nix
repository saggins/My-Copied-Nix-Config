{
  config,
  hostname,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
let
  # Declare which hosts have Tailscale enabled.
  installOn = [
    "bastion"
    "blackchungus"
    "workhorse"
  ];
  # Hosts that accept SSH over the tailnet via Tailscale SSH
  tsSshHosts = [
    "bastion"
  ];
  tsExitNodes = [
    "workhorse"
  ];
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  environment.systemPackages = with pkgs; lib.optionals isWorkstation [ trayscale ];

  services.tailscale = {
    enable = true;
    # Stable lags several releases behind; track unstable for security fixes
    package = pkgs.unstable.tailscale;
    extraUpFlags = [
      "--operator=${username}"
    ]
    ++ lib.optional (lib.elem "${hostname}" tsExitNodes) "--advertise-exit-node"
    ++ lib.optional (lib.elem "${hostname}" tsSshHosts) "--ssh";
    extraSetFlags = [
      "--operator=${username}"
    ]
    ++ lib.optional (lib.elem "${hostname}" tsExitNodes) "--advertise-exit-node"
    ++ lib.optional (lib.elem "${hostname}" tsSshHosts) "--ssh";
    # Enable caddy to acquire certificates from the tailscale daemon
    # - https://tailscale.com/blog/caddy
    permitCertUid = lib.mkIf config.services.caddy.enable "caddy";
    openFirewall = true;
    useRoutingFeatures = "both";
  };
}