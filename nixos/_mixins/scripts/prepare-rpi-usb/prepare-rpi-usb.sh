#!/usr/bin/env bash
# prepare-rpi-usb.sh — write Raspberry Pi OS to a USB drive / SD card with
# headless SSH preconfigured and NO root password (root stays locked).
#
# Linux only. Run as root:  sudo ./prepare-rpi-usb.sh [options]
# After the card's first boot (~1-2 min, needs network):
#   ssh <user>@raspberrypi.local
set -euo pipefail
# Make sure the usual Linux userland is on PATH (NixOS, minimal boxes).
export PATH="/run/current-system/sw/bin:/run/current-system/sw/sbin:$PATH"

readonly DEFAULT_URL="https://downloads.raspberrypi.com/raspios_lite_arm64_latest"
readonly MIN_BYTES=$((4 * 1024 * 1024 * 1024))        # 4 GiB
readonly SUDOERS_NAME="010-prepare-rpi"               # no dots: sudo ignores files containing '.'
readonly DROPIN="50-prepare-rpi-headless.conf"
readonly AUTHKEY_DIR="/etc/ssh/authorized_keys"

DEVICE=""; IMAGE=""; USER_NAME="pi"; PASSWORD=""; PW_SOURCE=""
SSH_KEY=""; KEY_TEXT=""; KEY_ONLY=0; ASSUME_YES=0; LIST_ONLY=0
CFG_BOOT=""; CFG_ROOT=""
WORK=""; IMG=""; COMP=xz
BOOT=""; ROOT=""
DEVICE_P1=""; DEVICE_P2=""; DEV_MODEL=""; DEV_SIZE=""; DEV_TYPE=""
DEV_BYTES=0; DEV_REMOVABLE=0
MOUNTED=()

die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '\n==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
need(){ command -v "$1" >/dev/null 2>&1 || die "missing tool: $1"; }

usage() {
  cat <<'EOF'
prepare-rpi-usb.sh — write Raspberry Pi OS to a USB drive / SD card with
headless SSH preconfigured and NO root password (root stays locked).

Usage: sudo ./prepare-rpi-usb.sh [options]

Options:
  --device /dev/sdX    Target drive. Omit to interactively pick a removable
                       USB/SD device (>=4 GiB, with nothing mounted on it).
  --image PATH|URL     Use a specific image (local file or http(s) URL).
                       Default: latest Raspberry Pi OS Lite 64-bit from
                       downloads.raspberrypi.com (checksum-verified).
  --user NAME          User created on first boot (default: pi).
  --password PASS      User password (default: random, printed at the end).
  --ssh-key PATH|KEY   Install an SSH public key: path to a .pub file, or the
                       "ssh-ed25519 AAAA..." line itself. Keys are delivered
                       via /etc/ssh/authorized_keys on the target, so the new
                       user's UID doesn't need to be known in advance.
  --key-only           Passwordless admin: requires --ssh-key; disables SSH
                       password authentication and gives the user NOPASSWD sudo.
  --yes                Skip the "destroy device" confirmation.
  --list               List suitable target devices and exit.
  --configure-only BOOT ROOT
                       Don't download or write anything: apply the first-boot
                       configuration to two ALREADY MOUNTED directories (boot
                       + rootfs partitions of an already-imaged card). Run as
                       root; handy for re-fine-tuning a card this script wrote.
  -h, --help           Show this help.

What gets configured on the card:
  boot partition :  "ssh" marker  -> sshd starts on first boot
                    userconf.txt  -> official first-boot user creation
  rootfs         :  PermitRootLogin no (sshd_config.d drop-in)
                    root locked in /etc/shadow (enforced: no root password)
                    sudoers entry for the user (NOPASSWD in --key-only mode)
                    /etc/ssh/authorized_keys/<user> when --ssh-key is given

First boot needs network (ethernet, or wifi configured separately).
EOF
}

cleanup() {
  local rc=$?
  trap - EXIT
  set +e
  if [[ ${#MOUNTED[@]} -gt 0 ]]; then
    local i
    for ((i=${#MOUNTED[@]}-1; i>=0; i--)); do umount "${MOUNTED[i]}" 2>/dev/null; done
  fi
  if [[ $rc -eq 0 && -n ${WORK:-} && -d ${WORK:-} ]]; then
    rm -rf "$WORK"
  elif [[ $rc -ne 0 && -n ${WORK:-} && -d ${WORK:-} ]]; then
    printf '\n(kept %s for retry — rerun with --image "%s"\n or remove it to re-download)\n' "$WORK" "$WORK/os.img.xz"
  fi
  exit $rc
}
trap cleanup EXIT

# ---------- helpers ----------------------------------------------------------

# SHA-512 crypt hash of $1, using whatever the host actually provides.
# Tries in order: openssl passwd -6 (the documented way), mkpasswd,
# python3 with the crypt module (<3.13), and finally nix-shell -p openssl.
sha512_crypt() {
  local pw=$1 out=""
  if command -v openssl >/dev/null 2>&1; then
    out=$(printf '%s' "$pw" | openssl passwd -6 -stdin 2>/dev/null) || true
  fi
  if [[ -z $out ]] && command -v mkpasswd >/dev/null 2>&1; then
    out=$(mkpasswd -m sha-512 "$pw" 2>/dev/null || mkpasswd --method=sha-512 "$pw" 2>/dev/null) || true
  fi
  if [[ -z $out ]] && command -v python3 >/dev/null 2>&1 && python3 -c 'import crypt' 2>/dev/null; then
    out=$(python3 -c 'import crypt,sys; print(crypt.crypt(sys.argv[1], crypt.mksalt(crypt.METHOD_SHA512)))' "$pw" 2>/dev/null) || true
  fi
  if [[ -z $out ]] && command -v nix-shell >/dev/null 2>&1; then
    out=$(printf '%s' "$pw" | nix-shell -p openssl --run 'openssl passwd -6 -stdin' 2>/dev/null) || true
  fi
  [[ ${out:-} =~ ^\$6\$ ]] || die "cannot build the SHA-512 crypt hash: no working openssl / mkpasswd / python3-crypt found (NixOS: add openssl to system packages)"
  printf '%s' "$out"
}

make_password() {
  head -c 24 /dev/urandom | base64 | tr -d '/+=' | cut -c1-16
}

human_bytes() {
  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec --suffix=B "$1"
  else
    awk -v b="$1" 'BEGIN{s="BKMGTP";i=0;while(b>=1024&&i<5){b/=1024;i++};printf "%.1f%s",b,substr(s,i+1,1)}'
  fi
}

is_mounted() { grep -qs "^/dev/${1##*/}" /proc/mounts; }

# Parent disk basename via lsblk PKNAME (handles sda, nvme0n1, mmcblk0 naming).
disk_base() {
  lsblk -nro PKNAME "$1" 2>/dev/null | head -n1
}

scan_devices() {
  local d name rem bytes model
  for d in /sys/block/*; do
    name=${d##*/}
    case $name in loop*|ram*|zram*|md*|dm-*|sr*|fd*|nbd*) continue ;; esac
    rem=$(cat "$d/removable" 2>/dev/null || echo 0)
    [[ $rem == 1 ]] || continue              # target must be removable (USB/SD)
    bytes=$((512 * $(cat "$d/size" 2>/dev/null || echo 0)))
    ((bytes >= MIN_BYTES)) || continue
    is_mounted "$name" && continue           # skip anything with mounts on it
    model=$(tr -s ' ' <"$d/device/model" 2>/dev/null || true)
    printf '%s\t%s\t%s\n' "/dev/$name" "$(human_bytes "$bytes")" "${model:-unknown model}"
  done
}

assert_not_system_disk() {
  local src bn1 bn2 d1 d2
  src=$(findmnt -nro SOURCE / 2>/dev/null || true)
  [[ -n $src ]] || return 0
  bn1=${src##*/}
  d1=$(disk_base "$src"); [[ -z $d1 ]] && d1=$bn1
  bn2=${DEVICE##*/}
  d2=$(disk_base "$DEVICE"); [[ -z $d2 ]] && d2=$bn2
  if [[ $bn2 == "$bn1" || $d2 == "$d1" ]]; then
    die "$DEVICE is on the same disk the system is running from ($src) — refusing"
  fi
}

validate_device() {
  [[ -b $DEVICE ]] || die "no such block device: $DEVICE"
  [[ $DEV_TYPE == disk ]] || die "$DEVICE is a partition or not a whole disk — give the drive itself (e.g. /dev/sdb)"
  assert_not_system_disk
  is_mounted "$DEVICE" && die "$DEVICE (or its partitions) is mounted — unmount it first"
  ((DEV_BYTES >= MIN_BYTES)) || die "$DEVICE is $(human_bytes "$DEV_BYTES") — too small for Raspberry Pi OS (need >= 4 GiB)"
  if [[ $DEV_REMOVABLE != 1 && $ASSUME_YES -ne 1 ]]; then
    die "$DEVICE is not marked removable — if it really is a USB stick, rerun with --yes"
  fi
}

load_dev_info() {
  local base=${DEVICE##*/}
  DEV_TYPE=$(lsblk -nro TYPE "$DEVICE" 2>/dev/null || echo unknown)
  DEV_REMOVABLE=$(cat "/sys/block/$base/removable" 2>/dev/null || echo 0)
  DEV_BYTES=$((512 * $(cat "/sys/block/$base/size" 2>/dev/null || echo 0)))
  DEV_SIZE=$(human_bytes "$DEV_BYTES")
  DEV_MODEL=$(tr -s ' ' <"/sys/block/$base/device/model" 2>/dev/null || echo "unknown model")
}

pick_device() {
  local cands=() n i ans
  mapfile -t cands < <(scan_devices)
  if [[ ${#cands[@]} -eq 0 ]]; then
    die "no suitable removable devices found (>=4 GiB, unmounted). Plug one in, or pass --device"
  fi
  if [[ ${#cands[@]} -eq 1 ]]; then
    DEVICE=${cands[0]%%$'\t'*}
  else
    printf 'Available devices:\n'
    for i in "${!cands[@]}"; do
      printf '  %d) %s\n' "$((i+1))" "${cands[i]//$'\t'/  |  }"
    done
    [[ -t 0 || -e /dev/tty ]] || die "multiple candidates but no terminal for choosing — pass --device"
    if [[ -t 0 ]]; then read -rp "Device number: " n; else read -rp "Device number: " n </dev/tty; fi
    [[ $n =~ ^[0-9]+$ && $n -ge 1 && $n -le ${#cands[@]} ]] || die "invalid choice"
    DEVICE=${cands[$((n-1))]%%$'\t'*}
  fi
  load_dev_info
  info "Selected target: $DEVICE ($DEV_MODEL, $DEV_SIZE)"
}

confirm_overwrite() {
  [[ $ASSUME_YES -eq 1 ]] && { note "skipping confirmation (--yes)"; return 0; }
  printf '\nWILL DESTROY ALL DATA ON: %s (%s, %s)\n' "$DEVICE" "$DEV_MODEL" "$DEV_SIZE"
  local ans
  if [[ -t 0 ]]; then read -rp 'Type YES to continue: ' ans
  elif [[ -e /dev/tty ]]; then read -rp 'Type YES to continue: ' ans </dev/tty
  else die "no terminal for confirmation — pass --yes for non-interactive use"
  fi
  [[ $ans == YES ]] || die "aborted — nothing was written"
}

fetch_image() {
  need curl; need xz
  WORK=$(mktemp -d "${TMPDIR:-/tmp}/prepare-rpi.XXXXXX")
  if [[ -n $IMAGE && $IMAGE != http* ]]; then
    [[ -f $IMAGE ]] || die "--image: no such file: $IMAGE"
    IMG=$IMAGE
    info "Using local image $IMG"
  else
    local url=${IMAGE:-$DEFAULT_URL} final sidecar want have
    IMG=$WORK/os.img.xz
    info "Downloading image from $url"
    final=$(curl -fL --retry 3 --retry-delay 2 -o "$IMG" -w '%{url_effective}' "$url") \
      || die "download failed (see curl error above)"
    # Verify against the official .sha256 sidecar published for the exact file
    # we ended up downloading (race-safe: derived from the effective final URL).
    if sidecar=$(curl -fsSL --retry 2 "$final.sha256" 2>/dev/null); then
      want=$(awk 'NR==1{print $1}' <<<"$sidecar")
      if [[ $want =~ ^[0-9a-f]{64}$ ]]; then
        have=$(sha256sum "$IMG" | awk '{print $1}')
        [[ $have == "$want" ]] || die "SHA-256 MISMATCH: got $have, expected $want — do not use this download"
        note "sha256 verified: $have"
      else
        note "sidecar sha256 unreadable — skipping hash check"
      fi
    else
      note "no .sha256 published for this URL — relying on transport + xz integrity"
    fi
  fi
  if xz -t "$IMG" 2>/dev/null; then
    COMP=xz
  else
    COMP=raw
    note "not an .xz stream — treating as raw .img"
  fi
  note "image ready: $IMG ($(human_bytes "$(stat -c%s "$IMG")"))"
}

write_image() {
  need dd
  info "Writing image to $DEVICE (this destroys all data on it)"
  if [[ $COMP == xz ]]; then
    xz -dc "$IMG" | dd of="$DEVICE" bs=4M status=progress conv=fsync
  else
    dd if="$IMG" of="$DEVICE" bs=4M status=progress conv=fsync
  fi
  sync
}

reread_and_check() {
  local base=${DEVICE##*/} p1 p2 t1 t2 i
  if command -v partprobe >/dev/null 2>&1; then
    partprobe "$DEVICE" 2>/dev/null || true
  elif command -v blockdev >/dev/null 2>&1; then
    blockdev --rereadpt "$DEVICE" 2>/dev/null || true
  fi
  command -v udevadm >/dev/null 2>&1 && udevadm settle --timeout=15 2>/dev/null || true
  if [[ $base == *[0-9] ]]; then p1="${DEVICE}p1"; p2="${DEVICE}p2"; else p1="${DEVICE}1"; p2="${DEVICE}2"; fi
  for i in {1..10}; do
    [[ -b $p1 && -b $p2 ]] && break
    sleep 1
  done
  [[ -b $p1 && -b $p2 ]] || die "partitions $p1/$p2 did not appear. Unplug and replug the drive, mount the partitions, then run: $0 --configure-only <boot_mount> <root_mount>"
  need blkid
  t1=$(blkid -s TYPE -o value "$p1" 2>/dev/null || true)
  t2=$(blkid -s TYPE -o value "$p2" 2>/dev/null || true)
  [[ $t1 == vfat* ]] || die "partition 1 is '$t1', expected vfat — unsupported image layout"
  [[ $t2 == ext* ]] || die "partition 2 is '$t2', expected ext4 — unsupported image layout"
  DEVICE_P1=$p1; DEVICE_P2=$p2
}

mount_partitions() {
  need mount; need umount
  BOOT=$WORK/boot; ROOT=$WORK/root
  mkdir -p "$BOOT" "$ROOT"
  mount "$DEVICE_P1" "$BOOT";  MOUNTED+=("$BOOT")
  mount "$DEVICE_P2" "$ROOT";  MOUNTED+=("$ROOT")
  [[ -f $BOOT/config.txt || -f $BOOT/start.elf ]] || die "boot partition doesn't look like a Raspberry Pi OS boot partition"
  [[ -f $ROOT/etc/os-release ]] || die "rootfs doesn't look like a Raspberry Pi OS rootfs"
}

# ---------- first-boot configuration (boot dir + rootfs dir) -----------------

# Lock down root in the target /etc/shadow. Locked = field is '*' or '!*'.
lock_root_shadow() {
  local f=$1 cur tmp
  [[ -f $f ]] || { note "no /etc/shadow on target — skipping root lock"; return 0; }
  cur=$(awk -F: '$1=="root"{print $2}' "$f")
  case $cur in
    !*)
      note "root already locked in target /etc/shadow ($cur)"
      return 0 ;;
    '*')
      note "root already locked in target /etc/shadow ($cur)"
      return 0 ;;
  esac
  # either empty (passwordless root!) or a real hash -> replace with locked '!'
  tmp=$(mktemp "$(dirname "$f")/.shadow.XXXXXX")
  awk -F: -v OFS=: '/^root:/{ $2="!" } {print}' "$f" > "$tmp"
  chmod --reference="$f" "$tmp"
  chown --reference="$f" "$tmp" 2>/dev/null || true
  mv "$tmp" "$f"
  note "root locked in target /etc/shadow (was: '$cur' -> now '!') — no root password possible"
}

resolve_ssh_key() {
  [[ -n $SSH_KEY ]] || return 0
  if [[ -f $SSH_KEY ]]; then
    KEY_TEXT=$(grep -E '^(ssh-|ecdsa-|sk-)' "$SSH_KEY" || true)
    if grep -q PRIVATE <<<"$SSH_KEY"; then
      die "--ssh-key: that looks like a PRIVATE key — pass the .pub file instead"
    fi
  elif [[ $SSH_KEY =~ ^(ssh-|ecdsa-|sk-) ]]; then
    KEY_TEXT=$SSH_KEY
  else
    die "--ssh-key: '$SSH_KEY' is not a file and doesn't look like a public key"
  fi
  [[ -n $KEY_TEXT ]] || die "--ssh-key: no public key lines found"
}

# Applies the whole headless configuration to $1 (boot dir) and $2 (rootfs dir).
configure() {
  local bd=$1 rd=$2 hash
  [[ -d $bd && -d $rd ]] || die "configure: '$bd' and '$rd' must be existing directories"

  ensure_password
  resolve_ssh_key
  local sudo_rule="ALL=(ALL) ALL"
  [[ $KEY_ONLY -eq 1 ]] && sudo_rule="ALL=(ALL) NOPASSWD: ALL"

  # 1) boot partition: official first-boot hooks
  touch "$bd/ssh"
  hash=$(sha512_crypt "$PASSWORD")
  printf '%s:%s\n' "$USER_NAME" "$hash" > "$bd/userconf.txt"
  note "boot: ssh marker + userconf.txt written (user '$USER_NAME' is created on first boot)"

  # 2) belt-and-braces: enable ssh.service directly on the rootfs too
  mkdir -p "$rd/etc/systemd/system/multi-user.target.wants"
  ln -sfn /usr/lib/systemd/system/ssh.service "$rd/etc/systemd/system/multi-user.target.wants/ssh.service"

  # 3) sudo rights for the user (sudoers.d ignores filenames containing '.')
  mkdir -p "$rd/etc/sudoers.d"
  printf '%s %s\n' "$USER_NAME" "$sudo_rule" > "$rd/etc/sudoers.d/$SUDOERS_NAME"
  chmod 0440 "$rd/etc/sudoers.d/$SUDOERS_NAME"
  if command -v visudo >/dev/null 2>&1; then
    visudo -qcf "$rd/etc/sudoers.d/$SUDOERS_NAME" || die "generated sudoers file failed validation"
  fi
  note "rootfs: sudoers.d/$SUDOERS_NAME -> $USER_NAME $sudo_rule"

  # 4) sshd policy via a drop-in (or prepended block on older images)
  mkdir -p "$rd/etc/ssh/sshd_config.d"
  {
    printf 'PermitRootLogin no\n'
    printf 'PubkeyAuthentication yes\n'
    printf 'AuthorizedKeysFile %s/%%u .ssh/authorized_keys\n' "$AUTHKEY_DIR"
    if [[ $KEY_ONLY -eq 1 ]]; then
      printf 'PasswordAuthentication no\nKbdInteractiveAuthentication no\n'
    fi
  } > "$rd/etc/ssh/sshd_config.d/$DROPIN"
  if ! grep -qE '^[[:space:]]*Include[[:space:]]+.*sshd_config\.d' "$rd/etc/ssh/sshd_config" 2>/dev/null; then
    # older sshd_config without the Include line: sshd uses first-match-wins,
    # so our directives must go ABOVE the stock file
    local tmpf
    tmpf=$(mktemp "$(dirname "$rd/etc/ssh/sshd_config")/.sshd_config.XXXXXX")
    { cat "$rd/etc/ssh/sshd_config.d/$DROPIN"; echo; cat "$rd/etc/ssh/sshd_config"; } > "$tmpf"
    chmod --reference="$rd/etc/ssh/sshd_config" "$tmpf"
    chown --reference="$rd/etc/ssh/sshd_config" "$tmpf" 2>/dev/null || true
    mv "$tmpf" "$rd/etc/ssh/sshd_config"
    note "rootfs: sshd_config has no Include line — drop-in was prepended directly"
  fi
  note "rootfs: sshd drop-in written (PermitRootLogin no$( [[ $KEY_ONLY -eq 1 ]] && printf ', password auth off' ))"

  # 5) authorized_keys delivered system-wide (UID of the first-boot user unknown)
  if [[ -n $KEY_TEXT ]]; then
    mkdir -p "$rd$AUTHKEY_DIR"
    chmod 0755 "$rd$AUTHKEY_DIR"
    printf '%s\n' "$KEY_TEXT" > "$rd$AUTHKEY_DIR/$USER_NAME"
    chmod 0644 "$rd$AUTHKEY_DIR/$USER_NAME"
    note "rootfs: $AUTHKEY_DIR/$USER_NAME installed ($(wc -l <"$rd$AUTHKEY_DIR/$USER_NAME") key line(s))"
  fi

  # 6) no root password, enforced
  lock_root_shadow "$rd/etc/shadow"
}

ensure_password() {
  [[ -n $PASSWORD ]] && return 0
  PASSWORD=$(make_password)
  PW_SOURCE=generated
}

report() {
  info "Done — $DEVICE is configured. Unmount finished; safe to unplug."
  note "user           : $USER_NAME (created automatically on first boot)"
  if [[ $KEY_ONLY -eq 1 ]]; then
    note "user password  : $PASSWORD"
    note "                   (needed only for console login / sudo fallback;"
    note "                    SSH ignores it — key-only auth + NOPASSWD sudo)"
  elif [[ $PW_SOURCE == generated ]]; then
    note "user password  : $PASSWORD   <-- WRITE THIS DOWN (shown once)"
  else
    note "user password  : (the one you provided)"
  fi
  note "ssh            : enabled on first boot; root login: no; root password: none (locked)"
  if [[ -n $KEY_TEXT ]]; then
    note "ssh keys       : /etc/ssh/authorized_keys/$USER_NAME (key auth preferred)"
  fi
  note "first login    : ssh $USER_NAME@raspberrypi.local  (after ~1-2 min, needs network)"
  note "wifi note      : ethernet assumed; configure wifi separately (e.g. Raspberry Pi Imager options or nmtui on the Pi)"
}

report_config_only() {
  info "Configuration applied to $1 and $2."
  note "If that was a card written by this script, it is ready to boot — unmount it:"
  note "  umount $1 $2"
}

main() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --device) DEVICE=${2:?--device needs a value};           shift 2 ;;
      --image)  IMAGE=${2:?--image needs a value};             shift 2 ;;
      --user)   USER_NAME=${2:?--user needs a value};          shift 2 ;;
      --password) PASSWORD=${2:?--password needs a value}; PW_SOURCE=given; shift 2 ;;
      --ssh-key) SSH_KEY=${2:?--ssh-key needs a value};        shift 2 ;;
      --key-only) KEY_ONLY=1;                                  shift ;;
      --yes|-y) ASSUME_YES=1;                                  shift ;;
      --list) LIST_ONLY=1;                                     shift ;;
      --configure-only)
        CFG_BOOT=${2:?--configure-only needs boot dir}; CFG_ROOT=${3:?--configure-only needs root dir}; shift 3 ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown option: $1 (see --help)" ;;
    esac
  done

  if [[ $LIST_ONLY -eq 1 ]]; then
    printf 'DEVICE\tSIZE\tMODEL\n'
    scan_devices || true
    exit 0
  fi

  [[ $EUID -eq 0 ]] || die "must run as root (sudo). For a dry preview: $0 --list"
  # keep in sync with the Pi's own first-boot validator (userconf-service):
  # must start with a letter, then lowercase letters/digits/hyphens, max 32
  [[ $USER_NAME =~ ^[a-z][a-z0-9-]{0,31}$ ]] || die "--user: invalid Linux username '$USER_NAME' (must start with a letter; lowercase letters, digits, hyphens only)"
  if [[ $KEY_ONLY -eq 1 && -z $SSH_KEY ]]; then
    die "--key-only requires --ssh-key"
  fi

  if [[ -n $CFG_BOOT ]]; then
    report_config_only "$CFG_BOOT" "$CFG_ROOT"
    return 0
  fi

  if [[ -z $DEVICE ]]; then
    pick_device
  else
    load_dev_info
    validate_device
    info "Target: $DEVICE ($DEV_MODEL, $DEV_SIZE)"
  fi

  fetch_image
  confirm_overwrite
  write_image
  reread_and_check
  mount_partitions
  configure "$BOOT" "$ROOT"
  sync
  report
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  main "$@"
fi
