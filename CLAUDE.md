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
  `scripts`, `services`, `users`. Each `default.nix` auto-imports every subdirectory, so
  a new mixin is just a new dir with a `default.nix`; gate it with the flags above
  (`lib.mkIf`, `lib.optional`). `desktop/` is only imported when `isWorkstation`.
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

## Secrets
- Never write to `secrets/` (sops files) or run `sops` commands that modify them.
  The user manages secrets themselves.
- When a change needs a secret or key added, rotated, or removed, give the user the
  exact commands to run instead (key generation, `sops set ...`, cleanup), and leave
  any config that depends on the resulting public key for them to fill in.
