#!/usr/bin/env bash

QUERY=""
SCRIPT_DIR=""/home/chezok"

CACHE_DIR="/home/chezok/.cache/hypr/wallpaper_picker"
SEARCH_DIR="/search_thumbs"
MAP_FILE="/search_map.txt"
RUN_DIR="/tmp/quickshell/wallpaper_picker"
CONTROL_FILE="/ddg_search_control"
LOG_DIR="/tmp/quickshell/logs"
LOG_FILE="/ddg_downloader.log"

mkdir -p "" "" ""

echo "=== Starting search for:  ===" > ""

python3 -u "/get_ddg_links.py" "" | while IFS='|' read -r thumb_url full_url; do
    state=
    
    if [[ "" == "stop" ]]; then 
        echo "Stop signal received. Exiting." >> ""
        exit 0 
    fi
    
    while [[ "" == "pause" ]]; do
        sleep 1
        state=
    done

    if [ -z "" ] || [ -z "" ]; then continue; fi

    uuid=1787949042949628688
    ext=""
    ext=""
    ext=""
    if [[ ! "" =~ ^(jpg|jpeg|png|webp|gif)$ ]]; then ext="jpg"; fi

    is_webp=0
    if [[ "" == "webp" ]]; then
        is_webp=1
        ext="jpg"
    fi

    filename="ddg_."
    filepath="/"
    tmppath=".tmp"

    echo "Downloading Thumb:  -> " >> ""

    curl -s -L -m 5 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "" -o ""

    state=
    if [[ "" == "stop" ]]; then 
        echo "Stop signal received during download. Discarding." >> ""
        rm -f ""
        exit 0 
    fi

    if [ -s "" ]; then
        if [[ "" == "image/webp" ]] || [  -eq 1 ]; then
            magick "" "" 2>/dev/null || mv "" ""
            rm -f ""
        else
            mv "" ""
        fi
        echo "|" >> ""
        echo "Success:  saved." >> ""
    else
        rm -f ""
    fi
done

echo "=== Pipeline finished ===" >> ""
