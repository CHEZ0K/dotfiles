#!/usr/bin/env python3
import json
import os
import subprocess
import sys

APP_CLASS = "cavaunderbar"
STATE_FILE = "/tmp/cava_underbar_status"
HIDDEN_FILE = "/tmp/cava_underbar_hidden_by_fs"
LOCK_FILE = "/tmp/cava_underbar.lock"

def main():
    if not os.environ.get("NIRI_SOCKET") and "niri" not in os.environ.get("XDG_CURRENT_DESKTOP", "").lower():
        return

    import fcntl
    try:
        lock_fd = open(LOCK_FILE, "w")
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except Exception:
        sys.exit(0)

    ws_map = {}
    current_active_ws_id = None
    cava_id = None
    cava_ws_id = None
    is_fullscreen = False

    def move_cava(win_id, target_idx):
        subprocess.run(
            ["niri", "msg", "action", "move-window-to-workspace", "--window-id", str(win_id), "--focus", "false", str(target_idx)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )

    def refresh_ws():
        nonlocal ws_map, current_active_ws_id
        try:
            res = subprocess.run(["niri", "msg", "--json", "workspaces"], capture_output=True, text=True)
            if res.returncode == 0 and res.stdout.strip():
                wss = json.loads(res.stdout)
                ws_map = {w["id"]: w["idx"] for w in wss}
                active = next((w for w in wss if w.get("is_active")), None)
                if active:
                    current_active_ws_id = active["id"]
        except Exception:
            pass

    def refresh_cava():
        nonlocal cava_id, cava_ws_id
        try:
            res = subprocess.run(["niri", "msg", "--json", "windows"], capture_output=True, text=True)
            if res.returncode == 0 and res.stdout.strip():
                wins = json.loads(res.stdout)
                cava = next((w for w in wins if w.get("app_id") == APP_CLASS), None)
                if cava:
                    cava_id = cava["id"]
                    cava_ws_id = cava.get("workspace_id")
                else:
                    cava_id = None
                    cava_ws_id = None
        except Exception:
            pass

    def check_fs():
        nonlocal is_fullscreen
        try:
            res = subprocess.run(["niri", "msg", "--json", "focused-window"], capture_output=True, text=True)
            if res.returncode == 0 and res.stdout.strip():
                fw = json.loads(res.stdout)
                fs = fw.get("is_fullscreen", False)
                if fs != is_fullscreen:
                    is_fullscreen = fs
                    want_on = "1"
                    if os.path.exists(STATE_FILE):
                        with open(STATE_FILE) as f:
                            want_on = f.read().strip()
                    if want_on == "1":
                        if is_fullscreen:
                            subprocess.run(["/home/chezok/.local/bin/cava_manager.sh", "stop"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                            with open(HIDDEN_FILE, "w") as f:
                                f.write("1")
                        else:
                            hidden = "0"
                            if os.path.exists(HIDDEN_FILE):
                                with open(HIDDEN_FILE) as f:
                                    hidden = f.read().strip()
                            if hidden == "1":
                                subprocess.run(["/home/chezok/.local/bin/cava_manager.sh", "start"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                                with open(HIDDEN_FILE, "w") as f:
                                    f.write("0")
        except Exception:
            pass

    # Initial state discovery
    refresh_ws()
    refresh_cava()
    if cava_id is not None and current_active_ws_id is not None and cava_ws_id != current_active_ws_id:
        target_idx = ws_map.get(current_active_ws_id)
        if target_idx is not None:
            cava_ws_id = current_active_ws_id
            move_cava(cava_id, target_idx)

    proc = subprocess.Popen(["niri", "msg", "--json", "event-stream"], stdout=subprocess.PIPE, text=True, bufsize=1)

    while True:
        line = proc.stdout.readline()
        if not line:
            break
        try:
            data = json.loads(line)

            if "WorkspaceActivated" in data:
                ws_info = data["WorkspaceActivated"]
                target_ws_id = ws_info.get("id")
                current_active_ws_id = target_ws_id
                target_idx = ws_map.get(target_ws_id)
                if target_idx is None:
                    refresh_ws()
                    target_idx = ws_map.get(target_ws_id)

                refresh_cava()

                if cava_id is not None and target_idx is not None and cava_ws_id != target_ws_id:
                    cava_ws_id = target_ws_id
                    move_cava(cava_id, target_idx)

            elif "WorkspacesChanged" in data:
                workspaces = data["WorkspacesChanged"].get("workspaces", [])
                ws_map = {w["id"]: w["idx"] for w in workspaces}
                active = next((w for w in workspaces if w.get("is_active")), None)
                if active:
                    current_active_ws_id = active["id"]
                    if cava_id is not None and cava_ws_id != current_active_ws_id:
                        cava_ws_id = current_active_ws_id
                        move_cava(cava_id, active["idx"])

            elif "WindowsChanged" in data:
                windows = data["WindowsChanged"].get("windows", [])
                cava = next((w for w in windows if w.get("app_id") == APP_CLASS), None)
                if cava:
                    cava_id = cava["id"]
                    cava_ws_id = cava.get("workspace_id")
                    if current_active_ws_id is not None and cava_ws_id != current_active_ws_id:
                        target_idx = ws_map.get(current_active_ws_id)
                        if target_idx is not None:
                            cava_ws_id = current_active_ws_id
                            move_cava(cava_id, target_idx)
                else:
                    cava_id = None
                    cava_ws_id = None

                check_fs()

            elif "WindowOpenedOrChanged" in data or "WindowFocusChanged" in data:
                check_fs()

        except Exception:
            pass

if __name__ == "__main__":
    main()
