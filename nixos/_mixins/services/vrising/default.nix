# V Rising dedicated server. The server is Windows-only, so it runs under Wine in the
# trueosiris/vrising container on workhorse; the image downloads/updates the game with
# SteamCMD on every start (~2GB the first time).
#
# - Logs: `journalctl -u podman-vrising -f`. Data and saves in /var/lib/vrising/data.
# - Settings live in /var/lib/vrising/data/Settings/*.json. The image patches them on start
#   from HOST_SETTINGS_* / GAME_SETTINGS_* env vars (case-insensitive key match), so set
#   anything managed here through those rather than editing the files.
# - Public entrypoint is bastion, which DNATs UDP to workhorse over the tailnet. The server
#   isn't listed on Steam/EOS (it would advertise workhorse's home IP); players use
#   Direct Connect to bastion's IP on the game port.
# - Password lives in secrets/workhorse.yaml as vrising/password.
{
  config,
  hostname,
  lib,
  ...
}:
let
  serverHost = "workhorse";
  relayHost = "bastion";

  gamePort = 9876;
  queryPort = 9877;
  ports = "${toString gamePort}:${toString queryPort}";

  # DNAT needs literal addresses
  bastionPublicIp = "107.172.75.145";
  workhorseTailIp = "100.99.219.83";

  dataDir = "/var/lib/vrising";
in
lib.mkMerge [
  (lib.mkIf (hostname == serverHost) {
    sops = {
      secrets."vrising/password".sopsFile = ../../../../secrets/workhorse.yaml;
      templates."vrising.env" = {
        content = ''
          HOST_SETTINGS_PASSWORD=${config.sops.placeholder."vrising/password"}
        '';
        restartUnits = [ "podman-vrising.service" ];
      };
    };

    virtualisation.oci-containers.containers.vrising = {
      image = "docker.io/trueosiris/vrising:3.0";
      ports = [
        "${toString gamePort}:${toString gamePort}/udp"
        "${toString queryPort}:${toString queryPort}/udp"
      ];
      volumes = [
        "${dataDir}/server:/mnt/vrising/server"
        "${dataDir}/data:/mnt/vrising/persistentdata"
      ];
      environment = {
        TZ = lib.mkIf (config.time.timeZone != null) config.time.timeZone;
        SERVERNAME = "Zero";
        WORLDNAME = "world1";
        GAMEPORT = toString gamePort;
        QUERYPORT = toString queryPort;
        HOST_SETTINGS_MAXCONNECTEDUSERS = "10";
        HOST_SETTINGS_SECURE = "true";
        HOST_SETTINGS_LISTONSTEAM = "false";
        HOST_SETTINGS_LISTONEOS = "false";
        HOST_SETTINGS_GAMESETTINGSPRESET = "StandardPvP";
        GAME_SETTINGS_GAMEMODETYPE = "PvP";
      };
      environmentFiles = [ config.sops.templates."vrising.env".path ];
    };

    systemd.tmpfiles.rules = [
      "d ${dataDir}/server 0750 root root -"
      "d ${dataDir}/data 0750 root root -"
    ];
    # tailscale0 is a trusted interface, so bastion can already reach the ports
  })

  (lib.mkIf (hostname == relayHost) {
    # Forward the game/query ports to workhorse over the tailnet. MASQUERADE is required:
    # replies have to come back through bastion, and Tailscale drops forwarded packets
    # whose source isn't a tailnet address. IP forwarding is on via tailscale's
    # useRoutingFeatures, and the firewall doesn't filter FORWARD.
    networking.firewall = {
      extraCommands = ''
        iptables -t nat -A PREROUTING -d ${bastionPublicIp} -p udp --dport ${ports} -j DNAT --to-destination ${workhorseTailIp}
        iptables -t nat -A POSTROUTING -o tailscale0 -d ${workhorseTailIp} -p udp --dport ${ports} -j MASQUERADE
      '';
      extraStopCommands = ''
        iptables -t nat -D PREROUTING -d ${bastionPublicIp} -p udp --dport ${ports} -j DNAT --to-destination ${workhorseTailIp} || true
        iptables -t nat -D POSTROUTING -o tailscale0 -d ${workhorseTailIp} -p udp --dport ${ports} -j MASQUERADE || true
      '';
    };
  })
]
