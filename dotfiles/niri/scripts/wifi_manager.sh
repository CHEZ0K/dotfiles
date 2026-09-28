#!/usr/bin/env bash
# Dedicated helper for connecting, reconnecting, disconnecting, and forgetting Wi-Fi networks in NetworkManager

ACTION="$1"
SSID="$2"
PASSWORD="$3"

CURRENT_USER="$USER"
[ -z "$CURRENT_USER" ] && CURRENT_USER=$(whoami)

# Dynamically find the primary Wi-Fi device
WIFI_DEV=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}')
[ -z "$WIFI_DEV" ] && WIFI_DEV="wlp2s0"

find_all_connections_for_ssid() {
    local target_ssid="$1"
    local uuids=()
    while IFS=: read -r name type uuid; do
        if [[ "$type" == "802-11-wireless" ]]; then
            if [[ "$name" == "$target_ssid" ]]; then
                uuids+=("$uuid")
            else
                local s
                s=$(nmcli -g 802-11-wireless.ssid c show "$uuid" 2>/dev/null)
                if [[ "$s" == "$target_ssid" ]]; then
                    uuids+=("$uuid")
                fi
            fi
        fi
    done < <(nmcli -t -f NAME,TYPE,UUID c show 2>/dev/null)
    echo "${uuids[@]}"
}

case "$ACTION" in
    connect)
        if [ -z "$SSID" ]; then
            echo "SSID is required" >&2
            exit 1
        fi

        ALL_UUIDS=($(find_all_connections_for_ssid "$SSID"))

        if [ -n "$PASSWORD" ]; then
            # User provided a password -> connect & save
            # 1. Update any existing profiles for this SSID
            for u in "${ALL_UUIDS[@]}"; do
                nmcli connection modify uuid "$u" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PASSWORD" connection.permissions "user:$CURRENT_USER" 2>/dev/null || true
                if nmcli --wait 15 connection up uuid "$u" ifname "$WIFI_DEV" >/dev/null 2>&1; then
                    exit 0
                fi
            done

            # 2. Try native dev wifi connect with password
            if nmcli --wait 15 dev wifi connect "$SSID" password "$PASSWORD" ifname "$WIFI_DEV" >/dev/null 2>&1; then
                exit 0
            fi

            # 3. Create fresh profile with credentials if not existing
            nmcli connection add type wifi con-name "$SSID" ssid "$SSID" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PASSWORD" connection.permissions "user:$CURRENT_USER" >/dev/null 2>&1 || \
            nmcli connection add type wifi con-name "$SSID" ssid "$SSID" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PASSWORD" >/dev/null 2>&1

            nmcli --wait 15 connection up id "$SSID" ifname "$WIFI_DEV"
            exit $?
        else
            # Password was NOT provided: connecting to a saved network or open network
            for u in "${ALL_UUIDS[@]}"; do
                if nmcli --wait 15 connection up uuid "$u" ifname "$WIFI_DEV" >/dev/null 2>&1; then
                    exit 0
                fi
            done

            # Try native connect for open network
            if nmcli --wait 15 dev wifi connect "$SSID" ifname "$WIFI_DEV" >/dev/null 2>&1; then
                exit 0
            fi

            # If all failed without password, indicate secrets were needed
            echo "Secrets were required" >&2
            exit 1
        fi
        ;;

    reconnect)
        if [ -z "$SSID" ]; then
            echo "SSID is required" >&2
            exit 1
        fi

        ALL_UUIDS=($(find_all_connections_for_ssid "$SSID"))
        for u in "${ALL_UUIDS[@]}"; do
            if nmcli --wait 15 connection up uuid "$u" ifname "$WIFI_DEV" >/dev/null 2>&1; then
                exit 0
            fi
        done

        if nmcli --wait 15 dev wifi connect "$SSID" ifname "$WIFI_DEV" >/dev/null 2>&1; then
            exit 0
        fi

        echo "Failed to reconnect" >&2
        exit 1
        ;;

    disconnect)
        if [ -n "$SSID" ]; then
            for u in $(find_all_connections_for_ssid "$SSID"); do
                nmcli connection down uuid "$u" >/dev/null 2>&1 || true
            done
            nmcli connection down id "$SSID" >/dev/null 2>&1 || true
        fi
        nmcli dev disconnect "$WIFI_DEV" >/dev/null 2>&1 || true
        echo "disconnected"
        exit 0
        ;;

    forget)
        if [ -n "$SSID" ]; then
            while IFS=: read -r name type uuid; do
                if [[ "$type" == "802-11-wireless" ]]; then
                    local s
                    s=$(nmcli -g 802-11-wireless.ssid c show "$uuid" 2>/dev/null)
                    if [[ "$s" == "$SSID" || "$name" == "$SSID" ]]; then
                        nmcli connection delete uuid "$uuid" >/dev/null 2>&1 || true
                    fi
                fi
            done < <(nmcli -t -f NAME,TYPE,UUID c show 2>/dev/null)
            nmcli connection delete id "$SSID" >/dev/null 2>&1 || true
        fi
        ;;

    *)
        echo "Usage: $0 {connect|reconnect|disconnect|forget} <SSID> [PASSWORD]"
        exit 1
        ;;
esac
