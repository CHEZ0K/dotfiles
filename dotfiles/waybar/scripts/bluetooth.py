#!/usr/bin/env python3
import glob, json, os, subprocess, time

CACHE_FILE = "/tmp/waybar_bt_cache.json"

def is_wifi_on():
    try:
        with open("/proc/net/wireless", "r") as f:
            for line in f:
                if ":" in line and not "Inter-" in line:
                    return True
    except Exception:
        pass
    return False

def is_bt_powered_rfkill():
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

def get_bt_info():
    powered = is_bt_powered_rfkill()
    if not powered:
        return False, []

    # Check cache for connected devices
    now = time.time()
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r") as f:
                d = json.load(f)
            if now - d.get("time", 0) < 10:
                return True, d.get("devs", [])
        except Exception:
            pass

    connected_devs = []
    try:
        res_devs = subprocess.run(["bluetoothctl", "devices", "Connected"], capture_output=True, text=True, timeout=0.8)
        for line in res_devs.stdout.strip().split("\n"):
            if line.startswith("Device "):
                parts = line.split(" ", 2)
                if len(parts) >= 3:
                    connected_devs.append(parts[2])
        with open(CACHE_FILE, "w") as f:
            json.dump({"time": now, "devs": connected_devs}, f)
    except Exception:
        pass

    return True, connected_devs

def main():
    wifi_active = is_wifi_on()
    bt_powered, bt_devs = get_bt_info()
    bt_active = bt_powered or len(bt_devs) > 0

    if bt_active:
        icon = "󰂱" if bt_devs else "󰂯"
        if wifi_active:
            css_class = "bt-on merged-right"
        else:
            css_class = "bt-on single-pill"
        tooltip = f"<b>Bluetooth:</b> {', '.join(bt_devs) if bt_devs else 'Включен'}"
    else:
        icon = "󰂲"
        css_class = "bt-off no-pill"
        tooltip = "<b>Bluetooth:</b> Выключен"

    print(json.dumps({
        "text": icon,
        "tooltip": tooltip,
        "class": css_class
    }))

if __name__ == "__main__":
    main()
