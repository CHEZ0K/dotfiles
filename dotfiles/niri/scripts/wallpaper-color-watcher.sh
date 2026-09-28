#!/usr/bin/env bash
# Automatically sync Niri backdrop-color, focus-ring, and GTK theme/icons with active wallpaper / wal palette

NIRI_CONF="$HOME/.config/niri/config.kdl"
WAL_JSON="$HOME/.cache/wal/colors.json"

last_wal_mtime=""
last_image=""

update_colors() {
    local bg=""
    local c1=""
    local c2=""

    # 1. Prefer wal colors if available
    if [[ -f "$WAL_JSON" ]] && command -v jq >/dev/null 2>&1; then
        bg="$(jq -r '.special.background // empty' "$WAL_JSON")"
        c1="$(jq -r '.colors.color2 // empty' "$WAL_JSON")"
        c2="$(jq -r '.colors.color4 // empty' "$WAL_JSON")"
    fi

    # 2. Fallback: extract directly from image if bg is empty
    if [[ -z "$bg" ]] && [[ -n "$last_image" ]] && [[ -f "$last_image" ]] && command -v magick >/dev/null 2>&1; then
        local hex
        hex="$(magick "$last_image" -resize 1x1\! -format "%[hex:p{0,0}]" info: 2>/dev/null)"
        [[ -n "$hex" ]] && bg="#$hex"
    fi

    if [[ -n "$bg" && -f "$NIRI_CONF" ]]; then
        local changed=0

        # Check if backdrop-color differs
        local current_bg
        current_bg="$(grep -oP 'backdrop-color "\K#[0-9a-fA-F]+' "$NIRI_CONF" | head -n 1)"
        if [[ "$current_bg" != "$bg" ]]; then
            sed -i -E "s/backdrop-color \"#[0-9a-fA-F]+\"/backdrop-color \"$bg\"/" "$NIRI_CONF"
            changed=1
        fi

        # Update active-gradient if wal colors are present
        if [[ -n "$c1" && -n "$c2" ]]; then
            local target_gradient="active-gradient from=\"${c1}ee\" to=\"${c2}ee\""
            if ! grep -Fq "$target_gradient" "$NIRI_CONF"; then
                sed -i -E "s/active-gradient from=\"#[0-9a-fA-F]+\" to=\"#[0-9a-fA-F]+\"/$target_gradient/" "$NIRI_CONF"
                changed=1
            fi
        fi

        if [[ $changed -eq 1 ]]; then
            command -v niri >/dev/null 2>&1 && niri msg action load-config-file >/dev/null 2>&1 || true
        fi
    fi

    # 3. Live-reload GTK3/Nemo colors and icons without killing applications
    if [[ -x "$HOME/.local/bin/reload-gtk-colors" ]]; then
        "$HOME/.local/bin/reload-gtk-colors" >/dev/null 2>&1 &
    fi
}

# Run immediately on start
update_colors

# Daemon loop: check every 0.5 seconds
while true; do
    sleep 0.5
    cur_wal_mtime=""
    [[ -f "$WAL_JSON" ]] && cur_wal_mtime="$(stat -c %Y "$WAL_JSON" 2>/dev/null)"

    cur_image=""
    if command -v awww >/dev/null 2>&1; then
        cur_image="$(awww query 2>/dev/null | grep -oP 'image: \K.*')"
    fi
    if [[ -z "$cur_image" ]]; then
        cur_image="$(pgrep -a swaybg 2>/dev/null | sed -E 's/.*-i (.*) -m .*/\1/' | head -n 1)"
    fi

    if [[ "$cur_wal_mtime" != "$last_wal_mtime" || "$cur_image" != "$last_image" ]]; then
        # If wallpaper changed and wal hasn't run on it yet:
        if [[ -n "$cur_image" && "$cur_image" != "$last_image" && -f "$cur_image" ]]; then
            if command -v wal >/dev/null 2>&1; then
                wal -i "$cur_image" -s -t -n -q 2>/dev/null
                [[ -f "$WAL_JSON" ]] && cur_wal_mtime="$(stat -c %Y "$WAL_JSON" 2>/dev/null)"
            fi
        fi

        last_wal_mtime="$cur_wal_mtime"
        last_image="$cur_image"
        update_colors
    fi
done
