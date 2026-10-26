#!/usr/bin/env bash
source "$HOME/.config/sketchybar/plugins/lib.sh"

cpus=$(sysctl -n hw.ncpu 2>/dev/null)
[[ -z "$cpus" || "$cpus" -lt 1 ]] && cpus=1

load=$(ps -A -o %cpu 2>/dev/null | awk '{s+=$1} END{print s+0}')
used=$(awk -v l="$load" -v c="$cpus" 'BEGIN{ printf "%.0f", l/c }')
used=$(pb_clamp "$used")

color=$PIP_ACCENT
(( used >= 80 )) && color=$PIP_AMBER

sketchybar --set "$NAME" \
  label="${used}%" \
  label.color=$color
