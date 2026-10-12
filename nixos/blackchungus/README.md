# blackchungus

## Secure Boot

Boot chain: **firmware → shim → GRUB → kernel / Windows**. Everything is
verified against our own sbctl keys, enrolled alongside Microsoft's (so
Windows and GPU option ROMs keep working). Configured in `secureboot.nix`.

- Keys live in `/var/lib/sbctl` (not in git). Back them up somewhere safe.
- `/boot/EFI/NixOS-boot/` holds `shimx64.efi`, `mmx64.efi` (both copied from
  nixpkgs) and `grubx64.efi`; all three plus `/boot/kernels/*-bzImage` are
  signed with our db key.
- The only firmware boot entry for NixOS is **NixOS-shim**. GRUB is installed
  with `--no-nvram`, and any `NixOS-boot` entry is deleted, because booting
  GRUB directly fails with `shim_lock protocol not found`.

### When do I need to do anything?

| Situation | Action |
| --- | --- |
| Normal `nixos-rebuild switch`, new kernels, nixpkgs updates | Nothing: signing and the boot entry are handled on every bootloader install |
| BIOS update, CMOS reset, or "restore factory keys" in the BIOS | Keys are likely wiped: [re-enroll](#enrolling-keys) |
| Reinstall, or `/var/lib/sbctl` lost | [Create keys and enroll](#enrolling-keys) |
| BIOS boot order changed (MSI re-sorts it) | Set **Boot Option #1 = NixOS-shim** in the BIOS |
| Adding a GRUB module (`insmod` in grub.cfg) | Add it to `grubModules` in `secureboot.nix`: GRUB can't load modules from disk under Secure Boot |
| Booting another EFI binary (e.g. memtest) | `sudo sbctl sign -s <file>` |
| shim reports an SBAT violation after a shim or Windows update | Raise the `grub,N` generation in `grubSbat` (see shim's `SbatLevel_Variable.txt`) and rebuild |

A rebuild prints `secureboot: WARNING unsigned boot files remain` if a file
couldn't be signed; check with `sudo sbctl verify | grep -E 'NixOS-boot|kernels'`.

### Enrolling keys

1. BIOS → Secure Boot: set **Secure Boot Mode = Custom**, then **Delete All
   Secure Boot Variables** (enters setup mode). Leave Secure Boot **disabled**.
   Answer **No** if asked to restore factory keys. Save and boot NixOS.
2. Confirm setup mode, then create (only if `/var/lib/sbctl` is empty) and
   enroll the keys, keeping Microsoft's:
   ```sh
   sudo sbctl status            # Setup Mode: ✗ Enabled
   sudo sbctl create-keys       # only on a fresh install
   sudo sbctl enroll-keys -m
   ```
3. Check the firmware actually took our keys (factory ones say `MSI SHIP PK`):
   ```sh
   strings -n 6 /sys/firmware/efi/efivars/PK-* | grep -i key   # Platform Key
   ```
4. Sign everything and recreate the boot entry:
   ```sh
   sudo nixos-rebuild switch --install-bootloader
   ```
5. BIOS: set **Boot Option #1 = NixOS-shim**, enable Secure Boot (mode stays
   Custom). Then verify:
   ```sh
   sudo sbctl status            # Secure Boot: ✓ Enabled
   ```

### Troubleshooting

| Symptom | Cause |
| --- | --- |
| Error flashes, firmware falls back to Windows | shim/GRUB not signed by an enrolled key; check `PK` isn't `MSI SHIP PK` and `sbctl verify` |
| `shim_lock protocol not found` | Firmware booted GRUB directly; fix boot order / delete `NixOS-boot` entry |
| `verification requested but nobody cares` | GRUB built with `--disable-shim-lock`; it must boot through shim |
| shim "Verification failed" / MokManager screen | GRUB or kernel unsigned; boot with Secure Boot off and rebuild |
| GRUB menu falls back to plain text | Expected: GRUB refuses font files from disk under Secure Boot |

Note: `sbctl status` reports firmware quirk FQ0001 (this board may run
unsigned code on a policy violation), so treat Secure Boot here as best effort.
