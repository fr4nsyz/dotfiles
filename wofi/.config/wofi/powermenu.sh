#!/bin/env bash

options="shutdown\nreboot\nlogout\nsuspend"

chosen=$(echo -e "$options" | wofi --dmenu --prompt "Power Menu")

case "$chosen" in
shutdown) systemctl poweroff ;;
reboot) systemctl reboot ;;
logout) hyprctl dispatch exit ;;
suspend) systemctl suspend ;;
esac
