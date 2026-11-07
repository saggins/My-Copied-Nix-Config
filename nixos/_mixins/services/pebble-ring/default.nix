# pebble-ring: webhook receiver for the Index 01 ring (whisper.cpp + LLM classify + actions).
# Runs in a NixOS container on workhorse; source and module live in the pebble-ring flake.
#
# - Shares the host network (privateNetwork = false), so it reaches the tailnet services it
#   calls (Ollama on the host, Home Assistant, Gitea) and binds 127.0.0.1:${port} on the host.
# - Exposed to the ring at https://workhorse.<tailnet>:${httpsPort}/webhooks/ring by Caddy
#   (tailscale cert), like the other tailnet HTTPS services on workhorse. tailscale0 is a
#   trusted interface, so no firewall rule is needed.
# - LLM: services.ollama on the host (127.0.0.1:11434), CUDA built for the Quadro P3000.
# - Secrets: secrets/pebble-ring.yaml, one flat key per name in `secretNames`. Each is
#   decrypted on the host by sops-nix and bind-mounted read-only into the container.
{
  config,
  hostname,
  inputs,
  lib,
  pkgs,
  stateVersion,
  tailNet,
  ...
}:
let
  installOn = [ "workhorse" ];
  port = 8017;
  httpsPort = 8446;
  llmModel = "gemma4:e2b";
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
          LLM_URL = "http://127.0.0.1:11434/v1"; # services.ollama on the host
          LLM_MODEL = llmModel;
          NOTES_TZ = "America/Los_Angeles";
          GITEA_URL = "https://workhorse.${tailNet}:8445";
          WHISPER_THREADS = 4;
        };
      };
    };
  };

  # Quadro P3000 is Pascal (sm_61). nixpkgs' CUDA 12.9 still supports it, but the default
  # cudaCapabilities start at 7.5, so build ollama's CUDA kernels for sm_61 only. Not in the
  # binary cache: the first build compiles on workhorse.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda.override { cudaArches = [ "sm_61" ]; };
    host = "127.0.0.1";
    port = 11434;
    loadModels = [ llmModel ];
  };

  services.caddy = lib.mkIf config.services.tailscale.enable {
    enable = true;
    virtualHosts."${hostname}.${tailNet}:${toString httpsPort}".extraConfig = ''
      reverse_proxy 127.0.0.1:${toString port}
    '';
  };
}
