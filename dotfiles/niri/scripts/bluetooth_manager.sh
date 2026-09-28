#!/usr/bin/env bash
# Dedicated helper for Bluetooth power, scanning, connect, pair, and forget

ACTION="$1"
TARGET="$2"

case "$ACTION" in
    toggle)
        if bluetoothctl show | grep -q "Powered: yes"; then
            bluetoothctl power off >/dev/null 2>&1
        else
            rfkill unblock bluetooth >/dev/null 2>&1 || true
            bluetoothctl power on >/dev/null 2>&1
        fi
        ;;

    on)
        rfkill unblock bluetooth >/dev/null 2>&1 || true
        bluetoothctl power on >/dev/null 2>&1
        ;;

    off)
        bluetoothctl power off >/dev/null 2>&1
        ;;

    connect)
        if [ -n "$TARGET" ]; then
            bluetoothctl connect "$TARGET" >/dev/null 2>&1
        fi
        ;;

    disconnect)
        if [ -n "$TARGET" ]; then
            bluetoothctl disconnect "$TARGET" >/dev/null 2>&1
        fi
        ;;

    pair)
        if [ -n "$TARGET" ]; then
            bluetoothctl pair "$TARGET" >/dev/null 2>&1
            bluetoothctl trust "$TARGET" >/dev/null 2>&1
            bluetoothctl connect "$TARGET" >/dev/null 2>&1
        fi
        ;;

    forget)
        if [ -n "$TARGET" ]; then
            bluetoothctl disconnect "$TARGET" >/dev/null 2>&1 || true
            bluetoothctl untrust "$TARGET" >/dev/null 2>&1 || true
            bluetoothctl remove "$TARGET" >/dev/null 2>&1
        fi
        ;;

    *)
        echo "Usage: $0 {toggle|on|off|connect|disconnect|pair|forget} [MAC]"
        exit 1
        ;;
esac
