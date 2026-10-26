#!/usr/bin/env bash
source "$HOME/.config/sketchybar/plugins/lib.sh"

name=${NAME:-battery}
hover_state="${TMPDIR:-/tmp}/sketchybar-battery-hover"

batt=$(ioreg -rn AppleSmartBattery -r 2>/dev/null)

cur=$(echo "$batt" | awk -F'= ' '/"CurrentCapacity" /{print $2+0; exit}')
max=$(echo "$batt" | awk -F'= ' '/"MaxCapacity" /{print $2+0; exit}')
charging=$(echo "$batt" | awk -F'= ' '/"IsCharging" /{print $2+0; exit}')

# no battery (desktop) -> hide the module and its separator
if [[ -z "$cur" || -z "$max" || "$max" -eq 0 ]]; then
  rm -f "$hover_state"
  sketchybar --set "$name" drawing=off
  sketchybar --set sep3 drawing=off
  exit 0
fi

pct=$(awk -v c="$cur" -v m="$max" 'BEGIN{ printf "%.0f", (c*100)/m }')
pct=$(pb_clamp "$pct")

color=$PIP_ACCENT
label="${pct}%"
if [[ "$charging" == "1" ]]; then
  color=$PIP_AMBER
  label="+${pct}%"
elif (( pct <= 20 )); then
  color=$PIP_AMBER
fi

# The percentage lives in the slider's knob, i.e. inside the bar's own
# slot. The bar is hidden while hovering, the knob holds the number,
# and the slot keeps its width either way -> nothing on the bar moves.
show_bar() {
  sketchybar --set "$name" \
    slider.percentage=$pct \
    slider.highlight_color=$color \
    slider.knob.string="" \
    slider.background.drawing=on
}

show_percent() {
  sketchybar --set "$name" \
    slider.percentage=0 \
    slider.knob.string="$label" \
    slider.knob.color=$color \
    slider.background.drawing=off
}

case "$SENDER" in
  mouse.entered)
    printf '1' > "$hover_state"
    show_percent
    ;;
  mouse.exited)
    rm -f "$hover_state"
    show_bar
    ;;
  mouse.clicked)
    # a click drags the slider, snap it back to the real level
    if [[ -f "$hover_state" ]]; then
      show_percent
    else
      show_bar
    fi
    ;;
  *)
    if [[ -f "$hover_state" ]]; then
      show_percent
    else
      show_bar
    fi
    ;;
esac

sketchybar --set sep3 drawing=on
