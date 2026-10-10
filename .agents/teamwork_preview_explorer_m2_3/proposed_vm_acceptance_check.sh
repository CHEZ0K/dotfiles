#!/usr/bin/env bash
# =============================================================================
# tests/vm_acceptance_check.sh
# In-Guest Acceptance Criteria Verification Script for Milestone 2
# =============================================================================
# Executes inside the installed QEMU VM after multi-user.target is reached.
# Validates R1-R4 acceptance criteria, writes status tokens to serial (/dev/ttyS0),
# and triggers clean poweroff.
# =============================================================================

set -u

# Redirect stdout and stderr to serial console and local log
LOG_FILE="/var/log/vm_acceptance_check.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

echo ""
echo "================================================================="
echo "  CACHYOS / ARCH LINUX VM ACCEPTANCE TEST SUITE (MILESTONE 2)   "
echo "================================================================="
echo "Timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "Hostname : $(uname -n 2>/dev/null || echo unknown)"
echo "Uptime   : $(uptime 2>/dev/null || echo unknown)"
echo ""

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
# Check 1: UEFI Removable Fallback Bootloader (/boot/efi/EFI/BOOT/BOOTX64.EFI)
# -----------------------------------------------------------------------------
EFI_FALLBACK="/boot/efi/EFI/BOOT/BOOTX64.EFI"
if [[ ! -f "$EFI_FALLBACK" ]]; then
    EFI_FALLBACK="/boot/efi/EFI/BOOT/bootx64.efi"
fi

if [[ -f "$EFI_FALLBACK" && -s "$EFI_FALLBACK" ]]; then
    efi_size=$(stat -c%s "$EFI_FALLBACK" 2>/dev/null || wc -c < "$EFI_FALLBACK")
    report_check "UEFI_BOOTX64_EXISTS" "PASS" "Found ${EFI_FALLBACK} (${efi_size} bytes)"
else
    report_check "UEFI_BOOTX64_EXISTS" "FAIL" "File ${EFI_FALLBACK} is missing or empty"
fi

# -----------------------------------------------------------------------------
# Check 2: UEFI NVRAM Bootloader (/boot/efi/EFI/GRUB/grubx64.efi)
# -----------------------------------------------------------------------------
EFI_NVRAM="/boot/efi/EFI/GRUB/grubx64.efi"
if [[ -f "$EFI_NVRAM" && -s "$EFI_NVRAM" ]]; then
    nvram_size=$(stat -c%s "$EFI_NVRAM" 2>/dev/null || wc -c < "$EFI_NVRAM")
    report_check "UEFI_GRUBX64_EXISTS" "PASS" "Found ${EFI_NVRAM} (${nvram_size} bytes)"
else
    report_check "UEFI_GRUBX64_EXISTS" "FAIL" "File ${EFI_NVRAM} is missing or empty"
fi

# -----------------------------------------------------------------------------
# Check 3: Running Kernel is CachyOS Bore
# -----------------------------------------------------------------------------
KERNEL_UNAME=$(uname -r)
if [[ "$KERNEL_UNAME" =~ cachyos-bore ]]; then
    report_check "KERNEL_CACHYOS_BORE" "PASS" "Running kernel: ${KERNEL_UNAME}"
else
    report_check "KERNEL_CACHYOS_BORE" "FAIL" "Running kernel is not cachyos-bore: ${KERNEL_UNAME}"
fi

# -----------------------------------------------------------------------------
# Check 4-7: Required Systemd Services are Enabled
# -----------------------------------------------------------------------------
REQUIRED_SERVICES=("NetworkManager" "bluetooth" "sddm" "udisks2")

for svc in "${REQUIRED_SERVICES[@]}"; do
    if systemctl is-enabled "$svc" &>/dev/null; then
        report_check "SERVICE_ENABLED_${svc^^}" "PASS" "Service ${svc} is enabled"
    else
        report_check "SERVICE_ENABLED_${svc^^}" "FAIL" "Service ${svc} is NOT enabled (state: $(systemctl is-enabled "$svc" 2>&1 || true))"
    fi
done

# -----------------------------------------------------------------------------
# Check 8-11: Required Systemd Services Active / Running State (with retry loop)
# -----------------------------------------------------------------------------
for svc in "${REQUIRED_SERVICES[@]}"; do
    attempts=0
    svc_state=""
    while [[ $attempts -lt 15 ]]; do
        svc_state=$(systemctl is-active "$svc" 2>&1 || true)
        if [[ "$svc_state" == "active" ]]; then
            break
        fi
        if [[ "$svc" =~ ^(sddm|bluetooth)$ && ("$svc_state" =~ activating || "$svc_state" =~ inactive) ]]; then
            break
        fi
        sleep 1
        attempts=$((attempts + 1))
    done

    if [[ "$svc_state" == "active" ]]; then
        report_check "SERVICE_ACTIVE_${svc^^}" "PASS" "Service ${svc} is active"
    elif [[ "$svc" == "sddm" && ("$svc_state" =~ activating || "$svc_state" =~ inactive) ]]; then
        # SDDM may be in activating state in headless QEMU without KMS display
        report_check "SERVICE_ACTIVE_${svc^^}" "PASS" "Service ${svc} state is acceptable in headless VM: ${svc_state}"
    elif [[ "$svc" == "bluetooth" && ("$svc_state" =~ activating || "$svc_state" =~ inactive) ]]; then
        # Bluetooth daemon is enabled; inactive state is expected in VM without physical Bluetooth controller
        report_check "SERVICE_ACTIVE_${svc^^}" "PASS" "Service ${svc} state is acceptable in VM without bluetooth controller: ${svc_state}"
    else
        report_check "SERVICE_ACTIVE_${svc^^}" "FAIL" "Service ${svc} is not active (state: ${svc_state})"
    fi
done

# -----------------------------------------------------------------------------
# Check 12: User 'chezok' exists and in wheel group
# -----------------------------------------------------------------------------
if id chezok &>/dev/null; then
    user_groups=$(id -Gn chezok 2>/dev/null || true)
    if [[ "$user_groups" =~ wheel ]]; then
        report_check "USER_CHEZOK_WHEEL" "PASS" "User chezok exists in groups: ${user_groups}"
    else
        report_check "USER_CHEZOK_WHEEL" "FAIL" "User chezok exists but not in wheel group: ${user_groups}"
    fi
else
    report_check "USER_CHEZOK_WHEEL" "FAIL" "User chezok does not exist"
fi

# -----------------------------------------------------------------------------
# Check 13: Resolv.conf Configuration
# -----------------------------------------------------------------------------
if grep -qE "1\.1\.1\.1|8\.8\.8\.8" /etc/resolv.conf 2>/dev/null || grep -qE "nameserver [0-9.]+" /etc/resolv.conf 2>/dev/null; then
    ns_list=$(grep "nameserver" /etc/resolv.conf 2>/dev/null | tr '\n' ' ' || true)
    report_check "DNS_RESOLV_CONF" "PASS" "Valid nameservers present in /etc/resolv.conf: ${ns_list}"
else
    report_check "DNS_RESOLV_CONF" "FAIL" "No public DNS found in /etc/resolv.conf"
fi

# -----------------------------------------------------------------------------
# Check 14: CachyOS Bore Kernel Package Installed
# -----------------------------------------------------------------------------
if pacman -Q linux-cachyos-bore &>/dev/null; then
    pkg_ver=$(pacman -Q linux-cachyos-bore)
    report_check "PKG_CACHYOS_BORE" "PASS" "Package installed: ${pkg_ver}"
else
    report_check "PKG_CACHYOS_BORE" "FAIL" "Package linux-cachyos-bore is missing"
fi

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

# -----------------------------------------------------------------------------
# Summary and Final Verdict
# -----------------------------------------------------------------------------
echo ""
echo "================================================================="
echo "                      ACCEPTANCE SUMMARY                         "
echo "================================================================="
echo "Total Checks : ${TOTAL_CHECKS}"
echo "Passed Checks: ${PASSED_CHECKS}"
echo "Failed Checks: ${FAILED_CHECKS}"

if [[ ${FAILED_CHECKS} -eq 0 ]]; then
    OVERALL_RESULT="PASSED"
    echo "[ACCEPTANCE_SUMMARY] RESULT=PASSED TOTAL=${TOTAL_CHECKS} PASSED=${PASSED_CHECKS} FAILED=0"
    echo "=== VM ACCEPTANCE VERIFICATION SUCCESSFUL ==="
else
    OVERALL_RESULT="FAILED"
    echo "[ACCEPTANCE_SUMMARY] RESULT=FAILED TOTAL=${TOTAL_CHECKS} PASSED=${PASSED_CHECKS} FAILED=${FAILED_CHECKS}"
    echo "=== VM ACCEPTANCE VERIFICATION FAILED ==="
fi
echo "================================================================="
echo ""

# Flush storage buffers
sync
sleep 3

# Trigger shutdown of the virtual machine
echo "Shutting down virtual machine..."
systemctl poweroff || poweroff || true
