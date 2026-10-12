{
  config,
  hostname,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  hyprlandPkgs = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system};
  hostMonitors = import ./monitors.nix { inherit lib; };
  layout = hostMonitors.${hostname} or hostMonitors.default;
  toLua = lib.generators.toLua { multiline = false; };

  hyprlock = lib.getExe pkgs.hyprlock;
  hyprshot = lib.getExe pkgs.hyprshot;
  satty = lib.getExe pkgs.satty;
  playerctl = lib.getExe pkgs.playerctl;
  swaync-client = "${pkgs.swaynotificationcenter}/bin/swaync-client";
in
{
  home.packages = with pkgs; [
    hyprpicker
  ];
  # Hyprland is a Wayland compositor and dynamic tiling window manager
  # Additional applications are required to create a full desktop shell
  imports = [
    ./avizo # on-screen display for audio and backlight
    ./fuzzel # app launcher, emoji picker and clipboard manager
    ./hyprlock # screen locker
    ./hyprpaper # wallpaper setter
    ./hyprshot # screenshot grabber and annotator
    ./swaync # notification center
    ./waybar # status bar
    ./wlogout # session menu
  ];
  services = {
    gpg-agent.pinentry.package = lib.mkForce pkgs.pinentry-gnome3;
    udiskie = {
      enable = true;
      automount = false;
      tray = "auto";
      notify = true;
    };
  };

  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    Unit.Description = "polkit-gnome-authentication-agent-1";
    Install.WantedBy = [ "hyprland-session.target" ];
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  wayland.windowManager.hyprland = {
    enable = true;
    # Hyprland >= 0.55 is configured with Lua (~/.config/hypr/hyprland.lua).
    # https://wiki.hypr.land/Configuring/Start/
    configType = "lua";
    package = hyprlandPkgs.hyprland;
    portalPackage = hyprlandPkgs.xdg-desktop-portal-hyprland;
    systemd = {
      enableXdgAutostart = true;
      variables = [ "--all" ];
    };
    xwayland.enable = true;
    # Written by hand rather than via `settings` so it reads like a normal
    # hyprland.lua. Other modules may append to this (it is a `lines` option).
    extraConfig = ''
      ------------------
      ---- MONITORS ----
      ------------------
      -- https://wiki.hypr.land/Configuring/Basics/Monitors/
      for _, m in ipairs(${toLua layout.monitors}) do
          hl.monitor(m)
      end

      -- https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
      for _, w in ipairs(${toLua layout.workspaces}) do
          hl.workspace_rule(w)
      end

      -------------------
      ---- AUTOSTART ----
      -------------------
      hl.on("hyprland.start", function()
          hl.exec_cmd("hypr-session start")
      end)

      -----------------------
      ---- LOOK AND FEEL ----
      -----------------------
      -- https://wiki.hypr.land/Configuring/Basics/Variables/
      hl.config({
          general = {
              gaps_in     = 5,
              gaps_out    = 5,
              border_size = 2,
              col = {
                  -- Catppuccin Mocha
                  active_border   = { colors = { "rgb(cba6f7)", "rgb(89b4fa)" }, angle = 45 },
                  inactive_border = "rgb(45475a)",
              },
              resize_on_border = true,
              layout = "dwindle",
          },

          decoration = {
              rounding = 8,
              shadow = {
                  enabled      = true,
                  range        = 4,
                  render_power = 3,
                  color        = "rgba(11111baf)",
              },
              blur = {
                  enabled = true,
                  size    = 3,
                  passes  = 1,
              },
          },

          animations = {
              enabled = true,
          },

          dwindle = {
              preserve_split = true,
          },

          misc = {
              background_color         = "rgb(1e1e2e)",
              disable_hyprland_logo    = true,
              disable_splash_rendering = true,
              focus_on_activate        = true,
          },

          input = {
              kb_layout    = "us",
              follow_mouse = 2,
              repeat_rate  = 30,
              repeat_delay = 300,
              touchpad = {
                  natural_scroll = true,
              },
          },

          xwayland = {
              force_zero_scaling = true,
          },
      })

      -- https://wiki.hypr.land/Configuring/Gestures/
      hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

      ---------------------
      ---- KEYBINDINGS ----
      ---------------------
      -- https://wiki.hypr.land/Configuring/Basics/Binds/
      local mainMod = "SUPER"

      -- Windows
      hl.bind(mainMod .. " + Q",    hl.dsp.window.close())
      hl.bind(mainMod .. " + up",   hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
      hl.bind(mainMod .. " + down", hl.dsp.window.float({ action = "toggle" }))
      hl.bind(mainMod .. " + P",    hl.dsp.window.pseudo())

      -- Applications
      hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("nautilus --new-window"))
      hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("foot"))

      -- Cycle focus (and raise) with ALT + Tab
      hl.bind("ALT + Tab",         hl.dsp.window.cycle_next({ next = true }))
      hl.bind("ALT + Tab",         hl.dsp.window.bring_to_top())
      hl.bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }))
      hl.bind("ALT + SHIFT + Tab", hl.dsp.window.bring_to_top())

      -- Move focus with ALT + arrows, swap windows with ALT + SUPER + arrows
      for _, dir in ipairs({ "left", "right", "up", "down" }) do
          hl.bind("ALT + " .. dir,                hl.dsp.focus({ direction = dir }))
          hl.bind("ALT + " .. mainMod .. " + " .. dir, hl.dsp.window.swap({ direction = dir }))
      end

      -- Workspaces: CTRL + ALT + [1-9] to switch, SUPER + ALT + [1-9] to move window
      for i = 1, 9 do
          hl.bind("CTRL + ALT + " .. i,          hl.dsp.focus({ workspace = i }))
          hl.bind(mainMod .. " + ALT + " .. i,   hl.dsp.window.move({ workspace = i }))
      end
      hl.bind("CTRL + ALT + left",  hl.dsp.focus({ workspace = "e-1" }))
      hl.bind("CTRL + ALT + right", hl.dsp.focus({ workspace = "e+1" }))

      -- Move windows with SUPER + LMB, or AltGr + LMB (for lefties)
      hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
      hl.bind("MOD5 + mouse:272",        hl.dsp.window.drag(), { mouse = true })

      -- Launcher, menus and pickers (fuzzel)
      hl.bind(mainMod .. " + SUPER_L", hl.dsp.exec_cmd("${pkgs.procps}/bin/pkill fuzzel || fuzzel-launcher"), { release = true })
      hl.bind(mainMod .. " + SPACE",   hl.dsp.exec_cmd("fuzzel-actions"))
      hl.bind("CTRL + ALT + SPACE",    hl.dsp.exec_cmd("hypr-activity-menu"))
      hl.bind("CTRL + ALT + B",        hl.dsp.exec_cmd("fuzzel-bluetooth"))
      hl.bind("CTRL + ALT + E",        hl.dsp.exec_cmd("fuzzel-emoji"))
      hl.bind("CTRL + ALT + K",        hl.dsp.exec_cmd("fuzzel-hyprpicker"))
      hl.bind("CTRL + ALT + P",        hl.dsp.exec_cmd("fuzzel-clipboard"))
      hl.bind("CTRL + ALT + R",        hl.dsp.exec_cmd("fuzzel-history"))
      hl.bind("CTRL + ALT + W",        hl.dsp.exec_cmd("fuzzel-wifi"))

      -- Notifications
      hl.bind("CTRL + ALT + N", hl.dsp.exec_cmd("${swaync-client} --toggle-panel --skip-wait"))

      -- Lock screen
      hl.bind(mainMod .. " + L",  hl.dsp.exec_cmd("${hyprlock} --immediate"))
      hl.bind("CTRL + ALT + L",   hl.dsp.exec_cmd("${hyprlock} --immediate"))

      -- Screenshots
      hl.bind("Print",              hl.dsp.exec_cmd("fuzzel-hyprshot"))
      hl.bind("ALT + Print",        hl.dsp.exec_cmd("${hyprshot} --mode active --mode window --raw | ${satty} --filename -"))
      hl.bind("SHIFT + Print",      hl.dsp.exec_cmd("${hyprshot} --mode region --raw | ${satty} --filename -"))
      hl.bind("CTRL + ALT + Print", hl.dsp.exec_cmd("${hyprshot} --mode active --mode output --raw | ${satty} --filename -"))

      -- Media keys; `locked` keeps them working on the lock screen
      hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("${playerctl} play-pause"), { locked = true })
      hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("${playerctl} previous"),   { locked = true })
      hl.bind("XF86AudioNext", hl.dsp.exec_cmd("${playerctl} next"),       { locked = true })

      -- Volume and brightness (avizo)
      hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("volumectl toggle-mute"),    { locked = true })
      hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("volumectl -m toggle-mute"), { locked = true })
      hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("volumectl -u up"),          { locked = true, repeating = true })
      hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("volumectl -u down"),        { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("lightctl up"),              { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("lightctl down"),            { locked = true, repeating = true })

      ----------------------------
      ---- WINDOW/LAYER RULES ----
      ----------------------------
      -- https://wiki.hypr.land/Configuring/Basics/Window-Rules/
      -- Pop-up file dialogs float, centred
      hl.window_rule({ match = { title = "(Open|Progress|Save File)" },  float = true, center = true })
      hl.window_rule({ match = { class = "(xdg-desktop-portal-gtk)" },   float = true, center = true })
      hl.window_rule({ match = { class = "(polkit-gnome-authentication-agent-1|nm-connection-editor|org.gnome.Calculator|.blueman-manager-wrapped)" }, float = true, center = true })

      -- https://wiki.hypr.land/Configuring/Basics/Layer-Rules/
      hl.layer_rule({ match = { namespace = "launcher" },                   blur = true, ignore_alpha = 0 })   -- fuzzel
      hl.layer_rule({ match = { namespace = "logout_dialog" },              blur = true })                     -- wlogout
      hl.layer_rule({ match = { namespace = "swaync-control-center" },      blur = true, ignore_alpha = 0.7 })
      hl.layer_rule({ match = { namespace = "swaync-notification-window" }, blur = true, ignore_alpha = 0.7 })
    '';
  };
  # https://github.com/hyprwm/hyprland-wiki/issues/409
  # https://github.com/nix-community/home-manager/pull/4707
  xdg.portal = {
    config = {
      common = {
        default = [
          "hyprland"
          "gtk"
        ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
    };
    configPackages = [ config.wayland.windowManager.hyprland.package ];
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
    xdgOpenUsePortal = true;
  };
}
