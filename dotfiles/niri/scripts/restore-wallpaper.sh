#!/usr/bin/env bash
# Restore active wallpaper on startup:
# If static: launch swaybg (consumes only ~6MB) and ensure heavy daemons are NOT running.
# If animated/video: launch the appropriate animated engine.

WAL_FILE="$HOME/.cache/wal/wal"
DEFAULT_WALL="$HOME/67/. 74.jpg"

wall="$DEFAULT_WALL"
if [[ -f "$WAL_FILE" ]] && [[ -s "$WAL_FILE" ]]; then
    candidate="$(cat "$WAL_FILE" 2>/dev/null | tr -d '\r\n')"
    [[ -f "$candidate" ]] && wall="$candidate"
fi

ext="${wall##*.}"
ext="${ext,,}"

case "$ext" in
    gif)
        pkill -x swaybg 2>/dev/null || true
        pkill -9 -f linux-wallpaperengine 2>/dev/null || true
        if ! pgrep -x awww-daemon >/dev/null 2>&1; then
            awww-daemon >/dev/null 2>&1 &
            sleep 0.2
        fi
        awww img "$wall" >/dev/null 2>&1 &
        ;;
    mp4|webm|mkv)
        pkill -x swaybg 2>/dev/null || true
        pkill -9 -f awww-daemon 2>/dev/null || true
        # Video scene: wallpaper engine or mpvpaper
        if command -v linux-wallpaperengine >/dev/null 2>&1; then
            setsid linux-wallpaperengine --fps 60 --scaling fill "$wall" >/dev/null 2>&1 &
        fi
        ;;
    *)
        if command -v awww >/dev/null 2>&1; then
            pkill -x swaybg 2>/dev/null || true
            pkill -9 -f linux-wallpaperengine 2>/dev/null || true
            if ! pgrep -x awww-daemon >/dev/null 2>&1; then
                awww-daemon >/dev/null 2>&1 &
                sleep 0.3
            fi
            awww img "$wall" --transition-type fade --transition-duration 0.5 >/dev/null 2>&1 &
        elif command -v swaybg >/dev/null 2>&1; then
            pkill -9 -f awww-daemon 2>/dev/null || true
            pkill -9 -f linux-wallpaperengine 2>/dev/null || true
            pkill -x swaybg 2>/dev/null || true
            swaybg -i "$wall" -m fill >/dev/null 2>&1 &
        elif [[ -x "$HOME/.local/bin/swaybg" ]]; then
            pkill -9 -f awww-daemon 2>/dev/null || true
            pkill -9 -f linux-wallpaperengine 2>/dev/null || true
            pkill -x swaybg 2>/dev/null || true
            "$HOME/.local/bin/swaybg" -i "$wall" -m fill >/dev/null 2>&1 &
        fi
        ;;
esac
