#!/usr/bin/env bash
# Unified wallpaper selector for Hyprland – Serpantinum Coverflow UI, Images & Wallpaper Engine 3D/Video Scenes

set -u

export G_MESSAGES_DEBUG=none
export G_MESSAGES_PREFIXED=none

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/67}"
CACHE_ROOT="${CACHE_ROOT:-$HOME/.cache/hypr}"
PREVIEW_DIR="${PREVIEW_DIR:-$CACHE_ROOT/wallpaper_previews}"
VIDEO_CACHE_DIR="${VIDEO_CACHE_DIR:-$CACHE_ROOT/video_wallpapers}"
INDEX_FILE="${INDEX_FILE:-$HOME/.wallpaper_index}"
WPE_MAP_FILE="${WPE_MAP_FILE:-$CACHE_ROOT/wpe_map.txt}"
STEAM_WE_DIR="${STEAM_WE_DIR:-$HOME/.local/share/Steam/steamapps/common/wallpaper_engine}"
STEAM_ASSETS_DIR="$STEAM_WE_DIR/assets"
STEAM_WORKSHOP_DIR="${STEAM_WORKSHOP_DIR:-$HOME/.local/share/Steam/steamapps/workshop/content/431960}"

DISPLAY_NAME="${DISPLAY_NAME:-$(niri msg --json outputs 2>/dev/null | jq -r '.[0].name // empty' 2>/dev/null || echo 'eDP-1')}"
DISPLAY_NAME="${DISPLAY_NAME:-eDP-1}"
TARGET_RES="${TARGET_RES:-1920x1080}"
TARGET_FPS="${TARGET_FPS:-$(niri msg --json outputs 2>/dev/null | jq -r '.[0].refreshRate | floor // empty' 2>/dev/null || echo '60')}"
TARGET_FPS="${TARGET_FPS:-60}"
MAX_JOBS="${MAX_JOBS:-4}"
DONE_FLAG="$PREVIEW_DIR/.done"
PICKER_DIR="$HOME/.config/hypr/scripts/wallpaper-picker"
WAL_JSON="$HOME/.cache/wal/colors.json"
WAYBAR_CSS="$HOME/.cache/wal/colors-waybar.css"
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"

mkdir -p "$PREVIEW_DIR" "$VIDEO_CACHE_DIR" "$PREVIEW_DIR/colors_markers"

log() { printf '%s\n' "$*"; }
warn() { printf '⚠ %s\n' "$*" >&2; }
err() { printf '❌ %s\n' "$*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Missing required command: $1"; exit 1; }
}

get_file_list() {
  find "$WALLPAPER_DIR" -type f \( \
    -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o \
    -iname '*.webp' -o -iname '*.gif' -o \
    -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' \
  \) | sort
}

sync_wpe_projects() {
  local we_default="$STEAM_WE_DIR/projects/defaultprojects"
  local color_dir="$PREVIEW_DIR/colors_markers"
  local map_tmp
  map_tmp=$(mktemp)

  # Broken legacy projects to exclude
  local broken="arsenal demon_core fantasticcar neon_sunset ricepod dna_fragment sheep techno audiophile corsair_collection corsair_o_tron"

  # 1. Scan default projects
  if [[ -d "$we_default" ]]; then
    for p in "$we_default"/*; do
      [[ -d "$p" && -f "$p/project.json" ]] || continue
      local pname
      pname="$(basename "$p")"
      [[ " $broken " =~ " $pname " ]] && continue

      local prev_file=""
      for candidate in "$p/preview.jpg" "$p/preview.png" "$p/preview.gif"; do
        if [[ -f "$candidate" ]]; then prev_file="$candidate"; break; fi
      done
      [[ -n "$prev_file" ]] || continue

      local thumb_name="WPE_${pname}.jpg"
      local thumb_path="$PREVIEW_DIR/$thumb_name"
      printf '%s|%s|%s\n' "$thumb_name" "$p" "$prev_file" >> "$map_tmp"

      if [[ ! -f "$thumb_path" ]]; then
        if command -v magick >/dev/null 2>&1; then
          magick "${prev_file}[0]" -quiet -filter Lanczos -resize x720 -quality 95 "$thumb_path" || true
        fi
      fi

      if [[ -f "$thumb_path" ]]; then
        local marker_pattern="$color_dir/${thumb_name}_HEX_*"
        if ! compgen -G "$marker_pattern" >/dev/null; then
          local hex=""
          if command -v magick >/dev/null 2>&1; then
            hex="$(magick "$thumb_path" -modulate 100,200 -resize "1x1^" -gravity center -extent 1x1 -depth 8 -format "%[hex:p{0,0}]" info:- 2>/dev/null | grep -oE '[0-9A-Fa-f]{6}' | head -n 1)"
          fi
          [[ -n "$hex" ]] && touch "$color_dir/${thumb_name}_HEX_$hex" 2>/dev/null || true
        fi
      fi
    done
  fi

  # 2. Scan workshop projects
  if [[ -d "$STEAM_WORKSHOP_DIR" ]]; then
    for p in "$STEAM_WORKSHOP_DIR"/*; do
      [[ -d "$p" && -f "$p/project.json" ]] || continue
      local pname
      pname="$(basename "$p")"
      local prev_file=""
      for candidate in "$p/preview.jpg" "$p/preview.png" "$p/preview.gif"; do
        if [[ -f "$candidate" ]]; then prev_file="$candidate"; break; fi
      done
      [[ -n "$prev_file" ]] || continue

      local thumb_name="WPE_${pname}.jpg"
      local thumb_path="$PREVIEW_DIR/$thumb_name"
      printf '%s|%s|%s\n' "$thumb_name" "$p" "$prev_file" >> "$map_tmp"

      if [[ ! -f "$thumb_path" ]]; then
        if command -v magick >/dev/null 2>&1; then
          magick "${prev_file}[0]" -quiet -filter Lanczos -resize x720 -quality 95 "$thumb_path" || true
        fi
      fi

      if [[ -f "$thumb_path" ]]; then
        local marker_pattern="$color_dir/${thumb_name}_HEX_*"
        if ! compgen -G "$marker_pattern" >/dev/null; then
          local hex=""
          if command -v magick >/dev/null 2>&1; then
            hex="$(magick "$thumb_path" -modulate 100,200 -resize "1x1^" -gravity center -extent 1x1 -depth 8 -format "%[hex:p{0,0}]" info:- 2>/dev/null | grep -oE '[0-9A-Fa-f]{6}' | head -n 1)"
          fi
          [[ -n "$hex" ]] && touch "$color_dir/${thumb_name}_HEX_$hex" 2>/dev/null || true
        fi
      fi
    done
  fi

  mv "$map_tmp" "$WPE_MAP_FILE" 2>/dev/null || true
}

create_preview() {
  local file="$1"
  local base ext preview color_dir hex
  base="$(basename "$file")"
  ext="${base##*.}"
  color_dir="$PREVIEW_DIR/colors_markers"

  case "${ext,,}" in
    mp4|webm|mkv)
      preview="$PREVIEW_DIR/000_${base}"
      if [[ ! -f "$preview" || "$file" -nt "$preview" ]]; then
        ffmpeg -y -nostdin -loglevel error -ss 5 -i "$file" -frames:v 1 -q:v 1 \
          -vf 'scale=-1:720:flags=lanczos' "$preview" || return 1
      fi
      ;;
    jpg|jpeg|png|webp|gif)
      preview="$PREVIEW_DIR/${base}"
      if [[ ! -f "$preview" || "$file" -nt "$preview" ]]; then
        if command -v magick >/dev/null 2>&1; then
          magick "${file}[0]" -quiet -filter Lanczos -resize x720 -quality 95 "$preview" || return 1
        elif command -v convert >/dev/null 2>&1; then
          convert "${file}[0]" -quiet -filter Lanczos -resize x720 -quality 95 "$preview" || return 1
        fi
      fi
      ;;
    *) return 1 ;;
  esac

  if [[ -f "$preview" ]]; then
    local marker_pattern="$color_dir/${base}_HEX_*"
    if ! compgen -G "$marker_pattern" >/dev/null || [[ "$preview" -nt $(compgen -G "$marker_pattern" | head -n 1) ]]; then
      rm -f $color_dir/${base}_HEX_* 2>/dev/null || true
      if command -v magick >/dev/null 2>&1; then
        hex="$(magick "$preview" -modulate 100,200 -resize "1x1^" -gravity center -extent 1x1 -depth 8 -format "%[hex:p{0,0}]" info:- 2>/dev/null | grep -oE '[0-9A-Fa-f]{6}' | head -n 1)"
      elif command -v convert >/dev/null 2>&1; then
        hex="$(convert "$preview" -modulate 100,200 -resize "1x1^" -gravity center -extent 1x1 -depth 8 -format "%[hex:p{0,0}]" info:- 2>/dev/null | grep -oE '[0-9A-Fa-f]{6}' | head -n 1)"
      fi
      if [[ -n "$hex" ]]; then
        touch "$color_dir/${base}_HEX_$hex" 2>/dev/null || true
      fi
    fi
  fi
}

generate_previews() {
  sync_wpe_projects
  mapfile -t files < <(get_file_list)

  local to_generate=()
  for f in "${files[@]}"; do
    local base="$(basename "$f")"
    local ext="${base##*.}"
    local prev
    case "${ext,,}" in
      mp4|webm|mkv) prev="$PREVIEW_DIR/000_${base}" ;;
      *)            prev="$PREVIEW_DIR/${base}" ;;
    esac
    if [[ ! -f "$prev" || "$f" -nt "$prev" ]]; then
      to_generate+=("$f")
    fi
  done

  if (( ${#to_generate[@]} > 0 )); then
    log "▶ Generating previews & color markers (${#to_generate[@]} new/updated)..."
    local running=0
    for f in "${to_generate[@]}"; do
      create_preview "$f" &
      ((running+=1))
      if (( running >= MAX_JOBS )); then
        wait -n || true
        ((running-=1))
      fi
    done
    wait || true
  fi

  touch "$DONE_FLAG"
  log "✓ Preview cache ready"
}

stop_video_wallpapers() {
  pkill -9 -f 'linux-wallpaperengine' 2>/dev/null || true
  pkill -9 -f 'mpvpaper' 2>/dev/null || true
  sleep 0.2
}

ensure_awww_daemon() {
  local sock="/run/user/${UID:-1000}/${WAYLAND_DISPLAY:-wayland-1}-awww-daemon.sock"
  if [[ ! -S "$sock" ]] || ! pgrep -f 'awww-daemon' >/dev/null 2>&1; then
    pkill -9 -f 'awww-daemon' 2>/dev/null || true
    rm -f "$sock" 2>/dev/null || true
    nohup awww-daemon >/dev/null 2>&1 &
    local i=0
    while [[ ! -S "$sock" && $i -lt 20 ]]; do
      sleep 0.05
      ((i++))
    done
  fi
}

ensure_dbus() {
  if ! dbus-send --session --dest=org.freedesktop.DBus --type=method_call --print-reply /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1; then
    dbus-daemon --session --fork --address="unix:path=/run/user/${UID:-1000}/bus" 2>/dev/null || true
  fi
}

set_image_wallpaper() {
  local image="$1"
  stop_video_wallpapers

  local ext="${image##*.}"
  if [[ "${ext,,}" == "gif" ]]; then
    pkill -x swaybg 2>/dev/null || true
    require_cmd awww
    ensure_awww_daemon
    awww img "$image" --transition-type fade --transition-duration 0.4 --transition-fps "$TARGET_FPS"
    log "✓ Animated GIF wallpaper applied: $(basename "$image")"
  else
    # Static image: Kill animated daemon immediately!
    pkill -9 -f 'awww-daemon' 2>/dev/null || true
    rm -f "/run/user/${UID:-1000}/${WAYLAND_DISPLAY:-wayland-1}-awww-daemon.sock" 2>/dev/null || true
    pkill -x swaybg 2>/dev/null || true
    "$HOME/.local/bin/swaybg" -i "$image" -m fill >/dev/null 2>&1 &
    log "✓ Static wallpaper applied via swaybg (daemon killed): $(basename "$image")"
  fi
}

set_wpe_wallpaper() {
  local proj_dir="$1"
  local preview_img="$2"

  if ! command -v linux-wallpaperengine >/dev/null 2>&1; then
    err "linux-wallpaperengine is not installed."
    set_image_wallpaper "$preview_img"
    return 0
  fi

  ensure_dbus
  stop_video_wallpapers
  setsid linux-wallpaperengine \
    --screen-root "$DISPLAY_NAME" \
    --layer background \
    --fps "$TARGET_FPS" \
    --scaling fill \
    --disable-parallax \
    --assets-dir "$STEAM_ASSETS_DIR" \
    "$proj_dir" >/dev/null 2>&1 &
  sleep 0.5
  log "✓ Wallpaper Engine Scene applied: $(basename "$proj_dir")"
}

update_niri_colors() {
  [[ -f "$WAL_JSON" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  local niri_conf="$HOME/.config/niri/config.kdl"
  [[ -f "$niri_conf" ]] || return 0

  local bg c1 c2
  bg="$(jq -r '.special.background // empty' "$WAL_JSON")"
  c1="$(jq -r '.colors.color2 // empty' "$WAL_JSON")"
  c2="$(jq -r '.colors.color4 // empty' "$WAL_JSON")"

  if [[ -n "$bg" ]]; then
    sed -i -E "s/backdrop-color \"#[0-9a-fA-F]+\"/backdrop-color \"$bg\"/" "$niri_conf"
  fi
  if [[ -n "$c1" && -n "$c2" ]]; then
    sed -i -E "s/active-gradient from=\"#[0-9a-fA-F]+\" to=\"#[0-9a-fA-F]+\"/active-gradient from=\"${c1}ee\" to=\"${c2}ee\"/" "$niri_conf"
  fi

  command -v niri >/dev/null 2>&1 && niri msg action load-config-file >/dev/null 2>&1 || true
}

generate_waybar_css() {
  [[ -f "$WAL_JSON" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  jq -r '
  .colors | {
    background: .color0,
    foreground: .color7,
    color1: .color1,
    color2: .color2,
    color3: .color3,
    color4: .color4,
    color5: .color5,
    color6: .color6,
    color7: .color7
  } | to_entries[] | "@define-color \(.key) \(.value);"
  ' "$WAL_JSON" > "$WAYBAR_CSS"
}

apply_pywal_and_refresh() {
  local file="$1"
  if command -v wal >/dev/null 2>&1 && [[ -f "$file" ]]; then
    wal -i "$file" -t -n -q || warn "wal failed"
    update_niri_colors
    generate_waybar_css

    # Live-reload colors in open terminals (Foot, etc.) via OSC sequences
    if [[ -f "$HOME/.cache/wal/sequences" ]]; then
      for term in /dev/pts/[0-9]*; do
        [[ -w "$term" ]] && cat "$HOME/.cache/wal/sequences" > "$term" 2>/dev/null || true
      done
    fi

    if command -v matugen >/dev/null 2>&1; then
      matugen -t scheme-content --source-color-index 0 -m dark image "$file" >/dev/null 2>&1 || matugen --source-color-index 0 image "$file" >/dev/null 2>&1
    fi

    if [[ -f "$HOME/.config/illogical-impulse/config.json" ]] && command -v jq >/dev/null 2>&1; then
      jq --arg path "$file" '.background.wallpaperPath = $path' "$HOME/.config/illogical-impulse/config.json" > "$HOME/.config/illogical-impulse/config.json.tmp" && mv "$HOME/.config/illogical-impulse/config.json.tmp" "$HOME/.config/illogical-impulse/config.json"
    fi

    if pgrep waybar >/dev/null 2>&1; then
      pkill waybar || true
      nohup waybar >/dev/null 2>&1 &
    fi

    if pgrep kitty >/dev/null 2>&1; then
      killall -SIGUSR1 kitty 2>/dev/null || true
    fi
  fi
}

choose_wallpaper() {
  local sel_file="/tmp/qs_selected_wallpaper"
  rm -f "$sel_file"

  export WALLPAPER_DIR
  export PREVIEW_DIR
  export QS_CACHE_WALLPAPER_PICKER="$CACHE_ROOT/wallpaper_picker"

  if ! command -v quickshell >/dev/null 2>&1; then
    err "quickshell is required for the preview UI. Please install with: sudo pacman -S quickshell"
    return 1
  fi

  # Launch Serpantinum Quickshell wallpaper picker
  quickshell -p "$PICKER_DIR/Shell.qml" >/dev/null 2>&1 || true

  # Wait up to 0.5s for file flush if needed
  local i=0
  while [[ ! -s "$sel_file" && $i -lt 10 ]]; do
    sleep 0.05
    ((i++))
  done

  if [[ ! -f "$sel_file" ]]; then
    return 2 # Cancelled by user (Esc or backdrop click)
  fi

  local selected
  selected="$(head -n 1 "$sel_file" 2>/dev/null | tr -d '\r\n')"
  rm -f "$sel_file"

  if [[ -n "$selected" ]]; then
    printf '%s\n' "$selected"
    return 0
  fi

  err "No wallpaper selected"
  return 1
}

main() {
  require_cmd ffmpeg

  generate_previews

  local selected
  selected="$(choose_wallpaper)" || {
    code=$?
    [[ $code -eq 2 ]] && exit 0
    exit "$code"
  }

  if [[ "$selected" =~ ^WPE:(.*) ]] || [[ "$(basename "$selected")" =~ ^WPE_(.*)\.jpg ]]; then
    local wpe_thumb
    if [[ "$selected" =~ ^WPE:(.*) ]]; then
      wpe_thumb="${BASH_REMATCH[1]}"
    else
      wpe_thumb="$(basename "$selected")"
    fi
    local proj_dir=""
    local prev_img=""

    if [[ -f "$WPE_MAP_FILE" ]]; then
      local map_line
      map_line="$(grep -F "$wpe_thumb|" "$WPE_MAP_FILE" | head -n 1)"
      if [[ -n "$map_line" ]]; then
        IFS='|' read -r _thumb proj_dir prev_img <<< "$map_line"
      fi
    fi

    if [[ -n "$proj_dir" && -d "$proj_dir" ]]; then
      set_wpe_wallpaper "$proj_dir" "$prev_img"
      apply_pywal_and_refresh "$prev_img"
      log "🎉 Done: $(basename "$proj_dir")"
      exit 0
    fi
  fi

  [[ -f "$selected" ]] || { err "Selected file missing: $selected"; exit 1; }

  local file_ext="${selected##*.}"
  case "${file_ext,,}" in
    mp4|webm|mkv)
      set_wpe_wallpaper "$selected" "$PREVIEW_DIR/000_$(basename "$selected")"
      apply_pywal_and_refresh "$PREVIEW_DIR/000_$(basename "$selected")"
      ;;
    jpg|jpeg|png|webp|gif)
      set_image_wallpaper "$selected"
      apply_pywal_and_refresh "$selected"
      ;;
    *)
      err "Unsupported type: $file_ext"
      exit 1
      ;;
  esac

  log "🎉 Done: $(basename "$selected")"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
