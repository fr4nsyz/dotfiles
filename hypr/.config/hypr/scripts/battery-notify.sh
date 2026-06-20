#!/usr/bin/env bash

BAT=/sys/class/power_supply/BAT0
FLAG_DIR=/tmp/battery-notify

mkdir -p "$FLAG_DIR"

while true; do
    status=$(cat "$BAT/status")
    capacity=$(cat "$BAT/capacity")

    if [ "$status" = "Discharging" ]; then
        for level in 20 15 10 5; do
            flag="$FLAG_DIR/$level"
            if [ "$capacity" -le "$level" ] && [ ! -f "$flag" ]; then
                touch "$flag"
                notify-send -u critical "Battery Low" "${capacity}% remaining — plug in now!" -i battery-caution
            fi
        done
    else
        rm -f "$FLAG_DIR"/*
    fi

    sleep 60
done
