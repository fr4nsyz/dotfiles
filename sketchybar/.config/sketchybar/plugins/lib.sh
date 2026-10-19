#!/usr/bin/env bash
# shared helpers for pip-boy plugins

PIP_FG=0xffcbb6ff
PIP_DIM=0xff6a5b8f
PIP_ICON=0xff9a80d0
PIP_ACCENT=0xffa98bff
PIP_AMBER=0xffe6a94d
PIP_FONT="BlexMono Nerd Font"

# clamp numeric
pb_clamp() {
  local v=${1:-0}
  (( v < 0 )) && v=0
  (( v > 100 )) && v=100
  printf '%s' "$v"
}
