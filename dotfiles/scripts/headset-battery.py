#!/usr/bin/env python3
import subprocess
import re
import os
import sys

def get_battery():
    # 1. Check bluetoothctl for connected devices
    try:
        proc = subprocess.run(['bluetoothctl', 'devices', 'Connected'], capture_output=True, text=True, timeout=1.2)
        if proc.returncode == 0 and proc.stdout.strip():
            for line in proc.stdout.strip().splitlines():
                parts = line.split()
                if len(parts) >= 2 and parts[0] == 'Device':
                    mac = parts[1]
                    info_proc = subprocess.run(['bluetoothctl', 'info', mac], capture_output=True, text=True, timeout=1.2)
                    if info_proc.returncode == 0:
                        m = re.search(r'Battery Percentage:\s*(?:0x[0-9a-fA-F]+\s*)?\(?(\d+)\)?', info_proc.stdout)
                        if m:
                            return int(m.group(1))
    except Exception:
        pass

    # 2. Check UPower devices
    try:
        proc = subprocess.run(['upower', '-e'], capture_output=True, text=True, timeout=1.2)
        if proc.returncode == 0:
            for dev in proc.stdout.strip().splitlines():
                dev_lower = dev.lower()
                if any(k in dev_lower for k in ['headset', 'headphone', 'earphone', 'dev_']) and 'battery_bat' not in dev_lower:
                    dev_proc = subprocess.run(['upower', '-i', dev], capture_output=True, text=True, timeout=1.2)
                    if dev_proc.returncode == 0:
                        m = re.search(r'percentage:\s*(\d+)%', dev_proc.stdout)
                        if m:
                            return int(m.group(1))
    except Exception:
        pass

    # 3. Check /sys/class/power_supply
    try:
        if os.path.exists('/sys/class/power_supply'):
            for entry in os.listdir('/sys/class/power_supply'):
                if not entry.startswith('BAT') and not entry.startswith('ADP'):
                    cap_path = os.path.join('/sys/class/power_supply', entry, 'capacity')
                    if os.path.isfile(cap_path):
                        with open(cap_path) as f:
                            return int(f.read().strip())
    except Exception:
        pass

    return None

if __name__ == '__main__':
    batt = get_battery()
    if batt is not None:
        print(f"󰋋 {batt}%")
    else:
        sys.exit(0)
