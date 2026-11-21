# miyo: headless Miyo engine, indexes notes for semantic search and serves them over MCP.
# Package (pkgs/miyo) and module (modules/nixos/miyo) are vendored here; there's no nixpkgs
# package or upstream flake.
#
# - Runs as a systemd user service for ${username}: `systemctl --user status miyo`,
#   `journalctl --user -u miyo -f`. Data in ~/.config/Miyo.
# - After the first switch: `miyo folders add ~/notes`, then optionally `miyo login` for
#   remote access (stores relay.json in plain text in the data dir).
# - Listens on 127.0.0.1:8742 only. Reach it from other machines over SSH:
#   `claude mcp add miyo-server -- ssh ${hostname} miyo mcp`.
{
  hostname,
  lib,
  outputs,
  username,
  ...
}:
let
  installOn = [ "workhorse" ];
in
{
  imports = [ outputs.nixosModules.miyo ];

  config = lib.mkIf (lib.elem "${hostname}" installOn) {
    services.miyo = {
      enable = true;
      user = username;
    };
  };
}
