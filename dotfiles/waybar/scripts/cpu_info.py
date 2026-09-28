#!/usr/bin/env python3
import json, os, time

STATE_FILE = "/tmp/waybar_cpu_state.json"

def get_cpu_times():
    try:
        with open("/proc/stat", "r") as f:
            line = f.readline()
        fields = [float(x) for x in line.split()[1:]]
        idle = fields[3] + fields[4]
        total = sum(fields)
        return idle, total
    except Exception:
        return 0, 0

def get_cpu_temp():
    try:
        with open("/sys/class/hwmon/hwmon4/temp1_input", "r") as f:
            t = int(f.read().strip()) // 1000
            return t
    except Exception:
        pass
    return 0

def main():
    now = time.time()
    idle, total = get_cpu_times()
    
    usage = 0
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                prev = json.load(f)
            d_idle = idle - prev.get("idle", idle)
            d_total = total - prev.get("total", total)
            if d_total > 0:
                usage = int(round(100.0 * (1.0 - d_idle / d_total)))
        except Exception:
            pass
            
    with open(STATE_FILE, "w") as f:
        json.dump({"time": now, "idle": idle, "total": total}, f)
        
    text = f"󰍛 {usage}%"
    
    tooltip = [
        "<b>Процессор: AMD Ryzen 5 3500U</b>",
        "───────────────────────────",
        f"<b>Загрузка CPU:</b> {usage}%"
    ]
    
    print(json.dumps({
        "text": text,
        "tooltip": "\n".join(tooltip),
        "class": "cpu-high" if usage > 80 else "cpu-normal"
    }))

if __name__ == "__main__":
    main()
