#!/usr/bin/env bash
source "$HOME/.config/sketchybar/plugins/lib.sh"

vol=$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)
muted=$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)
[[ -z "$vol" || "$vol" == "missing value" ]] && vol=0
vol=$(pb_clamp "$vol")

if [[ "$muted" == "true" ]]; then
  sketchybar --set "$NAME" \
    label="MUTE" \
    label.color=$PIP_AMBER
else
  sketchybar --set "$NAME" \
    label="${vol}%" \
    label.color=$PIP_FG
fi
