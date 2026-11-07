# pebble-ring: webhook receiver for the Index 01 ring (whisper.cpp + LLM classify + actions).
# Runs in a NixOS container on workhorse; source and module live in the pebble-ring flake.
#
# - Shares the host network (privateNetwork = false), so it reaches the tailnet services it
#   calls (LM Studio on dorado, Home Assistant, Gitea) and binds 127.0.0.1:${port} on the host.
# - Exposed to the ring at https://workhorse.<tailnet>:${httpsPort}/webhooks/ring via
#   `tailscale serve` (oneshot below).
# - Secrets: secrets/pebble-ring.yaml, one flat key per name in `secretNames`. Each is
#   decrypted on the host by sops-nix and bind-mounted read-only into the container.
{
  config,
  hostname,
  inputs,
  lib,
  stateVersion,
  tailNet,
  ...
}:
let
  installOn = [ "workhorse" ];
  port = 8017;
  httpsPort = 8446;
  # Must match the module's services.pebble-ring.secretFiles options.
  secretNames = [
    "INDEX_WEBHOOK_SECRET"
    "HA_TOKEN"
    "GITEA_TOKEN"
  ];
  secretDir = "/run/pebble-ring-secrets";
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  sops.secrets = lib.genAttrs (map (n: "pebble-ring-${n}") secretNames) (name: {
    sopsFile = ../../../../secrets/pebble-ring.yaml;
    key = lib.removePrefix "pebble-ring-" name;
    restartUnits = [ "container@pebble-ring.service" ];
  });

  containers.pebble-ring = {
    autoStart = true;
    privateNetwork = false;
    bindMounts = lib.listToAttrs (
      map (n: {
        name = "${secretDir}/${n}";
        value = {
          hostPath = config.sops.secrets."pebble-ring-${n}".path;
          isReadOnly = true;
        };
      }) secretNames
    );

    config = {
      imports = [ inputs.pebble-ring.nixosModules.default ];
      system.stateVersion = stateVersion;

      services.pebble-ring = {
        enable = true;
        host = "127.0.0.1";
        inherit port;
        secretFiles = lib.genAttrs secretNames (n: "${secretDir}/${n}");
        settings = {
          LMSTUDIO_URL = "http://dorado.${tailNet}:1234/v1";
          NOTES_TZ = "America/Los_Angeles";
          GITEA_URL = "https://workhorse.${tailNet}:8445";
          WHISPER_THREADS = 4;
        };
      };
    };
  };

  # Persistent tailscale serve mapping: https://workhorse.<tailnet>:8446 -> 127.0.0.1:8017.
  systemd.services.pebble-ring-tailscale-serve = lib.mkIf config.services.tailscale.enable {
    description = "tailscale serve for pebble-ring";
    wantedBy = [ "multi-user.target" ];
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe config.services.tailscale.package} serve --bg --https=${toString httpsPort} http://127.0.0.1:${toString port}";
      ExecStop = "${lib.getExe config.services.tailscale.package} serve --https=${toString httpsPort} off";
    };
  };
}
