#!/usr/bin/env bash

PIDFILE=/tmp/ffmpeg_rec.pid

if [[ ! -f "$PIDFILE" ]]; then
    echo "No recording PID file found. Nothing to stop."
    exit 1
fi

PID=$(cat ${PIDFILE})
kill -s SIGINT $PID
rm ${PIDFILE}
