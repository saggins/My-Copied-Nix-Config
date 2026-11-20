#!/usr/bin/env bash
# Live slider for Hyprland's input:sensitivity (-1.0 .. 1.0).
# Changes apply immediately but are not persisted; copy the final value
# into the `input` block of the Hyprland config to keep it.

set_sens() {
  hyprctl eval "hl.config({ input = { sensitivity = ${1} } })" >/dev/null
}

to_float() {
  awk -v v="${1}" 'BEGIN { printf "%.2f", v / 100 }'
}

original=$(hyprctl getoption input:sensitivity | awk '/float:/ { printf "%d", $2 * 100 }')

# zenity's scale is integer-only, so the slider works in hundredths.
# --print-partial emits every position while dragging.
final=""
while read -r step; do
  final=$(to_float "${step}")
  set_sens "${final}"
done < <(zenity --scale \
  --title="Mouse sensitivity" \
  --text="Drag to adjust (applies live). Cancel to revert." \
  --min-value=-100 --max-value=100 --step=5 \
  --value="${original}" --print-partial)

# Cancel/close prints nothing after the partials and exits non-zero;
# PIPESTATUS isn't available for process substitution, so check `wait`.
if ! wait $!; then
  set_sens "$(to_float "${original}")"
  echo "Reverted to $(to_float "${original}")"
  exit 0
fi

echo "Sensitivity set to ${final} (not persisted)"
echo "Persist with:  input = { sensitivity = ${final}, ... }"
