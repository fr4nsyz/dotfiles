#!/usr/bin/env bash
source "$HOME/.config/sketchybar/plugins/lib.sh"

WS="${NAME#space.}"

# Prefer values passed through the trigger (fast path).
# Fall back to querying AeroSpace when run standalone / on periodic refresh.
if [[ -n "$FOCUSED" ]]; then
  FOCUSED_WS="$FOCUSED"
else
  FOCUSED_WS=$(aerospace list-workspaces --focused 2>/dev/null)
fi

if [[ -n "$OCCUPIED" ]]; then
  OCCUPIED_LIST="${OCCUPIED//,/ }"
else
  OCCUPIED_LIST=$(aerospace list-workspaces --monitor all --empty no 2>/dev/null | tr '\n' ' ')
fi

if [[ "$WS" == "$FOCUSED_WS" ]]; then
  # focused -> glowing violet pill
  sketchybar --set "$NAME" \
    label.color=$PIP_FG \
    background.drawing=on \
    background.color=0x40a98bff \
    background.border_width=1 \
    background.border_color=$PIP_ACCENT
elif [[ " $OCCUPIED_LIST " == *" $WS "* ]]; then
  # has windows -> filled mid violet
  sketchybar --set "$NAME" \
    label.color=$PIP_ICON \
    background.drawing=off \
    background.border_width=0
else
  # empty -> faint
  sketchybar --set "$NAME" \
    label.color=$PIP_DIM \
    background.drawing=off \
    background.border_width=0
fi
