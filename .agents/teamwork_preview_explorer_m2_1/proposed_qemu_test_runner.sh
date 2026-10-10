#!/usr/bin/env bash
# =============================================================================
# tests/qemu_test_runner.sh
# Automated QEMU VM Test Harness for Arch Linux / CachyOS Installer
# Milestone 2: QEMU Virtual Test Stand & E2E Verification
# =============================================================================

set -euo pipefail

# ─────────────── ANSI COLORS & FORMATTING ───────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════════════════════════${NC}\n${BOLD}${CYAN}  $*${NC}\n${BOLD}${CYAN}══════════════════════════════════════════════════════════════${NC}\n"; }

# ─────────────── PATHS & DEFAULT PARAMETERS ───────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WORK_DIR="${WORK_DIR:-$PROJECT_ROOT/tests/build}"
ARCH_ISO_PATH="${ARCH_ISO_PATH:-/home/chezok/backup_iso/archlinux-2026.09.01-x86_64.iso}"
DISK_IMG="${DISK_IMG:-$WORK_DIR/target.qcow2}"
DISK_SIZE="${DISK_SIZE:-25G}"
VM_MEM="${VM_MEM:-2560M}"
VM_CPUS="${VM_CPUS:-4}"
HTTP_PORT="${HTTP_PORT:-8089}"
STAGE1_TIMEOUT="${STAGE1_TIMEOUT:-1800}" # 30 minutes
STAGE2_TIMEOUT="${STAGE2_TIMEOUT:-300}"  # 5 minutes

ACTION="${1:-all}"

# ─────────────── PREREQUISITE CHECKS ───────────────
check_prerequisites() {
    header "Проверка окружения хоста и зависимостей QEMU"

    local missing_pkgs=()

    if ! command -v qemu-system-x86_64 &>/dev/null; then
        missing_pkgs+=("qemu-system-x86")
    else
        ok "QEMU бинарник найден: $(command -v qemu-system-x86_64) ($(qemu-system-x86_64 --version | head -n1))"
    fi

    if ! command -v qemu-img &>/dev/null; then
        missing_pkgs+=("qemu-img")
    else
        ok "qemu-img найден: $(command -v qemu-img)"
    fi

    # Locate UEFI OVMF firmware
    OVMF_CODE=""
    OVMF_VARS_SRC=""
    local ovmf_code_candidates=(
        "/usr/share/edk2/x64/OVMF_CODE.4m.fd"
        "/usr/share/edk2/x64/OVMF_CODE.fd"
        "/usr/share/ovmf/x64/OVMF_CODE.fd"
        "/usr/share/edk2-ovmf/x64/OVMF_CODE.fd"
    )
    local ovmf_vars_candidates=(
        "/usr/share/edk2/x64/OVMF_VARS.4m.fd"
        "/usr/share/edk2/x64/OVMF_VARS.fd"
        "/usr/share/ovmf/x64/OVMF_VARS.fd"
        "/usr/share/edk2-ovmf/x64/OVMF_VARS.fd"
    )

    for p in "${ovmf_code_candidates[@]}"; do
        if [[ -f "$p" ]]; then
            OVMF_CODE="$p"
            break
        fi
    done

    for p in "${ovmf_vars_candidates[@]}"; do
        if [[ -f "$p" ]]; then
            OVMF_VARS_SRC="$p"
            break
        fi
    done

    if [[ -z "$OVMF_CODE" || -z "$OVMF_VARS_SRC" ]]; then
        missing_pkgs+=("edk2-ovmf")
    else
        ok "UEFI OVMF прошивка найдена: CODE=$OVMF_CODE, VARS=$OVMF_VARS_SRC"
    fi

    if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
        warn "Отсутствуют необходимые пакеты хоста: ${missing_pkgs[*]}"
        warn "Для установки выполните: echo chezok | sudo -S pacman -S --needed --noconfirm ${missing_pkgs[*]}"
        if [[ "${INSTALL_DEPS:-0}" == "1" ]] || [[ -t 0 ]]; then
            info "Попытка автоматической установки пакетов через sudo..."
            echo chezok | sudo -S pacman -S --needed --noconfirm "${missing_pkgs[@]}" || error "Не удалось установить пакеты!"
            # Рекурсивный повтор проверки после установки
            INSTALL_DEPS=0 check_prerequisites
            return
        else
            error "Запустите скрипт с INSTALL_DEPS=1 или установите пакеты вручную!"
        fi
    fi

    # Check KVM availability
    ACCEL_ARGS=()
    if [[ -w /dev/kvm ]]; then
        ok "Аппаратная виртуализация KVM доступна (/dev/kvm с правами записи)."
        ACCEL_ARGS=(-enable-kvm -cpu host)
    else
        warn "/dev/kvm недоступен для записи — откат на программную эмуляцию TCG (может работать медленнее)."
        ACCEL_ARGS=(-accel tcg -cpu max)
    fi

    # Check Arch Live ISO
    if [[ ! -f "$ARCH_ISO_PATH" ]]; then
        error "Live ISO не найден по пути: $ARCH_ISO_PATH! Проверьте переменную ARCH_ISO_PATH."
    else
        local iso_size
        iso_size=$(stat -c%s "$ARCH_ISO_PATH" 2>/dev/null || wc -c < "$ARCH_ISO_PATH")
        ok "Live ISO верифицирован: $ARCH_ISO_PATH (${iso_size} байт)."
    fi

    # Check other utility tools
    for tool in bsdtar python3; do
        command -v "$tool" &>/dev/null || error "Утилита $tool не найдена на хосте!"
    done
}

# ─────────────── WORKSPACE PREPARATION ───────────────
prepare_workspace() {
    header "Подготовка рабочего каталога тестов ($WORK_DIR)"

    mkdir -p "$WORK_DIR/staging"
    mkdir -p "$WORK_DIR/reports"

    # Create target virtual disk if not existing
    if [[ ! -f "$DISK_IMG" ]]; then
        info "Создание чистого qcow2 диска ${DISK_IMG} (размер: ${DISK_SIZE})..."
        qemu-img create -f qcow2 "$DISK_IMG" "$DISK_SIZE"
        ok "Виртуальный диск создан."
    else
        info "Используется существующий виртуальный диск: $DISK_IMG"
    fi

    # Prepare writable copy of OVMF_VARS
    cp -f "$OVMF_VARS_SRC" "$WORK_DIR/OVMF_VARS.fd"
    chmod 644 "$WORK_DIR/OVMF_VARS.fd"
    ok "Создана перезаписываемая копия NVRAM: $WORK_DIR/OVMF_VARS.fd"

    # Extract kernel and initramfs from ISO for direct fw_cfg boot
    if [[ ! -f "$WORK_DIR/vmlinuz-linux" || ! -f "$WORK_DIR/initramfs-linux.img" ]]; then
        info "Извлечение ядра и initramfs из Live ISO..."
        bsdtar -xf "$ARCH_ISO_PATH" -C "$WORK_DIR" arch/boot/x86_64/vmlinuz-linux arch/boot/x86_64/initramfs-linux.img
        mv "$WORK_DIR/arch/boot/x86_64/vmlinuz-linux" "$WORK_DIR/vmlinuz-linux"
        mv "$WORK_DIR/arch/boot/x86_64/initramfs-linux.img" "$WORK_DIR/initramfs-linux.img"
        rm -rf "$WORK_DIR/arch"
        ok "Ядро и initramfs успешно извлечены."
    fi
}

# ─────────────── STAGE 1: AUTOMATED INSTALLATION ───────────────
run_stage1() {
    header "ЭТАП 1: Неинтерактивная установка Arch Linux / CachyOS в QEMU"

    local staging_dir="$WORK_DIR/staging"
    rm -rf "$staging_dir" && mkdir -p "$staging_dir"

    # 1. Archive current dotfiles repo to dotfiles.tar.gz
    info "Упаковка локального репозитория dotfiles в архив..."
    tar -czf "$staging_dir/dotfiles.tar.gz" -C "$PROJECT_ROOT/.." "$(basename "$PROJECT_ROOT")"
    ok "Архив репозитория создан: $staging_dir/dotfiles.tar.gz"

    # 2. Generate in-guest autorun.sh payload
    cat > "$staging_dir/autorun.sh" << 'AUTORUN_EOF'
#!/usr/bin/env bash
set -u

# Stream output to serial console
exec > >(tee -a /tmp/stage1_autorun.log > /dev/ttyS0) 2>&1

echo ""
echo "================================================================="
echo "   STAGE 1 IN-GUEST INSTALLATION ORCHESTRATOR STARTED           "
echo "================================================================="
echo "Timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# Ensure public DNS in Live ISO
mkdir -p /etc
cat > /etc/resolv.conf << 'DNS_EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
DNS_EOF

# Download and unpack dotfiles payload from host HTTP server
echo "[STAGE1] Скачивание архива dotfiles с хоста (10.0.2.2)..."
mkdir -p /root/repo
curl -fsSL "http://10.0.2.2:8089/dotfiles.tar.gz" -o /tmp/dotfiles.tar.gz
tar -xzf /tmp/dotfiles.tar.gz -C /root/repo
REPO_DIR=$(find /root/repo -mindepth 1 -maxdepth 1 -type d | head -n1)

if [[ ! -d "$REPO_DIR" || ! -f "$REPO_DIR/install-arch.sh" ]]; then
    echo "[STAGE1_FATAL] Не удалось обнаружить install-arch.sh в распакованном архиве!"
    echo "###STAGE1_COMPLETE_FAILED:ERR_NO_INSTALLER###"
    sleep 3
    poweroff
    exit 1
fi

echo "[STAGE1] Запуск install-arch.sh в автоматическом режиме (AUTORUN=1)..."
cd "$REPO_DIR"
export AUTORUN=1
export TARGET_DISK="/dev/vda"
export ROOT_PASS="root"
export USER_PASS="chezok"
export CONFIRM="YES"

set +e
bash ./install-arch.sh
INSTALL_RC=$?
set -e

if [[ $INSTALL_RC -ne 0 ]]; then
    echo "[STAGE1_FAILED] install-arch.sh завершился с кодом ошибки: $INSTALL_RC"
    echo "###STAGE1_COMPLETE_FAILED:${INSTALL_RC}###"
    sleep 3
    poweroff
    exit $INSTALL_RC
fi

echo "[STAGE1] install-arch.sh успешно завершен! Настройка Stage 2 проверок..."

# Mount installed system to plant Stage 2 verification unit
mkdir -p /target
mount /dev/vda2 /target
mkdir -p /target/boot/efi
mount /dev/vda1 /target/boot/efi

# Copy vm_acceptance_check.sh
mkdir -p /target/usr/local/bin
if [[ -f "$REPO_DIR/tests/vm_acceptance_check.sh" ]]; then
    cp "$REPO_DIR/tests/vm_acceptance_check.sh" /target/usr/local/bin/vm_acceptance_check.sh
elif [[ -f /tmp/vm_acceptance_check.sh ]]; then
    cp /tmp/vm_acceptance_check.sh /target/usr/local/bin/vm_acceptance_check.sh
else
    # Fallback fetch from host
    curl -fsSL "http://10.0.2.2:8089/vm_acceptance_check.sh" -o /target/usr/local/bin/vm_acceptance_check.sh || true
fi
chmod 755 /target/usr/local/bin/vm_acceptance_check.sh

# Install systemd acceptance test service
cat > /target/etc/systemd/system/vm-acceptance.service << 'SERVICE_EOF'
[Unit]
Description=Milestone 2 Acceptance Criteria Verification
After=multi-user.target
Wants=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vm_acceptance_check.sh
StandardOutput=tty
StandardError=tty
TTYPath=/dev/ttyS0

[Install]
WantedBy=multi-user.target
SERVICE_EOF

mkdir -p /target/etc/systemd/system/multi-user.target.wants
ln -sf /etc/systemd/system/vm-acceptance.service /target/etc/systemd/system/multi-user.target.wants/vm-acceptance.service

# Ensure GRUB serial console in Stage 2
if [[ -f /target/etc/default/grub ]]; then
    sed -i 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200"/' /target/etc/default/grub
    arch-chroot /target grub-mkconfig -o /boot/grub/grub.cfg || true
fi

sync
umount -R /target

echo "###STAGE1_COMPLETE_SUCCESS###"
echo "[STAGE1] Выключение виртуальной машины..."
sleep 3
poweroff
AUTORUN_EOF
    chmod +x "$staging_dir/autorun.sh"

    # Copy vm_acceptance_check.sh to staging if present
    if [[ -f "$PROJECT_ROOT/tests/vm_acceptance_check.sh" ]]; then
        cp "$PROJECT_ROOT/tests/vm_acceptance_check.sh" "$staging_dir/vm_acceptance_check.sh"
    elif [[ -f "$SCRIPT_DIR/proposed_vm_acceptance_check.sh" ]]; then
        cp "$SCRIPT_DIR/proposed_vm_acceptance_check.sh" "$staging_dir/vm_acceptance_check.sh"
    fi

    # 3. Launch host HTTP server in background
    info "Запуск локального HTTP сервера на порту ${HTTP_PORT}..."
    python3 -m http.server "$HTTP_PORT" --directory "$staging_dir" &
    HTTP_PID=$!
    trap 'kill -9 "$HTTP_PID" 2>/dev/null || true' EXIT

    # 4. Launch QEMU Stage 1
    local stage1_log="$WORK_DIR/stage1_serial.log"
    rm -f "$stage1_log"
    touch "$stage1_log"

    info "Запуск QEMU для выполнения Stage 1 (таймаут: ${STAGE1_TIMEOUT}с)..."
    local qemu_cmd=(
        qemu-system-x86_64
        -machine q35
        "${ACCEL_ARGS[@]}"
        -m "$VM_MEM"
        -smp "$VM_CPUS"
        -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
        -drive "if=pflash,format=raw,file=$WORK_DIR/OVMF_VARS.fd"
        -drive "file=$ARCH_ISO_PATH,media=cdrom,readonly=on"
        -drive "file=$DISK_IMG,if=virtio,format=qcow2"
        -kernel "$WORK_DIR/vmlinuz-linux"
        -initrd "$WORK_DIR/initramfs-linux.img"
        -append "archisobasedir=arch archisolabel=ARCH_202609 script=http://10.0.2.2:${HTTP_PORT}/autorun.sh console=tty0 console=ttyS0,115200"
        -netdev "user,id=net0"
        -device "virtio-net-pci,netdev=net0"
        -serial "file:$stage1_log"
        -display none
    )

    "${qemu_cmd[@]}" &
    local qemu_pid=$!

    # Monitor Stage 1 execution
    local start_time=$(date +%s)
    local stage1_success=0

    while kill -0 "$qemu_pid" 2>/dev/null; do
        local now=$(date +%s)
        local elapsed=$((now - start_time))

        if [[ $elapsed -gt $STAGE1_TIMEOUT ]]; then
            warn "Превышен таймаут Stage 1 (${STAGE1_TIMEOUT}с)! Принудительная остановка QEMU..."
            kill -9 "$qemu_pid" 2>/dev/null || true
            break
        fi

        if grep -q "###STAGE1_COMPLETE_SUCCESS###" "$stage1_log" 2>/dev/null; then
            stage1_success=1
            info "Обнаружен токен успешного завершения Stage 1. Ожидание выключения QEMU..."
            wait "$qemu_pid" 2>/dev/null || true
            break
        fi

        if grep -q "###STAGE1_COMPLETE_FAILED" "$stage1_log" 2>/dev/null; then
            warn "Обнаружен токен ошибки Stage 1!"
            wait "$qemu_pid" 2>/dev/null || true
            break
        fi

        sleep 5
    done

    # Clean up HTTP server
    kill "$HTTP_PID" 2>/dev/null || true
    trap - EXIT

    if [[ $stage1_success -eq 1 ]]; then
        ok "ЭТАП 1 ЗАВЕРШЕН УСПЕШНО! Все фазы установки выполнены."
    else
        error "ЭТАП 1 ЗАВЕРШИЛСЯ С ОШИБКОЙ! Проверьте лог: $stage1_log"
    fi
}

# ─────────────── STAGE 2: UEFI BOOT & IN-GUEST VALIDATION ───────────────
run_stage2() {
    header "ЭТАП 2: UEFI загрузка установленного диска и in-guest верификация"

    local stage2_log="$WORK_DIR/stage2_serial.log"
    rm -f "$stage2_log"
    touch "$stage2_log"

    info "Запуск QEMU для Stage 2 с чистого диска (без Live ISO)..."
    local qemu_cmd=(
        qemu-system-x86_64
        -machine q35
        "${ACCEL_ARGS[@]}"
        -m "$VM_MEM"
        -smp "$VM_CPUS"
        -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
        -drive "if=pflash,format=raw,file=$WORK_DIR/OVMF_VARS.fd"
        -drive "file=$DISK_IMG,if=virtio,format=qcow2"
        -netdev "user,id=net0"
        -device "virtio-net-pci,netdev=net0"
        -serial "file:$stage2_log"
        -display none
    )

    "${qemu_cmd[@]}" &
    local qemu_pid=$!

    local start_time=$(date +%s)
    local stage2_success=0

    while kill -0 "$qemu_pid" 2>/dev/null; do
        local now=$(date +%s)
        local elapsed=$((now - start_time))

        if [[ $elapsed -gt $STAGE2_TIMEOUT ]]; then
            warn "Превышен таймаут Stage 2 (${STAGE2_TIMEOUT}с)! Принудительная остановка QEMU..."
            kill -9 "$qemu_pid" 2>/dev/null || true
            break
        fi

        if grep -q "\[ACCEPTANCE_SUMMARY\] RESULT=PASSED" "$stage2_log" 2>/dev/null; then
            stage2_success=1
            info "Обнаружен токен [ACCEPTANCE_SUMMARY] RESULT=PASSED. Ожидание выключения QEMU..."
            wait "$qemu_pid" 2>/dev/null || true
            break
        fi

        if grep -q "\[ACCEPTANCE_SUMMARY\] RESULT=FAILED" "$stage2_log" 2>/dev/null; then
            warn "Обнаружен токен неудачи acceptance проверок!"
            wait "$qemu_pid" 2>/dev/null || true
            break
        fi

        sleep 3
    done

    wait "$qemu_pid" 2>/dev/null || true

    # Parse and display verification results
    header "РЕЗУЛЬТАТЫ IN-GUEST ВЕРИФИКАЦИИ (ACCEPTANCE CRITERIA)"

    local checks_found=0
    while IFS= read -r line; do
        if [[ "$line" =~ \[ACCEPTANCE_CHECK\] ]]; then
            checks_found=$((checks_found + 1))
            echo -e "${CYAN}  * ${line}${NC}"
        fi
    done < <(grep "\[ACCEPTANCE_CHECK\]" "$stage2_log" 2>/dev/null || true)

    if [[ $checks_found -eq 0 ]]; then
        warn "Служба vm_acceptance_check не вернула записей проверок. Проверьте лог: $stage2_log"
    fi

    if [[ $stage2_success -eq 1 ]]; then
        ok "ЭТАП 2 ЗАВЕРШЕН УСПЕШНО! Все Acceptance Criteria подтверждены."
    else
        error "ЭТАП 2 НЕ ПРОШЕЛ ВЕРИФИКАЦИЮ! Проверьте лог: $stage2_log"
    fi
}

# ─────────────── CLI DISPATCH ───────────────
case "$ACTION" in
    check|--check)
        check_prerequisites
        ;;
    stage1|--stage1)
        check_prerequisites
        prepare_workspace
        run_stage1
        ;;
    stage2|--stage2)
        check_prerequisites
        prepare_workspace
        run_stage2
        ;;
    clean|--clean)
        info "Очистка рабочего каталога: $WORK_DIR"
        rm -rf "$WORK_DIR"
        ok "Очистка завершена."
        ;;
    all|--all|"")
        check_prerequisites
        prepare_workspace
        run_stage1
        run_stage2
        ok "══════════════════════════════════════════════════════════════"
        ok " ВСЕ ЭТАПЫ MILESTONE 2 (STAGE 1 & STAGE 2) УСПЕШНО ПРОЙДЕНЫ! "
        ok "══════════════════════════════════════════════════════════════"
        ;;
    *)
        echo "Использование: $0 [all|stage1|stage2|check|clean]"
        exit 1
        ;;
esac
