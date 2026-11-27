{ inputs, pkgs, ... }:
{
  environment.systemPackages = [
    inputs.pwndbg.packages.${pkgs.stdenv.hostPlatform.system}.pwndbg-lldb
    pkgs.ollama
  ];
}
