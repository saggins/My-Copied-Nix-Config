# CLAUDE.md

## Project layout
Flake-based config for NixOS, nix-darwin and standalone Home Manager. Lives at
`~/Zero/nix-config`; scripts assume that path.

- `flake.nix` — inputs and outputs. Hosts are declared here via `helper.mkNixos`,
  `helper.mkDarwin` and `helper.mkHome` (`homeConfigurations` keyed `user@host`).
- `lib/helpers.nix` — the `mk*` builders. They compute host flags (`isInstall`, `isISO`,
  `isLaptop`, `isLightweight`, `isWorkstation`, `tailNet`, ...) and pass them, plus
  `hostname`, `username`, `desktop`, `platform`, `stateVersion`, as `specialArgs` /
  `extraSpecialArgs`. Add new host flags here.
- `nixos/` — NixOS entrypoint `default.nix`, one dir per host (`blackchungus`,
  `workhorse`, `bastion`, `iso-console`) with `default.nix`, `disks.nix` (disko), etc.
- `darwin/` — nix-darwin entrypoint, host `dorado`.
- `home-manager/` — Home Manager entrypoint (big `default.nix`).
- `*/_mixins/` — shared modules, split into `configs`, `desktop`, `features`,
  `scripts`, `services`, `users`. Only `scripts/` (all three) and `nixos/_mixins/features/`
  auto-import every subdirectory; everywhere else (`services/`, `desktop/`, other
  `features/`) the `default.nix` has an explicit `imports` list, so a new mixin dir must
  also be added there. `users/` imports `./${username}` if it exists. Gate mixins with the
  flags above (`lib.mkIf`, `lib.optional`). `desktop/` is only imported when `isWorkstation`.
  - `_mixins/scripts/<name>/` — shell scripts packaged with `writeShellApplication`
    (`<name>.sh` + `default.nix`); `_template` is the starting point.
- `pkgs/` — custom packages, exported as `packages.<system>`.
- `overlays/` — `additions` (adds `pkgs/`), `modifications` (package overrides),
  `unstable-packages` (`pkgs.unstable.*` from `nixpkgs-unstable`).
- `modules/nixos/` — custom NixOS modules exported as `nixosModules`.
- `secrets/` — sops-nix encrypted files; recipients in `.sops.yaml`. See Secrets below.
- `.github/workflows/` — CI builds for hosts and packages, lock updater.

## Building
Use `nh` whenever possible instead of raw `nixos-rebuild` / `darwin-rebuild` /
`home-manager` / `nix build`:
- NixOS: `nh os build ~/Zero/nix-config` / `nh os switch ~/Zero/nix-config`
  (remote: `--hostname <host> --target-host <user>@<host>`)
- Home Manager: `nh home build ~/Zero/nix-config` / `nh home switch ~/Zero/nix-config`
- nix-darwin: `nh darwin build ~/Zero/nix-config` / `nh darwin switch ~/Zero/nix-config`

Wrapper scripts exist: `nh-host`, `nh-all` (NixOS), `nh-home` (HM). Fall back to
`nix build .#<attr>` only for things `nh` can't do (ISOs, single packages from `pkgs/`,
evaluating one option). Format with `nix fmt` (nixfmt).

Run builds/switches in a detached tmux session so the user can attach to watch and type the
sudo password. `git add` new files first (flakes ignore untracked files). Launch via a bash
script, not an inline command (tmux runs inline commands with fish, which breaks `$?`):
```sh
# switch.sh: cd ~/Zero/nix-config; nh os switch ~/Zero/nix-config; echo "=== nh exit: $? ==="; exec bash
tmux new-session -d -s nix-switch ./switch.sh   # user: tmux attach -t nix-switch
```
Every time you start one, immediately tell the user the exact attach command
(e.g. `tmux attach -t nix-switch`) in your reply, before polling.
Poll with `tmux capture-pane -p -J -S -200 -t nix-switch` until `=== nh exit` or a `Password:`
prompt; on a prompt, tell the user to attach and enter it. `nix-output-monitor error: ...
invalid activity type: 10113` lines are harmless noise from a newer Nix.

## Secrets
- Never write to `secrets/` (sops files) or run `sops` commands that modify them.
  The user manages secrets themselves.
- When a change needs a secret or key added, rotated, or removed, give the user the
  exact commands to run instead (key generation, `sops set ...`, cleanup), and leave
  any config that depends on the resulting public key for them to fill in.
