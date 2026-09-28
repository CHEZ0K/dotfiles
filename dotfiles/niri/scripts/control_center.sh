#!/usr/bin/env bash
# Toggle Custom C++ Sidebar (157KB binary, GTK4 Layer-Shell)

if ! pgrep -x custom-sidebar >/dev/null 2>&1; then
    /home/chezok/.local/bin/custom-sidebar >/dev/null 2>&1 &
    exit 0
fi

/home/chezok/.local/bin/custom-sidebar >/dev/null 2>&1 &
