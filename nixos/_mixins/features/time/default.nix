{
  hostname,
  isLightweight,
  lib,
  ...
}:
let
  isServer = hostname == "malak" || hostname == "revan" || isLightweight;
  useGeoclue = !isServer;
in
{
  location = lib.mkIf (!isLightweight) {
    provider = "geoclue2";
  };

  services = {
    automatic-timezoned.enable = useGeoclue;
    geoclue2 = lib.mkIf (!isLightweight) {
      enable = true;
      # https://github.com/NixOS/nixpkgs/issues/321121
      geoProviderUrl = "https://api.positon.xyz/v1/geolocate?key=test";
      submissionUrl = "https://api.positon.xyz/v2/geosubmit?key=test";
      submitData = false;
    };
    localtimed.enable = useGeoclue;
  };

  # Prevent "Failed to open /etc/geoclue/conf.d/:" errors
  systemd.tmpfiles.rules = lib.optionals (!isLightweight) [
    "d /etc/geoclue/conf.d 0755 root root"
  ];

  time = {
    # VPS clocks are UTC
    hardwareClockInLocalTime = !isLightweight;
    timeZone = lib.mkIf isServer "UTC";
  };
}
