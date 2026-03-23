#!/bin/bash

options="Shutdown\nReboot\nLogout\nSuspend"

chosen=$(echo -e "$options" | wofi --dmenu --prompt "Power Menu")

case "$chosen" in
    Shutdown) systemctl poweroff ;;
    Reboot) systemctl reboot ;;
    Logout) hyprctl dispatch exit ;;
    Suspend) systemctl suspend ;;
esac
