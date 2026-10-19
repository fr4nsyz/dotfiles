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
raw=$(date '+%z')                 # e.g. -0400
sign="${raw:0:1}"
hours="${raw:1:2}"
hours=$(( 10#$hours ))            # strip leading zero
zone="UTC${sign}${hours}"

sketchybar --set "$NAME" \
  label="${month} ${day}${suffix} ${year}  ${time}  ${zone}" \
  label.color=$PIP_FG
