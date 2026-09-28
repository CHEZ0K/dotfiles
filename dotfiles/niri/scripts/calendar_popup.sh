#!/usr/bin/env bash
# Toggle Interactive Calendar Popup

if pgrep -f 'quickshell.*calendar' >/dev/null 2>&1; then
  pkill -9 -f 'quickshell.*calendar' || true
else
  quickshell -p "$HOME/.config/hypr/scripts/calendar/Shell.qml" >/dev/null 2>&1 &
fi
