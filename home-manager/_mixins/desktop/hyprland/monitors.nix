# Per-host monitor layout and workspace placement.
# Each host gets `monitors` (passed to hl.monitor) and `workspaces`
# (passed to hl.workspace_rule). Hosts not listed here fall back to
# Hyprland's auto-detected layout.
{ lib }:
let
  names = [ "Web" "Work" "Chat" "Code" "Term" "Note" "Cast" "Fun" ];

  # Workspaces 1-8 with the default names; `placement` maps workspace
  # number -> output, or is a single output string for all of them.
  defaultWorkspaces =
    placement:
    lib.imap1 (i: name: {
      workspace = toString i;
      default_name = name;
      persistent = true;
      monitor = if builtins.isString placement then placement else placement.${toString i};
    }) names;

  mon = output: mode: position: scale: { inherit output mode position scale; };

  laptop = mode: {
    monitors = [ (mon "eDP-1" mode "auto" 1) ];
    workspaces = defaultWorkspaces "eDP-1";
  };
in
{
  default = {
    monitors = [ (mon "" "preferred" "auto" "auto") ];
    workspaces = [ ];
  };

  blackchungus = {
    monitors = [
      (mon "DP-3" "1920x1080@144Hz" "0x0" 1) # ASUS MG248
      (mon "HDMI-A-1" "1920x1080@60Hz" "1920x0" 1) # Acer S271HL
    ];
    workspaces = defaultWorkspaces "DP-3";
  };

  phasma = {
    monitors = [
      (mon "DP-1" "3440x1440@100Hz" "0x1280" 1)
      (mon "DP-2" "1920x1080@60Hz" "760x2720" 1)
      (mon "HDMI-A-1" "2560x1600@120Hz" "1920x0" 1.25)
    ];
    workspaces = defaultWorkspaces "DP-1" ++ [
      { workspace = "9"; default_name = "Camera"; persistent = true; monitor = "HDMI-A-1"; layout_opts.orientation = "left"; }
      { workspace = "10"; default_name = "Stream"; persistent = true; monitor = "DP-2"; }
    ];
  };

  shaa = laptop "1920x1080@60Hz";
  atrius = laptop "1920x1080@60Hz";
  tanis = laptop "1920x1200@60Hz";

  vader = {
    monitors = [
      (mon "DP-1" "2560x2880@60Hz" "0x0" 1)
      (mon "DP-2" "2560x2880@60Hz" "2560x0" 1)
      (mon "DP-3" "1920x1080@60Hz" "320x2880" 1)
    ];
    workspaces =
      defaultWorkspaces {
        "1" = "DP-1"; "2" = "DP-1"; "3" = "DP-2"; "4" = "DP-2";
        "5" = "DP-2"; "6" = "DP-2"; "7" = "DP-1"; "8" = "DP-1";
      }
      ++ [
        { workspace = "9"; default_name = "Camera"; persistent = true; monitor = "DP-2"; }
        { workspace = "10"; default_name = "Stream"; persistent = true; monitor = "DP-3"; }
      ];
  };
}
