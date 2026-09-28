#!/usr/bin/env bash
# ==============================================================================
# Silent Clipboard History Viewer (Cliphist + Rofi + wl-clipboard)
# ==============================================================================

if ! command -v cliphist >/dev/null 2>&1; then
    exit 1
fi

case "$1" in
    --clear|clear|-c)
        cliphist wipe
        exit 0
        ;;
    --delete|delete|-d)
        selected=$(cliphist list | rofi -dmenu -p "🗑 Удалить" -theme-str 'window { width: 680px; } listview { lines: 9; }' -display-columns 2)
        if [ -n "$selected" ]; then
            echo "$selected" | cliphist delete
        fi
        exit 0
        ;;
esac

# Standard selection: list history -> select -> decode to clipboard silently
selected=$(cliphist list | rofi -dmenu \
    -p "📋 Буфер" \
    -theme-str 'window { width: 700px; } listview { lines: 10; }' \
    -display-columns 2)

if [ -n "$selected" ]; then
    echo "$selected" | cliphist decode | wl-copy
fi
