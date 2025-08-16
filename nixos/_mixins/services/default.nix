{ lib, ... }:
{
  imports = [
    ./ollama
    ./calendar
    ./nix-serve
    ./ssh
    ./tailscale
    ./unifi
    ./actual-server
  ];
}
