#!/usr/bin/env bash

HYPR_ANIMATIONS=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
if [ "$HYPR_ANIMATIONS" = "true" ] || [ "$HYPR_ANIMATIONS" = "1" ]; then
  hyprctl eval 'hl.config({ animations = { enabled = false }, decoration = { shadow = { enabled = false }, blur = { enabled = false } } })'
  # Disable opacity on all clients
  hyprctl clients -j | jq -r ".[].address" | xargs -I {} hyprctl dispatch "hl.dsp.window.set_prop({ window = 'address:{}', prop = 'opaque', value = '1' })"
  notify-desktop "🍬🛑 Eye candy disabled" "Hyprland animations, shadows and blur effects have been disabled." --urgency=low --app-name="Hypr Candy"
else
  hyprctl reload
  notify-desktop "🍬👀 Eye candy enabled" "Hyprland animations, shadows and blur effects have been restored." --urgency=low --app-name="Hypr Candy"
fi
