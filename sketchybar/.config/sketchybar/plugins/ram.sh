#!/usr/bin/env bash
source "$HOME/.config/sketchybar/plugins/lib.sh"

free=$(memory_pressure 2>/dev/null | awk -F': ' '/System-wide memory free percentage/ {gsub(/[^0-9]/,"",$2); print $2}')

if [[ -z "$free" ]]; then
  total=$(sysctl -n hw.memsize 2>/dev/null)
  pagesize=$(sysctl -n hw.pagesize 2>/dev/null)
  vmfree=$(vm_stat | awk '/Pages free/ {gsub(/[^0-9]/,"",$3); print $3}')
  free=$(awk -v f="${vmfree:-0}" -v p="${pagesize:-16384}" -v t="${total:-1}" 'BEGIN{ printf "%.0f", (f*p*100)/t }')
fi

used=$(awk -v f="$free" 'BEGIN{ printf "%.0f", 100 - f }')
used=$(pb_clamp "$used")

color=$PIP_ACCENT
(( used >= 85 )) && color=$PIP_AMBER

sketchybar --set "$NAME" \
  label="${used}%" \
  label.color=$color
