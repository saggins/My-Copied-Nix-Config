{ lib, pkgs, ... }:
let
  sbctl = "${pkgs.sbctl}/bin/sbctl";
  efibootmgr = "${pkgs.efibootmgr}/bin/efibootmgr";
  shim = "${pkgs.shim-unsigned}/share/shim";
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
    "efifwsetup"
    "all_video"
    "efi_gop"
    "font"
    "gfxterm"
    "gfxterm_background"
    "png"
    "jpeg"
  ];
  # shim refuses to start a loader without an SBAT section; generation 5 is
  # what shim's current revocation level (Feb 2025 GRUB CVEs) requires
  grubSbat = pkgs.writeText "grub-sbat.csv" ''
    sbat,1,SBAT Version,sbat,1,https://github.com/rhboot/shim/blob/main/SBAT.md
    grub,5,Free Software Foundation,grub,${pkgs.grub2_efi.version},https://www.gnu.org/software/grub/
  '';
in
{
  environment.systemPackages = [ pkgs.sbctl ];

  boot.loader.grub = {
    # Firmware -> shim -> GRUB. Without shim, GRUB 2.12's lockdown has no
    # verifier to vouch for kernels and fails with "verification requested but
    # nobody cares". shim checks GRUB, the kernels and Windows against our db.
    extraGrubInstallArgs = [
      "--sbat=${grubSbat}"
      # Don't create a firmware entry pointing straight at GRUB, which would
      # skip shim; the NixOS-shim entry below is the only way in
      "--no-nvram"
      "--modules=${lib.concatStringsSep " " grubModules}"
    ];

    # Runs after every bootloader install, whichever tool triggered the rebuild.
    # Signs shim, GRUB and any newly copied kernels, then reports anything
    # unsigned, and keeps the firmware booting shim rather than GRUB directly.
    extraInstallCommands = ''
      esp=/boot/EFI/NixOS-boot
      # shim loads grubx64.efi from its own directory
      install -m644 ${shim}/shimx64.efi "$esp/shimx64.efi"
      install -m644 ${shim}/mmx64.efi "$esp/mmx64.efi"

      if [ ! -e /var/lib/sbctl/keys/db/db.key ]; then
        echo "secureboot: no sbctl keys found, boot files left unsigned (see: sbctl create-keys)" >&2
      else
        for f in "$esp"/shimx64.efi "$esp"/mmx64.efi "$esp"/grubx64.efi /boot/kernels/*-bzImage; do
          [ -e "$f" ] || continue
          ${sbctl} sign --quiet "$f" || echo "secureboot: FAILED to sign $f" >&2
        done
        if ${sbctl} verify 2>&1 | grep -E 'NixOS-boot|/kernels/' | grep -q 'not signed'; then
          echo "secureboot: WARNING unsigned boot files remain, check 'sudo sbctl verify'" >&2
        fi
      fi

      findEntry() {
        ${efibootmgr} | sed -n "s/^Boot\([0-9A-Fa-f]\{4\}\)\*\{0,1\} $1\([[:space:]].*\)\{0,1\}$/\1/p"
      }

      # "NixOS-boot" entries go straight to GRUB, which then fails with
      # "shim_lock protocol not found"; drop them so firmware can only pick shim
      for old in $(findEntry NixOS-boot); do
        ${efibootmgr} -q -b "$old" -B
      done

      # Keep the shim entry first in BootOrder. MSI firmware may still re-sort
      # from its own "Boot Option #1" setting, so set that to NixOS-shim too
      entry=$(findEntry NixOS-shim | head -n1)
      if [ -z "$entry" ]; then
        part=$(${pkgs.util-linux}/bin/findmnt -no SOURCE /boot)
        disk=/dev/$(${pkgs.util-linux}/bin/lsblk -no PKNAME "$part")
        partn=$(cat "/sys/class/block/''${part##*/}/partition")
        ${efibootmgr} -q -c -d "$disk" -p "$partn" -L NixOS-shim -l '\EFI\NixOS-boot\shimx64.efi'
        entry=$(findEntry NixOS-shim | head -n1)
      fi
      order=$(${efibootmgr} | sed -n 's/^BootOrder: //p')
      case "$order" in
        "$entry" | "$entry",*) ;;
        *)
          rest=$(echo "$order" | tr , '\n' | grep -vix "$entry" | paste -sd, -)
          ${efibootmgr} -q -o "$entry''${rest:+,$rest}"
          ;;
      esac
    '';
  };
}
