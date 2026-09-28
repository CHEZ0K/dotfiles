#!/usr/bin/env bash

APP_CLASS="cavaunderbar"
STATE_FILE="/tmp/cava_underbar_status"
HIDDEN_FILE="/tmp/cava_underbar_hidden_by_fs"
LOCK_FILE="/tmp/cava_underbar.lock"

need() { command -v "$1" >/dev/null 2>&1 || { echo "$1 is required"; exit 1; }; }

need foot
need cava
need jq

[[ ! -f "$STATE_FILE" ]] && echo "0" > "$STATE_FILE"
[[ ! -f "$HIDDEN_FILE" ]] && echo "0" > "$HIDDEN_FILE"

sync_workspace() {
    if [[ -n "$NIRI_SOCKET" || "${XDG_CURRENT_DESKTOP,,}" == *"niri"* ]]; then
        local active_ws_info active_ws_id active_idx cava_win cava_id cava_ws_id
        active_ws_info="$(niri msg --json workspaces 2>/dev/null | jq -r '.[] | select(.is_active == true) | "\(.id) \(.idx)"' 2>/dev/null)"
        [[ -z "$active_ws_info" ]] && return 0
        active_ws_id="$(echo "$active_ws_info" | awk '{print $1}')"
        active_idx="$(echo "$active_ws_info" | awk '{print $2}')"

        cava_win="$(niri msg --json windows 2>/dev/null | jq -r '.[] | select(.app_id == "'"$APP_CLASS"'") | "\(.id) \(.workspace_id)"' 2>/dev/null)"
        [[ -z "$cava_win" ]] && return 0
        cava_id="$(echo "$cava_win" | awk '{print $1}')"
        cava_ws_id="$(echo "$cava_win" | awk '{print $2}')"

        if [[ -n "$cava_id" && -n "$cava_ws_id" && "$cava_ws_id" != "$active_ws_id" ]]; then
            niri msg action move-window-to-workspace --window-id "$cava_id" --focus false "$active_idx" 2>/dev/null
        fi
    fi
}

is_running() {
    pgrep -f "$APP_CLASS" >/dev/null
}

run_cava() {
    is_running && return 0

    nohup foot --config /home/chezok/.config/cava/foot_cava.ini \
            --app-id="$APP_CLASS" \
            cava -p /home/chezok/.config/cava/config_underbar </dev/null >/dev/null 2>&1 &
}

stop_cava() {
    pkill -f "$APP_CLASS" 2>/dev/null
}

toggle_cava() {
    if is_running; then
        stop_cava
        echo "0" > "$STATE_FILE"
        echo "0" > "$HIDDEN_FILE"
    else
        run_cava
        echo "1" > "$STATE_FILE"
        echo "0" > "$HIDDEN_FILE"
    fi
}

if [[ "$1" == "toggle" ]]; then
    toggle_cava
    exit 0
fi

if [[ "$1" == "stop" ]]; then
    stop_cava
    echo "0" > "$STATE_FILE"
    echo "0" > "$HIDDEN_FILE"
    exit 0
fi

if [[ "$1" == "start" ]]; then
    if ! is_running; then
        run_cava
        echo "1" > "$STATE_FILE"
        echo "0" > "$HIDDEN_FILE"
    fi
    exit 0
fi
echo "Cava Underbar daemon started, check fullscreen and workspaces"

# Проверка фуллскрина для Niri и Hyprland
get_fs() {
    if [[ -n "$NIRI_SOCKET" || "${XDG_CURRENT_DESKTOP,,}" == *"niri"* ]]; then
        # Niri IPC
        niri msg --json focused-window 2>/dev/null | jq -r 'if (.is_fullscreen // false) then 2 else 0 end' 2>/dev/null
    else
        # Hyprland IPC
        hyprctl activewindow -j 2>/dev/null | jq -r '.fullscreen // 0' 2>/dev/null
    fi
}

daemon_tick() {
    local want_on fs hidden
    want_on="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
    hidden="$(cat "$HIDDEN_FILE" 2>/dev/null || echo 0)"
    fs="$(get_fs)"
    [[ -z "$fs" ]] && fs=0

    [[ "$want_on" != "1" ]] && return 0

    if [[ "$fs" == "2" ]]; then
        if pgrep -f "foot.*$APP_CLASS" >/dev/null; then
            stop_cava
            echo "1" > "$HIDDEN_FILE"
        fi
        return 0
    fi

    if ! pgrep -f "foot.*$APP_CLASS" >/dev/null; then
        run_cava
        echo "0" > "$HIDDEN_FILE"
    else
        sync_workspace
    fi
}

if [[ -n "$NIRI_SOCKET" || "${XDG_CURRENT_DESKTOP,,}" == *"niri"* ]]; then
    exec python3 /home/chezok/.local/bin/cava_niri_sync.py
fi

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

while true; do
    daemon_tick
    sleep 1
done
