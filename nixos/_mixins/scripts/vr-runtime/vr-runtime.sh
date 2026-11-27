# Switch the per-user VR runtime between Monado (+ xrizer for OpenVR games) and SteamVR.
# MONADO_JSON and XRIZER_DIR are prepended by default.nix.
STEAM="${XDG_DATA_HOME:-$HOME/.local/share}/Steam"
STEAMVR="$STEAM/steamapps/common/SteamVR"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
OPENXR_JSON="$CONFIG/openxr/1/active_runtime.json"
OPENVR_PATHS="$CONFIG/openvr/openvrpaths.vrpath"
VRSETTINGS="$STEAM/config/steamvr.vrsettings"

usage() {
  echo "Usage: vr-runtime monado|steamvr|status"
  exit 1
}

status() {
  echo "OpenXR: $(readlink "$OPENXR_JSON" 2>/dev/null || echo "system default (Monado)")"
  echo "OpenVR: $(jq -r '.runtime[0] // "unset"' "$OPENVR_PATHS" 2>/dev/null || echo "unset")"
}

# Rewrite a JSON file in place with jq, creating it if needed: json_set FILE [JQ ARGS...] FILTER
json_set() {
  local file="$1"
  shift
  mkdir -p "$(dirname "$file")"
  [ -s "$file" ] || echo '{}' >"$file"
  jq "$@" "$file" >"$file.tmp" && mv "$file.tmp" "$file"
}

# OpenVR games load vrclient.so from the first runtime entry. SteamVR also writes this
# file itself on launch, so only the runtime list is replaced and its other keys are kept.
set_openvr_runtime() {
  json_set "$OPENVR_PATHS" \
    --arg rt "$1" --arg steam "$STEAM" \
    '.version = 1 | .jsonid = "vrpathreg" | .runtime = [$rt]
     | .config //= [$steam + "/config"] | .log //= [$steam + "/logs"]'
}

# SteamVR rewrites its settings on exit, so only touch them while it isn't running
set_steamvr_autolaunch() {
  if pgrep -x vrserver >/dev/null; then
    echo "SteamVR is running; leaving power.autoLaunchSteamVROnButtonPress alone"
  elif [ -f "$VRSETTINGS" ]; then
    json_set "$VRSETTINGS" --argjson v "$1" '.power.autoLaunchSteamVROnButtonPress = $v'
  fi
}

case "${1:-}" in
  monado)
    if pgrep -x vrserver >/dev/null; then
      echo "Quit SteamVR first; it holds the headset."
      exit 1
    fi
    mkdir -p "$(dirname "$OPENXR_JSON")"
    ln -sfn "$MONADO_JSON" "$OPENXR_JSON"
    set_openvr_runtime "$XRIZER_DIR"
    # Powering on controllers would otherwise start SteamVR and steal the headset
    set_steamvr_autolaunch false
    echo "Monado active. Start with: systemctl --user start monado, then: wayvr"
    ;;
  steamvr)
    if [ ! -f "$STEAMVR/steamxr_linux64.json" ]; then
      echo "SteamVR not found at $STEAMVR"
      exit 1
    fi
    systemctl --user stop monado.service || true
    mkdir -p "$(dirname "$OPENXR_JSON")"
    ln -sfn "$STEAMVR/steamxr_linux64.json" "$OPENXR_JSON"
    set_openvr_runtime "$STEAMVR"
    set_steamvr_autolaunch true
    echo "SteamVR active. Launch it from Steam; for desktop screens run: steam-run wayvr"
    ;;
  status) ;;
  *) usage ;;
esac
status
