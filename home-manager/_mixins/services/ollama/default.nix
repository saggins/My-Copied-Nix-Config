{
  lib,
  pkgs,
  hostname,
  ...
}:
let
  installOn = [ "blackchungus" ];
in

lib.mkIf (lib.elem "${hostname}" installOn) {

  services.ollama = {
    acceleration = "rocm";
    enable = true;
    package = pkgs.ollama-rocm;
    # Listen on all interfaces; the firewall only trusts tailscale0, so this
    # exposes Ollama to the tailnet (and localhost) but not the LAN
    host = "0.0.0.0";
    environmentVariables = {
      # Default context is too small for agentic coding tools
      OLLAMA_CONTEXT_LENGTH = "32768";
      OLLAMA_FLASH_ATTENTION = "1";
      # Quantised KV cache roughly halves context VRAM use
      OLLAMA_KV_CACHE_TYPE = "q8_0";
    };
  };
}
