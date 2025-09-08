{ pkgs, ... }:
{

  services.ollama = {
    acceleration = "rocm";
    enable = true;
    package = pkgs.unstable.ollama-rocm;
  };
}
