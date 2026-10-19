#!/usr/bin/env bash
source "$HOME/.config/sketchybar/plugins/lib.sh"

month=$(date '+%b')
day=$(date '+%d')
day=$(( 10#$day ))
time=$(date '+%H:%M')

case "$day" in
  11|12|13) suffix="th" ;;
  *1)       suffix="st" ;;
  *2)       suffix="nd" ;;
  *3)       suffix="rd" ;;
  *)        suffix="th" ;;
esac

year=$(date '+%Y')

sketchybar --set "$NAME" \
  label="${month} ${day}${suffix} ${year}  ${time}" \
  label.color=$PIP_FG
