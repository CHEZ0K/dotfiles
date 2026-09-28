#!/usr/bin/env python3
import glob, json, os, subprocess, time

CACHE_FILE = "/tmp/waybar_wifi_cache.json"

def is_bt_on():
    try:
        for f in glob.glob("/sys/class/rfkill/rfkill*"):
            try:
                with open(f + "/type") as tf, open(f + "/state") as sf:
                    if tf.read().strip() == "bluetooth" and sf.read().strip() == "1":
                        return True
            except Exception:
                pass
    except Exception:
        pass
    return False

def get_net_stats():
    wifi_connected = False
    signal = 0
    ethernet_connected = False

    # Check wireless via /proc/net/wireless (instant, 0 subprocesses)
    try:
        with open("/proc/net/wireless", "r") as f:
            for line in f:
                if ":" in line and not "Inter-" in line:
                    parts = line.split(":")
                    stats = parts[1].split()
                    if len(stats) >= 2:
                        link = float(stats[1].replace(".", ""))
                        signal = int(min(100, max(0, (link / 70.0) * 100)))
                        wifi_connected = True
                        break
    except Exception:
        pass

    # Check ethernet ifaces via /sys/class/net
    try:
        for iface in os.listdir("/sys/class/net"):
            if not iface.startswith("wl") and iface != "lo":
                op_file = f"/sys/class/net/{iface}/operstate"
                if os.path.exists(op_file):
                    with open(op_file, "r") as f:
                        if f.read().strip() == "up":
                            ethernet_connected = True
                            break
    except Exception:
        pass

    return wifi_connected, ethernet_connected, signal

def get_cached_ssid(wifi_connected, ethernet_connected):
    if not (wifi_connected or ethernet_connected):
        return ""
    now = time.time()
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r") as f:
                d = json.load(f)
            if now - d.get("time", 0) < 30 and d.get("ssid"):
                return d.get("ssid")
        except Exception:
            pass

    ssid = ""
    try:
        res = subprocess.run(["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "dev"], capture_output=True, text=True, timeout=0.8)
        for line in res.stdout.strip().split("\n"):
            parts = line.split(":")
            if len(parts) >= 3 and parts[1] == "connected":
                if parts[0] == "wifi" or parts[0] in ("ethernet", "wired"):
                    ssid = parts[2]
                    break
        with open(CACHE_FILE, "w") as f:
            json.dump({"time": now, "ssid": ssid}, f)
    except Exception:
        pass
    return ssid

def main():
    wifi_connected, ethernet_connected, signal = get_net_stats()
    is_online = wifi_connected or ethernet_connected
    ssid = get_cached_ssid(wifi_connected, ethernet_connected)
    bt_active = is_bt_on()

    if is_online:
        if ethernet_connected and not wifi_connected:
            icon = "󰈀"
            tooltip = f"<b>Ethernet:</b> {ssid or 'Подключен'}"
        else:
            icon = "󰤨" if signal > 75 else ("󰤥" if signal > 50 else ("󰤢" if signal > 25 else "󰤟"))
            tooltip = f"<b>Wi-Fi:</b> {ssid or 'Подключен'} (Сигнал: {signal}%)"

        if bt_active:
            css_class = "wifi-on merged-left"
        else:
            css_class = "wifi-on single-pill"
    else:
        icon = ""
        css_class = "hidden"
        tooltip = "<b>Сеть:</b> Отключена"

    print(json.dumps({
        "text": icon,
        "tooltip": tooltip,
        "class": css_class
    }))

if __name__ == "__main__":
    main()
