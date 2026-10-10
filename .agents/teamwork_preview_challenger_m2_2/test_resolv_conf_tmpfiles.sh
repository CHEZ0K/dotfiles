#!/usr/bin/env bash
set -euo pipefail

TEST_DIR="/home/chezok/dotfiles/.agents/teamwork_preview_challenger_m2_2/scratch/tmpfiles_test"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

echo "=== TEST 1: UNMASKED systemd-tmpfiles overwrites /etc/resolv.conf ==="
ROOT_A="$TEST_DIR/root_unmasked"
mkdir -p "$ROOT_A/etc" "$ROOT_A/usr/lib/tmpfiles.d"

# Copy real systemd-resolve.conf
cp /usr/lib/tmpfiles.d/systemd-resolve.conf "$ROOT_A/usr/lib/tmpfiles.d/systemd-resolve.conf"

# Put static resolv.conf
cat > "$ROOT_A/etc/resolv.conf" << 'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

echo "Before tmpfiles in unmasked root:"
ls -l "$ROOT_A/etc/resolv.conf"
cat "$ROOT_A/etc/resolv.conf"

# Run systemd-tmpfiles on ROOT_A
systemd-tmpfiles --create --boot --root="$ROOT_A" --prefix=/etc/resolv.conf 2>&1 || true

echo "After tmpfiles in unmasked root:"
ls -l "$ROOT_A/etc/resolv.conf" || true
if [[ -L "$ROOT_A/etc/resolv.conf" ]]; then
    echo "CONFIRMED: Without mask, systemd-tmpfiles OVERWRITES /etc/resolv.conf with a symlink!"
fi

echo ""
echo "=== TEST 2: MASKED systemd-resolve.conf protects /etc/resolv.conf ==="
ROOT_B="$TEST_DIR/root_masked"
mkdir -p "$ROOT_B/etc/tmpfiles.d" "$ROOT_B/usr/lib/tmpfiles.d"

# Copy real systemd-resolve.conf
cp /usr/lib/tmpfiles.d/systemd-resolve.conf "$ROOT_B/usr/lib/tmpfiles.d/systemd-resolve.conf"

# Apply the installer's protection: mask in /etc/tmpfiles.d/
ln -sf /dev/null "$ROOT_B/etc/tmpfiles.d/systemd-resolve.conf"

# Put static resolv.conf
cat > "$ROOT_B/etc/resolv.conf" << 'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 10.0.2.3
EOF

echo "Before tmpfiles in masked root:"
ls -l "$ROOT_B/etc/resolv.conf"
cat "$ROOT_B/etc/resolv.conf"

# Run systemd-tmpfiles on ROOT_B
systemd-tmpfiles --create --boot --root="$ROOT_B" --prefix=/etc/resolv.conf 2>&1 || true

echo "After tmpfiles in masked root:"
ls -l "$ROOT_B/etc/resolv.conf"
if [[ -f "$ROOT_B/etc/resolv.conf" && ! -L "$ROOT_B/etc/resolv.conf" ]]; then
    echo "CONFIRMED: With /etc/tmpfiles.d/systemd-resolve.conf -> /dev/null, /etc/resolv.conf is PROTECTED from tmpfiles overwriting!"
    grep "nameserver" "$ROOT_B/etc/resolv.conf"
else
    echo "FAILED: /etc/resolv.conf was modified despite mask!"
    exit 1
fi

echo ""
echo "=== TEST 3: ensure_resolv_conf function self-healing ==="
# Test ensure_resolv_conf logic from install-arch.sh
ensure_resolv_conf_test() {
    local target_root="$1"
    mkdir -p "$target_root/etc/tmpfiles.d"
    ln -sf /dev/null "$target_root/etc/tmpfiles.d/systemd-resolve.conf" 2>/dev/null || true
    if [[ ! -s "$target_root/etc/resolv.conf" ]] || [[ -L "$target_root/etc/resolv.conf" ]] || ! grep -q "nameserver" "$target_root/etc/resolv.conf" 2>/dev/null; then
        rm -f "$target_root/etc/resolv.conf"
        cat > "$target_root/etc/resolv.conf" << 'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 10.0.2.3
EOF
        chmod 644 "$target_root/etc/resolv.conf"
    fi
}

ROOT_C="$TEST_DIR/root_healing"
mkdir -p "$ROOT_C/etc"

# Case C1: resolv.conf is a broken symlink
ln -sf /nonexistent "$ROOT_C/etc/resolv.conf"
ensure_resolv_conf_test "$ROOT_C"
[[ -f "$ROOT_C/etc/resolv.conf" && ! -L "$ROOT_C/etc/resolv.conf" ]] || { echo "Healing failed for symlink"; exit 1; }
echo "Healed broken symlink -> OK"

# Case C2: resolv.conf is empty
> "$ROOT_C/etc/resolv.conf"
ensure_resolv_conf_test "$ROOT_C"
grep -q "1.1.1.1" "$ROOT_C/etc/resolv.conf" || { echo "Healing failed for empty file"; exit 1; }
echo "Healed empty file -> OK"

# Case C3: resolv.conf contains valid DNS, should not be altered
echo "# custom" >> "$ROOT_C/etc/resolv.conf"
ensure_resolv_conf_test "$ROOT_C"
grep -q "# custom" "$ROOT_C/etc/resolv.conf" || { echo "Valid file corrupted"; exit 1; }
echo "Preserved valid file -> OK"

echo ""
echo "ALL RESOLV.CONF PROTECTION TESTS PASSED SUCCESSFULLY!"
