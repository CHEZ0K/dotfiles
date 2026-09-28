#!/usr/bin/env python3
import json

def main():
    info = {}
    try:
        with open("/proc/meminfo", "r") as f:
            for line in f:
                parts = line.split(":")
                if len(parts) == 2:
                    info[parts[0].strip()] = int(parts[1].split()[0])
    except Exception:
        pass

    total = info.get("MemTotal", 0) / (1024 * 1024)
    avail = info.get("MemAvailable", 0) / (1024 * 1024)
    used = total - avail
    pct = int(round((used / total) * 100)) if total > 0 else 0

    sw_total = info.get("SwapTotal", 0) / (1024 * 1024)
    sw_free = info.get("SwapFree", 0) / (1024 * 1024)
    sw_used = sw_total - sw_free
    sw_pct = int(round((sw_used / sw_total) * 100)) if sw_total > 0 else 0

    text = f"{used:.1f}/{total:.1f} ГБ"
    tooltip = [
        "<b>Оперативная память (RAM)</b>",
        "───────────────────────────",
        f"<b>Занято:</b> {used:.2f} ГБ из {total:.2f} ГБ ({pct}%)",
        f"<b>Доступно:</b> {avail:.2f} ГБ"
    ]
    if sw_total > 0:
        tooltip.extend([
            "───────────────────────────",
            f"<b>Своп (Swap):</b> {sw_used:.2f} ГБ из {sw_total:.2f} ГБ ({sw_pct}%)"
        ])
    tooltip.extend([
        "───────────────────────────",
        "<i>Клик: диспетчер задач (btop)</i>"
    ])

    print(json.dumps({
        "text": text,
        "tooltip": "\n".join(tooltip),
        "class": "ram-high" if pct >= 85 else "ram-normal"
    }, ensure_ascii=False))

if __name__ == "__main__":
    main()
