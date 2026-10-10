#!/usr/bin/env bash
set -u

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

report_check() {
    local check_id="$1"
    local status="$2"
    local details="$3"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [[ "$status" == "PASS" ]]; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        echo "[ACCEPTANCE_CHECK] id=${check_id} status=PASS details=\"${details}\""
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        echo "[ACCEPTANCE_CHECK] id=${check_id} status=FAIL details=\"${details}\""
    fi
}

# -----------------------------------------------------------------------------
# Check 15: Vibepanel Package or Binary Installed (R1)
# -----------------------------------------------------------------------------
if vibe_info=$(pacman -Q vibepanel-bin 2>/dev/null || pacman -Q vibepanel-git 2>/dev/null || pacman -Q vibepanel 2>/dev/null || which vibepanel 2>/dev/null); then
    report_check "PKG_VIBEPANEL" "PASS" "Found vibepanel: ${vibe_info}"
else
    report_check "PKG_VIBEPANEL" "FAIL" "vibepanel is missing (neither vibepanel-bin, vibepanel-git nor executable found)"
fi

# -----------------------------------------------------------------------------
# Check 16: Zen Browser Package or Binary Installed (R1)
# -----------------------------------------------------------------------------
if zen_info=$(pacman -Q zen-browser-bin 2>/dev/null || pacman -Q zen-browser 2>/dev/null || which zen-browser 2>/dev/null); then
    report_check "PKG_ZEN_BROWSER" "PASS" "Found Zen Browser: ${zen_info}"
else
    report_check "PKG_ZEN_BROWSER" "FAIL" "zen-browser-bin is missing"
fi

# -----------------------------------------------------------------------------
# Check 17: Fastfetch Package or Binary Installed (R1 CLI stack)
# -----------------------------------------------------------------------------
if ff_info=$(pacman -Q fastfetch 2>/dev/null || which fastfetch 2>/dev/null); then
    report_check "PKG_FASTFETCH" "PASS" "Found fastfetch: ${ff_info}"
else
    report_check "PKG_FASTFETCH" "FAIL" "fastfetch is missing"
fi

# -----------------------------------------------------------------------------
# Check 18: Btop Package or Binary Installed (R1 CLI stack)
# -----------------------------------------------------------------------------
if btop_info=$(pacman -Q btop 2>/dev/null || which btop 2>/dev/null); then
    report_check "PKG_BTOP" "PASS" "Found btop: ${btop_info}"
else
    report_check "PKG_BTOP" "FAIL" "btop is missing"
fi

# -----------------------------------------------------------------------------
# Check 19: AyuGram Desktop Package or Binary Installed (R1)
# -----------------------------------------------------------------------------
if ayu_info=$(pacman -Q ayugram-desktop 2>/dev/null || pacman -Q ayugram-desktop-bin 2>/dev/null || which ayugram-desktop 2>/dev/null); then
    report_check "PKG_AYUGRAM_DESKTOP" "PASS" "Found AyuGram Desktop: ${ayu_info}"
else
    report_check "PKG_AYUGRAM_DESKTOP" "FAIL" "ayugram-desktop is missing"
fi

# -----------------------------------------------------------------------------
# Check 20: Wayland Compositors & Bar Packages (R1: niri, hyprland, waybar)
# -----------------------------------------------------------------------------
desktop_missing=()
for dpkg in "niri" "hyprland" "waybar"; do
    if ! pacman -Q "$dpkg" &>/dev/null && ! which "$dpkg" &>/dev/null; then
        desktop_missing+=("$dpkg")
    fi
done

if [[ ${#desktop_missing[@]} -eq 0 ]]; then
    report_check "PKG_WAYLAND_STACK" "PASS" "Wayland stack installed: niri, hyprland, waybar"
else
    report_check "PKG_WAYLAND_STACK" "FAIL" "Missing Wayland packages: ${desktop_missing[*]}"
fi

echo "Total: $TOTAL_CHECKS, Passed: $PASSED_CHECKS, Failed: $FAILED_CHECKS"
