{ lib, ... }:
{
  imports = [
    ./ollama
    ./calendar
    ./nix-serve
    ./github-runner
    ./ssh
    ./tailscale
    ./unifi
    ./actual-server
    ./garage
    ./suwayomi
    ./sjsufood
  ];
}
