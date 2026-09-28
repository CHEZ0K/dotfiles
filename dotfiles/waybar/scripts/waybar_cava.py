#!/usr/bin/env python3
import json
import os
import signal
import subprocess
import sys

CAVA_CONFIG = os.path.expanduser("~/.config/cava/config_waybar")
RAMP = [" ", "▂", "▃", "▄", "▅", "▆", "▇", "█"]

def main():
    sys.stdout.reconfigure(line_buffering=True)
    
    if not os.path.exists(CAVA_CONFIG):
        print(json.dumps({"text": "", "class": "cava-hidden"}))
        return

    print(json.dumps({"text": "", "class": "cava-silent"}))

    cava_proc = subprocess.Popen(
        ["cava", "-p", CAVA_CONFIG],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        bufsize=1
    )

    def cleanup(signum=None, frame=None):
        try:
            cava_proc.terminate()
            cava_proc.wait(timeout=0.5)
        except Exception:
            cava_proc.kill()
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    silent_count = 0
    was_active = False

    try:
        while True:
            line = cava_proc.stdout.readline()
            if not line:
                break
            
            parts = [int(x) for x in line.strip(";\n").split(";") if x.isdigit()]
            if not parts:
                continue

            is_active = any(p > 0 for p in parts)
            
            if is_active:
                silent_count = 0
                was_active = True
                bars = "".join(RAMP[min(p, len(RAMP) - 1)] for p in parts)
                out = {
                    "text": bars,
                    "tooltip": "CAVA Audio Visualizer",
                    "class": "cava-active"
                }
                print(json.dumps(out, ensure_ascii=False))
            else:
                silent_count += 1
                if silent_count > 40:
                    if was_active:
                        print(json.dumps({"text": "", "class": "cava-silent"}))
                        was_active = False
                elif was_active:
                    bars = "".join(RAMP[0] for _ in parts)
                    print(json.dumps({"text": bars, "class": "cava-silent"}))
    finally:
        cleanup()

if __name__ == "__main__":
    main()
