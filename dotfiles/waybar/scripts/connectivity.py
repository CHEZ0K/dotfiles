#!/usr/bin/env python3
import json, os, subprocess

def get_wifi_info():
    ssid = ""
    signal = 0
    state = "disconnected"
    try:
        res = subprocess.run(["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,DEVICE,TYPE", "dev", "wifi"], capture_output=True, text=True, timeout=1.2)
        for line in res.stdout.strip().split("\n"):
            if line.startswith("yes:"):
                parts = line.split(":")
                if len(parts) >= 3:
                    ssid = parts[1]
                    signal = int(parts[2]) if parts[2].isdigit() else 70
                    state = "connected"
                    break
    except Exception:
        pass
    
    if not ssid:
        try:
            res = subprocess.run(["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "dev"], capture_output=True, text=True, timeout=1.2)
            for line in res.stdout.strip().split("\n"):
                parts = line.split(":")
                if len(parts) >= 3 and parts[0] == "wifi" and parts[1] == "connected":
                    ssid = parts[2]
                    state = "connected"
                    break
        except Exception:
            pass
    return state == "connected", ssid, signal

def get_bt_info():
    powered = False
    connected_devs = []
    try:
        res = subprocess.run(["bluetoothctl", "show"], capture_output=True, text=True, timeout=1.0)
        if "Powered: yes" in res.stdout:
            powered = True
        
        if powered:
            res_devs = subprocess.run(["bluetoothctl", "devices", "Connected"], capture_output=True, text=True, timeout=1.0)
            for line in res_devs.stdout.strip().split("\n"):
                if line.startswith("Device "):
                    parts = line.split(" ", 2)
                    if len(parts) >= 3:
                        connected_devs.append(parts[2])
    except Exception:
        pass
    return powered, connected_devs

def main():
    wifi_connected, ssid, signal = get_wifi_info()
    bt_powered, bt_devs = get_bt_info()
    bt_active = bt_powered or len(bt_devs) > 0

    wifi_icon = "󰤨" if wifi_connected else "󰤮"
    bt_icon = ("󰂱" if bt_devs else "󰂯") if bt_active else "󰂲"

    # 4 Dynamic States
    if not wifi_connected and not bt_active:
        # State 1: Both OFF
        state_class = "state-both-off"
        text = f"{wifi_icon}  {bt_icon}"
    elif wifi_connected and not bt_active:
        # State 2: Wi-Fi ON (left), BT OFF (right)
        state_class = "state-wifi-only"
        text = f"{wifi_icon}  {bt_icon}"
    elif not wifi_connected and bt_active:
        # State 3: Wi-Fi OFF (left), BT ON (right)
        state_class = "state-bt-only"
        text = f"{wifi_icon}  {bt_icon}"
    else:
        # State 4: Both ON (Unified active tablet)
        state_class = "state-both-on"
        text = f"{wifi_icon}   {bt_icon}"

    tooltip = [
        "<b>Панель подключений (Control Center)</b>",
        "───────────────────────────",
        f"<b>Wi-Fi:</b> {ssid or 'Подключен'} (Сигнал: {signal}%)" if wifi_connected else "<b>Wi-Fi:</b> Отключен",
        f"<b>Bluetooth:</b> {', '.join(bt_devs) if bt_devs else ('Включен' if bt_powered else 'Выключен')}",
        "",
        "<i>Кликните для открытия панели управления</i>"
    ]

    print(json.dumps({
        "text": text,
        "tooltip": "\n".join(tooltip),
        "class": state_class
    }))

if __name__ == "__main__":
    main()
