# Bigscreen Beyond (original) on the RX 7800 XT.
# https://vronlinux.org/docs/hardware/bigscreen-beyond/
# - Kernel patches come from that page: the EDID/DSC series (7.3+ variant) lets amdgpu
#   drive the panel at all, the DSC fix removes artifacts in detailed scenes.
# - Monado and SteamVR are both usable; `vr-runtime monado|steamvr` (nixos/_mixins/scripts)
#   picks which one apps load. Under Monado, OpenVR games go through xrizer and the overlay
#   is `wayvr`; under SteamVR launch it from Steam and run `steam-run wayvr`.
#   Monado also socket-activates when an OpenXR app connects.
# - SteamVR's compositor wants CAP_SYS_NICE, which NixOS can't grant declaratively; after
#   SteamVR installs/updates: sudo setcap CAP_SYS_NICE=eip ~/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrcompositor-launcher
# - Refresh rate (75/90Hz) can't be switched from Linux. List the modes with:
#   STEAMVR_LH_ENABLE=1 XRT_COMPOSITOR_LOG=debug XRT_COMPOSITOR_PRINT_MODES=1 monado-service 2>&1 >/dev/null | grep -E '(choose_best_vk_mode_auto|get_primary_display_mode)'
# - Beyond Utility under Proton 10+: launch options
#   `PROTON_ENABLE_HIDRAW=0x35BD/0x0101,0x35BD/0x4004,0x35BD/0x1001 %command%`.
{ inputs, pkgs, ... }:
{
  boot.kernelPatches = [
    {
      name = "bigscreen-beyond-edid-dsc";
      patch = ./patches/bigscreen-beyond-kernel.patch;
    }
    {
      name = "amd-bsb-dsc-fix";
      patch = ./patches/amd-bsb-dsc-fix.patch;
    }
  ];

  # hidraw access for the Beyond (normal, firmware and error modes)
  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0101", MODE="0660", GROUP="plugdev", TAG+="uaccess"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="4004", MODE="0660", GROUP="plugdev", TAG+="uaccess"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="1001", MODE="0660", GROUP="plugdev", TAG+="uaccess"
  '';

  # Desktop/window overlay: `wayvr` under Monado, `steam-run wayvr` under SteamVR
  environment.systemPackages = [ pkgs.wayvr ];

  # Let pressure-vessel import the host OpenXR runtime (Monado) into Steam games;
  # replaces the per-game launch option
  programs.steam.package = pkgs.steam.override {
    extraProfile = ''
      export PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
    '';
  };

  services.monado = {
    enable = true;
    # Built against our nixpkgs via the overlay: OpenXR apps dlopen libopenxr_monado.so,
    # so it must share their glibc (nixpkgs-xr's prebuilt one needs a newer glibc)
    package = (pkgs.extend inputs.nixpkgs-xr.overlays.default).monado;
    defaultRuntime = true;
    highPriority = true;
  };

  systemd.user.services.monado.environment = {
    # SteamVR's lighthouse driver tracks better than libsurvive; needs SteamVR installed
    STEAMVR_LH_ENABLE = "1";
    # Trackers/controllers that show up after discovery ends are dropped
    LH_DISCOVER_WAIT_MS = "6000";
    # Stop Monado shortly after the last OpenXR app exits
    IPC_EXIT_WHEN_IDLE = "1";
    # The Beyond Utility can't set IPD on Linux; set your measured value here
    # LH_OVERRIDE_IPD_MM = "64";
    # Pick 75/90Hz once the mode listing (see header) shows both
    # XRT_COMPOSITOR_DESIRED_MODE = "1";
  };
}
