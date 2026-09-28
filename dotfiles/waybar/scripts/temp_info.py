#!/usr/bin/env python3
import json

def get_cpu_temp():
    try:
        with open("/sys/class/hwmon/hwmon4/temp1_input", "r") as f:
            return int(f.read().strip()) // 1000
    except Exception:
        pass
    try:
        # Fallback to any k10temp or coretemp
        import glob
        for p in glob.glob("/sys/class/hwmon/hwmon*/temp1_input"):
            with open(p, "r") as f:
                return int(f.read().strip()) // 1000
    except Exception:
        pass
    return 0

def main():
    temp = get_cpu_temp()
    text = f"{temp}°C" if temp > 0 else "Н/Д"
    print(json.dumps({
        "text": text,
        "tooltip": f"Температура CPU: {temp}°C" if temp > 0 else "Температура: Н/Д",
        "class": "temp-high" if temp > 80 else "temp-normal"
    }))

if __name__ == "__main__":
    main()
