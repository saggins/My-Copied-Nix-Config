# Public Minecraft entrypoint on bastion. Gate runs in Lite mode: it routes by the
# handshake hostname to backend servers over the tailnet and then just pipes bytes, so
# modded clients (Forge's "\0FML\0" handshake marker is kept intact) work unchanged.
# Each route's hostname must point at bastion. Backends do their own auth, so they
# run with online-mode=true and should only be reachable on the tailnet.
# Hostnames are kept out of the repo: they live in secrets/bastion/gate.yaml and are
# filled into the config by a sops template.
{
  config,
  hostname,
  lib,
  pkgs,
  tailNet,
  ...
}:
let
  installOn = [ "bastion" ];
  port = 25565;

  sopsFile = ../../../../secrets/bastion/gate.yaml;

  servers = {
    rlcraft = {
      domain = config.sops.placeholder."gate/rlcraft-domain";
      address = "workhorse.${tailNet}:25565";
      motd = "RLCraft";
    };
  };

  route = s: {
    host = s.domain;
    backend = s.address;
    fallback = {
      motd = "§c${s.motd} is offline.\n§eCheck back later!";
      version = {
        name = "§cOffline";
        protocol = -1;
      };
    };
  };

  # JSON is valid YAML, and a sops template needs a string to substitute into
  gateConfig = builtins.toJSON {
    config = {
      bind = "0.0.0.0:${toString port}";
      lite = {
        enabled = true;
        # Routes match in order; unknown hostnames fall through to the first server
        routes = map route (lib.attrValues servers) ++ [
          (route (lib.head (lib.attrValues servers)) // { host = "*"; })
        ];
      };
      connectionTimeout = "5s";
      readTimeout = "30s";
    };
    connect.enabled = false;
    api.enabled = false;
  };
in
lib.mkIf (lib.elem hostname installOn) {
  sops = {
    secrets = lib.mapAttrs' (
      name: _: lib.nameValuePair "gate/${name}-domain" { inherit sopsFile; }
    ) servers;
    templates."gate.yml" = {
      content = gateConfig;
      restartUnits = [ "gate.service" ];
    };
  };

  systemd.services.gate = {
    description = "Gate Minecraft proxy";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "tailscaled.service"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      # The template is root-only; LoadCredential hands the DynamicUser a readable copy
      LoadCredential = "gate.yml:${config.sops.templates."gate.yml".path}";
      ExecStart = "${lib.getExe pkgs.gate} --config %d/gate.yml";
      DynamicUser = true;
      Restart = "on-failure";
      RestartSec = 10;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
