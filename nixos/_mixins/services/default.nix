{ lib, ... }:
{
  imports = [
    ./ollama
    ./calendar
    ./nix-serve
    ./ssh
    ./tailscale
    ./unifi
    ./garage
    ./actual-server
  ];
}
