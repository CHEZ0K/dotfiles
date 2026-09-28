#!/usr/bin/env bash
# Toggle Interactive Power Menu via Quickshell IPC

if ! pgrep -f 'quickshell.*sidebar.qml' >/dev/null 2>&1; then
    quickshell -p "$HOME/.config/quickshell/ii/sidebar.qml" >/dev/null 2>&1 &
    sleep 0.8
fi

quickshell ipc -p "$HOME/.config/quickshell/ii/sidebar.qml" call session toggle >/dev/null 2>&1
