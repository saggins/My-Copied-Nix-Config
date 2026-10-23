# Self-hosted GitHub Actions runner for this repo's build workflows.
# Builds land in workhorse's /nix/store, which nix-serve then shares as workhorse.comet-court.ts.net.
#  - Needs `github-runner-token` in secrets/workhorse.yaml: a fine-grained PAT scoped to
#    saggins/My-Copied-Nix-Config with "Administration: read & write", so the runner can
#    re-register itself.
#  - The repo is public: never run these jobs on pull_request, and keep fork PR workflows
#    requiring approval (Settings -> Actions -> General).
{
  config,
  hostname,
  lib,
  pkgs,
  ...
}:
let
  installOn = [ "workhorse" ];
  gcrootsDir = "/nix/var/nix/gcroots/ci";
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  services.github-runners.${hostname} = {
    enable = true;
    url = "https://github.com/saggins/My-Copied-Nix-Config";
    tokenFile = config.sops.secrets.github-runner-token.path;
    extraLabels = [ hostname ];
    replace = true;
    user = "github-runner";
    group = "github-runner";
    extraPackages = with pkgs; [
      config.nix.package
      coreutils
      gnugrep
      gnused
    ];
    # Let workflows keep their latest builds alive as GC roots
    serviceOverrides.ReadWritePaths = [ gcrootsDir ];
  };

  users.users.github-runner = {
    isSystemUser = true;
    group = "github-runner";
  };
  users.groups.github-runner = { };

  systemd.tmpfiles.rules = [ "d ${gcrootsDir} 0755 github-runner github-runner" ];

  sops.secrets.github-runner-token = {
    owner = "github-runner";
    sopsFile = ../../../../secrets/workhorse.yaml;
  };
}
