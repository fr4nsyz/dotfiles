#!/usr/bin/env bash
source "$HOME/.config/sketchybar/plugins/lib.sh"

batt=$(ioreg -rn AppleSmartBattery -r 2>/dev/null)

cur=$(echo "$batt" | awk -F'= ' '/"CurrentCapacity" /{print $2+0; exit}')
max=$(echo "$batt" | awk -F'= ' '/"MaxCapacity" /{print $2+0; exit}')
charging=$(echo "$batt" | awk -F'= ' '/"IsCharging" /{print $2+0; exit}')

# no battery (desktop) -> hide the module and its separator
if [[ -z "$cur" || -z "$max" || "$max" -eq 0 ]]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

sketchybar --set "$NAME" drawing=on

pct=$(awk -v c="$cur" -v m="$max" 'BEGIN{ printf "%.0f", (c*100)/m }')
pct=$(pb_clamp "$pct")

color=$PIP_FG
label="${pct}%"

if [[ "$charging" == "1" ]]; then
  label="+${pct}%"
  color=$PIP_AMBER
elif (( pct <= 20 )); then
  color=$PIP_AMBER
fi

sketchybar --set "$NAME" label="$label" label.color=$color
