#!/usr/bin/env bash

PIDFILE="/tmp/ffmpeg_rec.pid"

if [[ -f "$PIDFILE" ]]; then
    echo "Recording already in progress (pid file exists: $PIDFILE)."
    echo "Aborting."
    exit 1
fi

video_name="$(date +%Y-%m-%d_%H-%M-%S)"

ffmpeg \
    -video_size 2880x1800 -framerate 30 -f x11grab -i :0.0 \
    -f alsa -i default \
    -c:v libx264 -preset ultrafast -c:a aac ~/Videos/${video_name}.mp4 &

echo $! > "$PIDFILE"
