{
  lib,
  pkgs,
  username,
  ...
}:
# Steam-machine style HTPC: boot straight into Steam's gamescope session, with a
# minimal Plasma desktop reachable via Steam's "Switch to Desktop" for debugging.
#
# SDDM autologs into the `htpc` session, which reads a one-shot choice left by
# `steamos-session-select` and execs either gamescope or Plasma. With relogin on,
# SDDM starts it again whenever a session ends, so exiting Plasma (or running
# "Return to Gaming Mode") lands back in Steam.
let
  # Hybrid graphics is off in BIOS, so the Quadro drives every connector. Prefer
  # the external ports (TV) and fall back to the laptop panel.
  preferredOutputs = [
    "DP-4"
    "DP-1"
    "DP-2"
    "DP-3"
    "DP-5"
    "eDP-1"
  ];

  stateFile = ''"''${XDG_STATE_HOME:-$HOME/.local/state}/steamos-session-select"'';

  plasmaDesktop = "${pkgs.kdePackages.plasma-workspace.sessions}/share/wayland-sessions/plasma.desktop";

  htpc-session = pkgs.writeShellApplication {
    name = "htpc-session";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
    ];
    text = ''
      choice="$(cat ${stateFile} 2>/dev/null || echo gamescope)"
      # Desktop mode is one-shot: the next relogin goes back to Steam.
      rm -f ${stateFile}
      case "$choice" in
        plasma)
          # shellcheck disable=SC2046
          exec $(sed -n 's/^Exec=//p' ${plasmaDesktop})
          ;;
        *)
          # Start the --mangoapp overlay hidden; Steam rewrites this file when
          # its performance overlay level changes.
          export MANGOHUD_CONFIGFILE="''${XDG_RUNTIME_DIR:-/tmp}/htpc-mangohud.conf"
          echo no_display > "$MANGOHUD_CONFIGFILE"
          exec /run/current-system/sw/bin/steam-gamescope
          ;;
      esac
    '';
  };

  htpcSessionFile =
    (pkgs.writeTextDir "share/wayland-sessions/htpc.desktop" ''
      [Desktop Entry]
      Name=HTPC
      Comment=Steam gamescope session with Plasma as a switchable desktop
      Exec=${lib.getExe htpc-session}
      Type=Application
    '').overrideAttrs
      (_: {
        passthru.providedSessions = [ "htpc" ];
      });

  # Steam (launched with -steamos3) calls this from "Switch to Desktop".
  steamos-session-select = pkgs.writeShellApplication {
    name = "steamos-session-select";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      case "''${1:-gamescope}" in
        plasma*)
          mkdir -p "$(dirname ${stateFile})"
          echo plasma > ${stateFile}
          # Let Steam save state; gamescope exits with it and SDDM relogs.
          /run/current-system/sw/bin/steam -shutdown || loginctl terminate-session "''${XDG_SESSION_ID:-}"
          ;;
        *)
          rm -f ${stateFile}
          loginctl terminate-session "''${XDG_SESSION_ID:-}"
          ;;
      esac
    '';
  };

  # SteamOS helpers Steam probes for in -steamos3 mode; 7 means "no update".
  steamos-update = pkgs.writeShellScriptBin "steamos-update" "exit 7";
  steamos-select-branch = pkgs.writeShellScriptBin "steamos-select-branch" "echo rel";

  returnToGamingMode = pkgs.makeDesktopItem {
    name = "return-to-gaming-mode";
    desktopName = "Return to Gaming Mode";
    exec = "${lib.getExe steamos-session-select} gamescope";
    icon = "steam";
    categories = [ "Game" ];
  };

  steamosHelpers = [
    steamos-session-select
    steamos-update
    steamos-select-branch
  ];
in
{
  # Steam itself, Remote Play firewall and DualSense/DS4 touchpad udev rules.
  imports = [ ../_mixins/desktop/apps/steam ];

  programs.steam = {
    extraPackages = steamosHelpers;
    gamescopeSession = {
      enable = true;
      args = [
        "--prefer-output"
        (lib.concatStringsSep "," preferredOutputs)
        "--xwayland-count"
        "2"
        # Pascal + proprietary driver blanks the whole screen whenever the
        # cursor is hidden, which gamepadui always does. Running mangoapp
        # keeps it compositing. https://github.com/ValveSoftware/gamescope/issues/1252
        "--mangoapp"
      ];
      steamArgs = [
        "-steamos3"
        "-gamepadui"
        "-pipewire-dmabuf"
      ];
    };
  };

  services = {
    desktopManager.plasma6.enable = true;
    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
        autoLogin.relogin = true;
      };
      autoLogin = {
        enable = true;
        user = username;
      };
      defaultSession = "htpc";
      sessionPackages = [ htpcSessionFile ];
    };
    # Plasma pulls these in by default; nothing here needs them.
    orca.enable = false;
    # Configured here rather than via the desktop pipewire mixin: that one
    # removes NVIDIA HDA devices, which is where the TV's DP audio comes from.
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
  };
  security.rtkit.enable = true;
  programs.kde-pim.enable = false;

  # Keep Plasma to a debug desktop: shell, terminal, file manager, settings.
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    ark
    aurorae
    baloo-widgets
    dolphin-plugins
    elisa
    ffmpegthumbs
    gwenview
    kate
    khelpcenter
    krdp
    ktexteditor
    kwin-x11
    okular
    plasma-browser-integration
    plasma-keyboard
    plasma-workspace-wallpapers
    qtvirtualkeyboard
    spectacle
  ];

  environment.systemPackages = steamosHelpers ++ [ returnToGamingMode ];
}
