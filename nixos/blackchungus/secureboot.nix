{ lib, pkgs, ... }:
let
  sbctl = "${pkgs.sbctl}/bin/sbctl";
  # Under enforced Secure Boot GRUB enters lockdown and refuses to insmod from
  # disk, so every module grub.cfg needs must be embedded in the signed image.
  grubModules = [
    "part_gpt"
    "fat"
    "search"
    "search_fs_uuid"
    "search_fs_file"
    "search_label"
    "normal"
    "configfile"
    "loadenv"
    "test"
    "echo"
    "linux"
    "chain"
    "all_video"
    "efi_gop"
    "font"
    "gfxterm"
    "gfxterm_background"
    "png"
    "jpeg"
  ];
in
{
  environment.systemPackages = [ pkgs.sbctl ];

  boot.loader.grub = {
    # No shim: the firmware verifies GRUB directly against our enrolled db key
    extraGrubInstallArgs = [
      "--disable-shim-lock"
      "--modules=${lib.concatStringsSep " " grubModules}"
    ];

    # Runs after every bootloader install, whichever tool triggered the rebuild.
    # Signs GRUB and any newly copied kernels, then reports anything unsigned.
    extraInstallCommands = ''
      if [ ! -e /var/lib/sbctl/keys/db/db.key ]; then
        echo "secureboot: no sbctl keys found, boot files left unsigned (see: sbctl create-keys)" >&2
      else
        for f in /boot/EFI/NixOS-boot/grubx64.efi /boot/kernels/*-bzImage; do
          [ -e "$f" ] || continue
          ${sbctl} sign --quiet "$f" || echo "secureboot: FAILED to sign $f" >&2
        done
        if ${sbctl} verify 2>&1 | grep -E 'NixOS-boot|/kernels/' | grep -q 'not signed'; then
          echo "secureboot: WARNING unsigned boot files remain, check 'sudo sbctl verify'" >&2
        fi
      fi
    '';
  };
}
