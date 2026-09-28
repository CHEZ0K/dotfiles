#!/usr/bin/env python3
import json, subprocess

def get_player_info():
    try:
        status_res = subprocess.run(["playerctl", "status"], capture_output=True, text=True, timeout=0.5)
        status = status_res.stdout.strip()
        if not status or status not in ["Playing", "Paused"]:
            return None
            
        title_res = subprocess.run(["playerctl", "metadata", "title"], capture_output=True, text=True, timeout=0.5)
        artist_res = subprocess.run(["playerctl", "metadata", "artist"], capture_output=True, text=True, timeout=0.5)
        title = title_res.stdout.strip() or "Без названия"
        artist = artist_res.stdout.strip() or "Исполнитель"
        
        return {
            "status": status,
            "title": title,
            "artist": artist
        }
    except Exception:
        return None

def main():
    info = get_player_info()
    if not info:
        print(json.dumps({"text": "", "alt": "stopped", "tooltip": "", "class": "hidden"}))
        return

    title = info["title"]
    if len(title) > 18:
        title = title[:16] + "…"
        
    text = f"󰎆 {title}"
    status_class = "media-playing" if info["status"] == "Playing" else "media-paused"
    
    tooltip = [f"<b>Трек:</b> {info['title']}"]
    if info.get("artist") and info["artist"] != "Исполнитель":
        tooltip.append(f"<b>Исполнитель:</b> {info['artist']}")
    
    print(json.dumps({
        "text": text,
        "tooltip": "\n".join(tooltip),
        "class": f"{status_class} pill-highlighted",
        "alt": info["status"]
    }))

if __name__ == "__main__":
    main()
