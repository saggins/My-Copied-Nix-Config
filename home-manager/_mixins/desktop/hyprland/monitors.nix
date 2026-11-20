# Per-host monitor layout and workspace placement.
# Each host gets `monitors` (passed to hl.monitor) and `workspaces`
# (passed to hl.workspace_rule). Hosts not listed here fall back to
# Hyprland's auto-detected layout.
{ lib }:
let
  names = [
    "Web"
    "Work"
    "Chat"
    "Code"
    "Term"
    "Note"
    "Cast"
    "Fun"
  ];

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

  mon = output: mode: position: scale: {
    inherit
      output
      mode
      position
      scale
      ;
  };
in
{
  default = {
    monitors = [ (mon "" "preferred" "auto" "auto") ];
    workspaces = [ ];
  };

  # Matched by EDID description so the layout survives port changes.
  blackchungus =
    let
      asus = "desc:Ancor Communications Inc MG248 G7LMQS092948";
      acer = "desc:Acer Technologies S271HL LUWAA005853B";
    in
    {
      monitors = [
        (mon asus "1920x1080@144Hz" "0x0" 1)
        (mon acer "1920x1080@60Hz" "1920x0" 1)
      ];
      workspaces = defaultWorkspaces asus;
    };
}
