{
  config,
  isInstall,
  isWorkstation,
  lib,
  pkgs,
  username,
  ...
}:
{
  # Enable the threadirqs kernel parameter to reduce pipewire/audio latency
  boot = lib.mkIf config.services.pipewire.enable {
    # - Inpired by: https://github.com/musnix/musnix/blob/master/modules/base.nix#L56
    kernelParams = [ "threadirqs" ];
  };

  environment.systemPackages =
    with pkgs;
    lib.optionals isInstall [
      alsa-utils
      playerctl
      pulseaudio
      pulsemixer
    ]
    ++ lib.optionals (isInstall && isWorkstation) [ pwvucontrol ];

  services = {
    # https://nixos.wiki/wiki/PipeWire
    # https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-PipeWire#quantum-ranges
    # Debugging
    #  - pw-top                                            # see live stats
    #  - journalctl -b0 --user -u pipewire                 # see logs (spa resync is "bad")
    #  - pw-metadata -n settings 0                         # see current quantums
    #  - pw-metadata -n settings 0 clock.force-quantum 128 # override quantum
    #  - pw-metadata -n settings 0 clock.force-quantum 0   # disable override
    pipewire = {
      enable = true;
      alsa.enable = true;
      # Enable 32-bit support
      alsa.support32Bit = lib.mkForce config.hardware.graphics.enable32Bit;
      jack.enable = false;
      pulse.enable = true;
      wireplumber.enable = true;
    };
    pulseaudio.enable = lib.mkForce false;
  };

  # Allow members of the "audio" group to set RT priorities
  security = {
    # Inspired by musnix: https://github.com/musnix/musnix/blob/master/modules/base.nix#L87
    pam.loginLimits = [
      {
        domain = "@audio";
        item = "memlock";
        type = "-";
        value = "unlimited";
      }
      {
        domain = "@audio";
        item = "rtprio";
        type = "-";
        value = "99";
      }
      {
        domain = "@audio";
        item = "nofile";
        type = "soft";
        value = "99999";
      }
      {
        domain = "@audio";
        item = "nofile";
        type = "hard";
        value = "99999";
      }
    ];
    rtkit.enable = true;
  };

  services = {
    # use `lspci -nn`
    udev.extraRules = ''
      # Remove AMD Audio devices; if present
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1002", ATTR{class}=="0xab28", ATTR{power/control}="auto", ATTR{remove}="1"
      # Remove NVIDIA Audio devices; if present
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1"
      # Expose important timers the members of the audio group
      # Inspired by musnix: https://github.com/musnix/musnix/blob/master/modules/base.nix#L94
      KERNEL=="rtc0", GROUP="audio"
      KERNEL=="hpet", GROUP="audio"
      # Allow users in the audio group to change cpu dma latency
      DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"
    '';
  };

  users.users.${username}.extraGroups =
    lib.optional config.security.rtkit.enable "rtkit"
    ++ lib.optional config.services.pipewire.enable "audio";
}
