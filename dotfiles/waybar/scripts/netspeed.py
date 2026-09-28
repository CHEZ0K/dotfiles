#!/usr/bin/env python3
import json, os, time

STATE_FILE = "/tmp/waybar_netspeed_state.json"

def format_speed(bytes_sec):
    if bytes_sec < 1024 * 1024:
        return f"{bytes_sec / 1024:.0f}K"
    return f"{bytes_sec / (1024 * 1024):.1f}M"

def get_net_bytes():
    rx = 0
    tx = 0
    try:
        with open("/proc/net/dev", "r") as f:
            lines = f.readlines()[2:]
        for line in lines:
            parts = line.split()
            if len(parts) >= 10 and not parts[0].startswith("lo:"):
                rx += int(parts[1])
                tx += int(parts[9])
    except Exception:
        pass
    return rx, tx

def main():
    now = time.time()
    rx, tx = get_net_bytes()
    
    rx_speed = 0
    tx_speed = 0
    
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                prev = json.load(f)
            dt = now - prev.get("time", now)
            if dt > 0.4:
                rx_speed = max(0, (rx - prev.get("rx", rx)) / dt)
                tx_speed = max(0, (tx - prev.get("tx", tx)) / dt)
        except Exception:
            pass
            
    with open(STATE_FILE, "w") as f:
        json.dump({"time": now, "rx": rx, "tx": tx}, f)
        
    text = f"↓ {format_speed(rx_speed)}  ↑ {format_speed(tx_speed)}"
    
    tooltip = (
        f"<b>Скорость сети</b>\n"
        f"───────────────────\n"
        f"Входящий: {format_speed(rx_speed)}/с\n"
        f"Исходящий: {format_speed(tx_speed)}/с"
    )
    
    print(json.dumps({
        "text": text,
        "tooltip": tooltip,
        "class": "netspeed-pill"
    }))

if __name__ == "__main__":
    main()
