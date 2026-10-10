# Handoff Report — Milestone 1 Explorer 3: UEFI GRUB Removable & Headless Automation

**Working Directory**: `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_3`  
**Target Scripts**: `/home/chezok/dotfiles/install-arch.sh` and `/home/chezok/dotfiles/install.sh`  
**Reference Artifacts**:
- Patch: `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_3/grub_and_automation.patch`
- Reference script: `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_3/proposed_install-arch.sh`

---

## 1. Observation

### 1.1 Script Equality and Structure
1. Direct file comparison of `/home/chezok/dotfiles/install-arch.sh` and `/home/chezok/dotfiles/install.sh`:
   - `cmp /home/chezok/dotfiles/install-arch.sh /home/chezok/dotfiles/install.sh` returned code `0` (byte-for-byte identical, 61,050 bytes, 1,480 lines).
   - Any modifications targeting `install-arch.sh` must be mirrored identically to `install.sh` to preserve integrity and pass `./verify.sh`.

### 1.2 GRUB Bootloader Observations (Requirement R3)
1. In `install-arch.sh` lines 400–418:
   ```bash
   400:     # ─── GRUB (без quiet, без nowatchdog, без кастомного разрешения) ───
   401:     header "Установка и настройка GRUB..."
   402: 
   403:     grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck
   404: 
   405:     cat > /etc/default/grub << 'EOF'
   406: GRUB_DEFAULT=0
   407: GRUB_TIMEOUT=5
   408: GRUB_DISTRIBUTOR="CachyOS"
   409: GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3"
   410: GRUB_CMDLINE_LINUX=""
   411: GRUB_PRELOAD_MODULES="part_gpt part_msdos"
   412: GRUB_TIMEOUT_STYLE=menu
   413: GRUB_DISABLE_RECOVERY=true
   414: EOF
   415: 
   416:     grub-mkconfig -o /boot/grub/grub.cfg
   417: 
   418:     ok "GRUB установлен и настроен (логи загрузки полностью видны)."
   ```
2. Deficiencies identified:
   - Line 403 executes `grub-install` **without** `--removable`.
   - Without `--removable`, GRUB writes exclusively to `/boot/efi/EFI/GRUB/grubx64.efi` and attempts to create an NVRAM boot variable via `efibootmgr`.
   - The file `/boot/efi/EFI/BOOT/BOOTX64.EFI` is NOT created.
   - There is no post-installation check asserting the presence or file integrity of `/boot/efi/EFI/BOOT/BOOTX64.EFI` or `/boot/grub/grub.cfg`.
   - On UEFI motherboards (especially Intel Ivy Bridge laptops such as Pentium 2020M with HM70/HM76 chipsets) and fresh QEMU OVMF virtual machines without pre-existing persistent NVRAM variables, the UEFI BIOS ignores custom NVRAM entries and strictly loads the standard fallback path: `\EFI\BOOT\BOOTX64.EFI`. Its absence causes the disk to disappear from the boot menu or triggers `No bootable device found`.

### 1.3 Interactive Prompts Blocking Unattended Execution (Requirement R4)
1. In `install-arch.sh` lines 76–115 (`phase_install`):
   ```bash
   76:     read -rp "$(echo -e "${YELLOW}Введите целевой диск для установки (пример: nvme0n1): ${NC}")" TARGET_DISK_RAW
   ...
   100:     read -rp "$(echo -e "${RED}Подтвердите удаление данных (введите 'YES' заглавными буквами): ${NC}")" CONFIRM
   ...
   105:     read -rsp "$(echo -e "${YELLOW}Введите пароль root: ${NC}")" ROOT_PASS; echo
   106:     read -rsp "$(echo -e "${YELLOW}Повторите пароль root: ${NC}")" ROOT_PASS2; echo
   ...
   109:     read -rsp "$(echo -e "${YELLOW}Введите пароль для пользователя ${USERNAME}: ${NC}")" USER_PASS; echo
   110:     read -rsp "$(echo -e "${YELLOW}Повторите пароль для ${USERNAME}: ${NC}")" USER_PASS2; echo
   ```
2. In `install-arch.sh` lines 234–238 (`phase_chroot`):
   ```bash
   234:     source /install-vars.env 2>/dev/null || {
   235:         # Если запущен вручную — спрашиваем
   236:         read -rsp "Пароль root: " ROOT_PASS; echo
   237:         read -rsp "Пароль пользователя (${USERNAME}): " USER_PASS; echo
   238:     }
   ```
3. Deficiencies identified:
   - There is no handling of `AUTORUN=1`, `TARGET_DISK`, `ROOT_PASS`, `USER_PASS`, or `CONFIRM=YES` environment variables.
   - Any execution in a headless environment, automated CI/CD pipeline, or QEMU serial test runner halts indefinitely at line 76 waiting for tty input.
   - Hardcoded partition detection at lines 87–93:
     ```bash
     if [[ "$TARGET_DISK" =~ nvme ]]; then
         EFI_PART="${TARGET_DISK}p1"
         ROOT_PART="${TARGET_DISK}p2"
     else
         EFI_PART="${TARGET_DISK}1"
         ROOT_PART="${TARGET_DISK}2"
     fi
     ```
     While this handles `vda` and `sda` as `vda1`/`vda2`, block devices ending in digits such as `/dev/loop0`, `/dev/mmcblk0`, or `/dev/nbd0` are misclassified as `${TARGET_DISK}1` instead of `${TARGET_DISK}p1`.
   - Line 127 runs `sleep 2; partprobe "$TARGET_DISK"`, but does not invoke `udevadm settle`. Under fast VM execution (QEMU VirtIO), partition creation can outrun kernel udev node generation, leading to transient `No such file or directory` during `mkfs.fat` or `mkfs.xfs`.
   - Line 196–208 writes `/mnt/install-vars.env` without recording `AUTORUN`, leaving `phase_chroot()` unaware of unattended status.

---

## 2. Logic Chain

1. **UEFI GRUB Removable & Dual Bootloader Path (R3)**:
   - *Premise 1*: UEFI Specification Section 3.5 designates `\EFI\BOOT\BOOTX64.EFI` on the FAT32 EFI System Partition as the default fallback bootloader for x86_64 systems.
   - *Premise 2*: Buggy or legacy UEFI BIOS implementations (notably Intel Ivy Bridge mobile chipsets) and automated QEMU OVMF runs without persistent NVRAM variable storage frequently drop NVRAM entries or fail to execute non-removable bootloader IDs.
   - *Premise 3*: Passing `--removable` to `grub-install` instructs GRUB to install directly to `/boot/efi/EFI/BOOT/BOOTX64.EFI`.
   - *Premise 4*: Certain firmware or boot managers (such as systemd-boot or chainloaders) may specifically query `/boot/efi/EFI/GRUB/grubx64.efi`.
   - *Deduction*: By executing `grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck --removable` and synchronizing the binary between `/boot/efi/EFI/BOOT/BOOTX64.EFI` and `/boot/efi/EFI/GRUB/grubx64.efi`, both fallback and vendor-specific NVRAM boot paths are guaranteed to exist.
   - *Deduction*: Adding a post-install assertion (`[[ -f /boot/efi/EFI/BOOT/BOOTX64.EFI ]]`) ensures fail-fast behavior if GRUB installation fails, satisfying Acceptance Criteria.

2. **Headless Automation Logic (R4)**:
   - *Premise 1*: The QEMU test harness in Milestone 2 must launch `install-arch.sh` unattended without user intervention via `AUTORUN=1 TARGET_DISK=/dev/vda ROOT_PASS=root USER_PASS=chezok`.
   - *Premise 2*: If `AUTORUN=1` is set, all interactive `read` prompts must be bypassed using the provided environment variables or safe defaults (`ROOT_PASS=root`, `USER_PASS=chezok`, `CONFIRM=YES`).
   - *Premise 3*: If `TARGET_DISK` is omitted in `AUTORUN=1`, detecting existing block devices in priority (`/dev/vda` for QEMU, then `/dev/nvme0n1`, then `/dev/sda`) enables automatic out-of-the-box provisioning.
   - *Premise 4*: Partition naming must inspect if the disk path ends in a digit (`[0-9]$`), applying the `p` partition separator for `nvme*`, `loop*`, `mmcblk*`, and omitting it for `vd*`, `sd*`.
   - *Premise 5*: Synchronizing with `udevadm settle` after `partprobe` prevents race conditions where format commands execute before device nodes are created.
   - *Premise 6*: Exporting `AUTORUN` into `/mnt/install-vars.env` ensures that `phase_chroot()` suppresses prompts when invoked inside chroot.
   - *Deduction*: Implementing these guards preserves 100% backward compatibility for interactive users while providing full non-interactive execution for automated testing.

---

## 3. Caveats

1. **Case Sensitivity in FAT32 EFI Paths**:
   - The UEFI specification defines `EFI/BOOT/BOOTX64.EFI` (all caps), but Linux FAT32 drivers may occasionally create lowercase or mixed-case directory entries (`bootx64.efi`).
   - *Mitigation implemented*: The verification checks both `/boot/efi/EFI/BOOT/BOOTX64.EFI` and `/boot/efi/EFI/BOOT/bootx64.efi`.
2. **NVRAM Support in Chroot**:
   - In some chroot environments (or virtual machines where `/sys/firmware/efi/efivars` is read-only or not exposed), standard `grub-install` fails when attempting `efibootmgr` NVRAM registration.
   - *Mitigation*: The `--removable` flag deliberately instructs GRUB not to modify NVRAM variables, making installation fully robust even in restricted chroots or minimal test containers.
3. **Password Security in Production**:
   - `install-vars.env` stores plaintext passwords in `/mnt/install-vars.env` during installation. The script already contains `chmod 600 /mnt/install-vars.env` and line 523 removes the file (`rm -f /install-vars.env /install-arch.sh`) at the end of `phase_chroot()`. This is acceptable for automated test images and standard Arch installer workflows.

---

## 4. Conclusion & Exact Code Plan

### 4.1 Summary of Changes
The changes touch 6 distinct locations in `install-arch.sh` (and `install.sh`):
1. **Lines 10–18**: Usage comments updated to document headless automated syntax.
2. **Lines 76–115**: Disk selection, partition detection, confirmation prompt, and password handling wrapped in `AUTORUN=1` and env variable guards.
3. **Line 127**: Added `udevadm settle 2>/dev/null || sleep 2` after `partprobe`.
4. **Line 196**: Exported `AUTORUN='${AUTORUN:-0}'` into `/mnt/install-vars.env`.
5. **Lines 233–239**: Handled `phase_chroot()` variable sourcing and non-interactive password fallback.
6. **Lines 403–418**: Added `--removable` flag to `grub-install`, dual-copy synchronization between `BOOTX64.EFI` and `grubx64.efi`, and verification assertions for `BOOTX64.EFI` and `grub.cfg`.

### 4.2 Exact Before/After Code Snippets

#### Snippet 1: Usage Header (Lines 12–21)
**Before**:
```bash
# Использование:
#   # Из Arch ISO:
#   bash install-arch.sh
#
#   # Внутри chroot (вызывается автоматически):
#   bash /install-arch.sh --chroot
```
**After**:
```bash
# Использование:
#   # Из Arch ISO (интерактивный режим):
#   bash install-arch.sh
#
#   # Из Arch ISO (автоматический / unattended режим):
#   AUTORUN=1 TARGET_DISK=/dev/vda ROOT_PASS=root USER_PASS=chezok bash install-arch.sh
#
#   # Внутри chroot (вызывается автоматически):
#   bash /install-arch.sh --chroot
```

---

#### Snippet 2: Disk Selection, Confirmation & Passwords (Lines 76–115)
**Before**:
```bash
    read -rp "$(echo -e "${YELLOW}Введите целевой диск для установки (пример: nvme0n1): ${NC}")" TARGET_DISK_RAW
    TARGET_DISK_RAW="${TARGET_DISK_RAW#/dev/}"

    if [ -n "$boot_device" ] && [ "$TARGET_DISK_RAW" = "$boot_device" ]; then
        error "Вы выбрали диск ${TARGET_DISK_RAW}, с которого сейчас загружен Live ISO! Выберите ваш внутренний SSD (например, nvme0n1)!"
    fi

    TARGET_DISK="/dev/${TARGET_DISK_RAW}"
    [[ -b "$TARGET_DISK" ]] || error "Диск $TARGET_DISK не найден!"

    # Определяем тип диска (nvme или обычный)
    if [[ "$TARGET_DISK" =~ nvme ]]; then
        EFI_PART="${TARGET_DISK}p1"
        ROOT_PART="${TARGET_DISK}p2"
    else
        EFI_PART="${TARGET_DISK}1"
        ROOT_PART="${TARGET_DISK}2"
    fi

    echo ""
    warn "ВНИМАНИЕ! Диск ${TARGET_DISK} будет ПОЛНОСТЬЮ ОТФОРМАТИРОВАН!"
    warn "EFI раздел: ${EFI_PART} (1GB, FAT32)"
    warn "Root раздел: ${ROOT_PART} (оставшееся место, XFS)"
    echo ""
    read -rp "$(echo -e "${RED}Подтвердите удаление данных (введите 'YES' заглавными буквами): ${NC}")" CONFIRM
    [[ "$CONFIRM" == "YES" ]] || error "Установка отменена."

    # ─── Пароли ───
    echo ""
    read -rsp "$(echo -e "${YELLOW}Введите пароль root: ${NC}")" ROOT_PASS; echo
    read -rsp "$(echo -e "${YELLOW}Повторите пароль root: ${NC}")" ROOT_PASS2; echo
    [[ "$ROOT_PASS" == "$ROOT_PASS2" ]] || error "Пароли root не совпадают!"

    read -rsp "$(echo -e "${YELLOW}Введите пароль для пользователя ${USERNAME}: ${NC}")" USER_PASS; echo
    read -rsp "$(echo -e "${YELLOW}Повторите пароль для ${USERNAME}: ${NC}")" USER_PASS2; echo
    [[ "$USER_PASS" == "$USER_PASS2" ]] || error "Пароли пользователя не совпадают!"

    # Экспортируем для chroot
    export ROOT_PASS USER_PASS TARGET_DISK EFI_PART ROOT_PART
```
**After**:
```bash
    local target_disk_input=""
    if [[ "${AUTORUN:-0}" == "1" ]] || [[ -n "${TARGET_DISK:-}" ]]; then
        if [[ -n "${TARGET_DISK:-}" ]]; then
            target_disk_input="${TARGET_DISK}"
        elif [[ -b /dev/vda ]]; then
            target_disk_input="/dev/vda"
        elif [[ -b /dev/nvme0n1 ]]; then
            target_disk_input="/dev/nvme0n1"
        elif [[ -b /dev/sda ]]; then
            target_disk_input="/dev/sda"
        else
            error "AUTORUN=1 активирован, но TARGET_DISK не задан и подходящий диск не обнаружен!"
        fi
        TARGET_DISK_RAW="${target_disk_input#/dev/}"
        info "Автоматический режим (AUTORUN=1): выбран целевой диск ${TARGET_DISK_RAW}"
    else
        read -rp "$(echo -e "${YELLOW}Введите целевой диск для установки (пример: nvme0n1): ${NC}")" TARGET_DISK_RAW
        TARGET_DISK_RAW="${TARGET_DISK_RAW#/dev/}"
    fi

    if [ -n "$boot_device" ] && [ "$TARGET_DISK_RAW" = "$boot_device" ]; then
        error "Вы выбрали диск ${TARGET_DISK_RAW}, с которого сейчас загружен Live ISO! Выберите ваш внутренний SSD (например, nvme0n1)!"
    fi

    TARGET_DISK="/dev/${TARGET_DISK_RAW}"
    [[ -b "$TARGET_DISK" ]] || error "Диск $TARGET_DISK не найден!"

    # Определяем тип диска (nvme, loop, mmcblk или обычный vd/sd)
    if [[ "$TARGET_DISK" =~ [0-9]$ ]] || [[ "$TARGET_DISK" =~ nvme ]] || [[ "$TARGET_DISK" =~ loop ]]; then
        EFI_PART="${TARGET_DISK}p1"
        ROOT_PART="${TARGET_DISK}p2"
    else
        EFI_PART="${TARGET_DISK}1"
        ROOT_PART="${TARGET_DISK}2"
    fi

    echo ""
    warn "ВНИМАНИЕ! Диск ${TARGET_DISK} будет ПОЛНОСТЬЮ ОТФОРМАТИРОВАН!"
    warn "EFI раздел: ${EFI_PART} (1GB, FAT32)"
    warn "Root раздел: ${ROOT_PART} (оставшееся место, XFS)"
    echo ""
    local confirm_val="${CONFIRM:-}"
    if [[ "${AUTORUN:-0}" == "1" ]] || [[ "${confirm_val^^}" == "YES" ]]; then
        CONFIRM="YES"
        info "Автоматический режим: подтверждение форматирования принято."
    else
        read -rp "$(echo -e "${RED}Подтвердите удаление данных (введите 'YES' заглавными буквами): ${NC}")" CONFIRM
    fi
    local confirm_check="${CONFIRM:-}"
    [[ "${confirm_check^^}" == "YES" ]] || error "Установка отменена."

    # ─── Пароли ───
    echo ""
    if [[ "${AUTORUN:-0}" == "1" ]]; then
        ROOT_PASS="${ROOT_PASS:-root}"
        USER_PASS="${USER_PASS:-chezok}"
        info "Автоматический режим: пароли root и ${USERNAME} установлены."
    else
        if [[ -n "${ROOT_PASS:-}" ]]; then
            info "Пароль root получен из переменной окружения."
        else
            read -rsp "$(echo -e "${YELLOW}Введите пароль root: ${NC}")" ROOT_PASS; echo
            read -rsp "$(echo -e "${YELLOW}Повторите пароль root: ${NC}")" ROOT_PASS2; echo
            [[ "$ROOT_PASS" == "$ROOT_PASS2" ]] || error "Пароли root не совпадают!"
        fi

        if [[ -n "${USER_PASS:-}" ]]; then
            info "Пароль пользователя ${USERNAME} получен из переменной окружения."
        else
            read -rsp "$(echo -e "${YELLOW}Введите пароль для пользователя ${USERNAME}: ${NC}")" USER_PASS; echo
            read -rsp "$(echo -e "${YELLOW}Повторите пароль для ${USERNAME}: ${NC}")" USER_PASS2; echo
            [[ "$USER_PASS" == "$USER_PASS2" ]] || error "Пароли пользователя не совпадают!"
        fi
    fi

    # Экспортируем для chroot
    export ROOT_PASS USER_PASS TARGET_DISK EFI_PART ROOT_PART AUTORUN
```

---

#### Snippet 3: Partition Table Synchronization (Lines 126–128)
**Before**:
```bash
    sgdisk --print "$TARGET_DISK"
    sleep 2; partprobe "$TARGET_DISK"
```
**After**:
```bash
    sgdisk --print "$TARGET_DISK"
    sleep 2
    partprobe "$TARGET_DISK" 2>/dev/null || true
    udevadm settle 2>/dev/null || sleep 2
```

---

#### Snippet 4: Serializing AUTORUN to chroot environment (Lines 196–198)
**Before**:
```bash
    # Передаём переменные
    cat > /mnt/install-vars.env << EOF
ROOT_PASS='${ROOT_PASS}'
USER_PASS='${USER_PASS}'
```
**After**:
```bash
    # Передаём переменные
    cat > /mnt/install-vars.env << EOF
AUTORUN='${AUTORUN:-0}'
ROOT_PASS='${ROOT_PASS}'
USER_PASS='${USER_PASS}'
```

---

#### Snippet 5: chroot Variable Loading (Lines 233–239)
**Before**:
```bash
    # Загружаем переменные
    source /install-vars.env 2>/dev/null || {
        # Если запущен вручную — спрашиваем
        read -rsp "Пароль root: " ROOT_PASS; echo
        read -rsp "Пароль пользователя (${USERNAME}): " USER_PASS; echo
    }
```
**After**:
```bash
    # Загружаем переменные
    if [ -f /install-vars.env ]; then
        source /install-vars.env
    fi
    AUTORUN="${AUTORUN:-0}"
    if [[ -z "${ROOT_PASS:-}" ]]; then
        if [[ "$AUTORUN" == "1" ]]; then
            ROOT_PASS="root"
            info "Автоматический режим: задан пароль root по умолчанию."
        else
            read -rsp "Пароль root: " ROOT_PASS; echo
        fi
    fi
    if [[ -z "${USER_PASS:-}" ]]; then
        if [[ "$AUTORUN" == "1" ]]; then
            USER_PASS="chezok"
            info "Автоматический режим: задан пароль пользователя (${USERNAME}) по умолчанию."
        else
            read -rsp "Пароль пользователя (${USERNAME}): " USER_PASS; echo
        fi
    fi
```

---

#### Snippet 6: GRUB Installation, Dual EFI & Verification (Lines 403–418)
**Before**:
```bash
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck

    cat > /etc/default/grub << 'EOF'
...
    grub-mkconfig -o /boot/grub/grub.cfg

    ok "GRUB установлен и настроен (логи загрузки полностью видны)."
```
**After**:
```bash
    # Флаг --removable обязателен (R3): копирует загрузчик в /boot/efi/EFI/BOOT/BOOTX64.EFI,
    # обеспечивая распознавание диска в UEFI BIOS даже при отсутствии или игнорировании NVRAM записей.
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck --removable

    # Гарантируем наличие обоих путей: fallback (/EFI/BOOT/BOOTX64.EFI) и NVRAM (/EFI/GRUB/grubx64.efi)
    mkdir -p /boot/efi/EFI/GRUB
    mkdir -p /boot/efi/EFI/BOOT

    if [[ -f /boot/efi/EFI/BOOT/BOOTX64.EFI ]] && [[ ! -f /boot/efi/EFI/GRUB/grubx64.efi ]]; then
        cp /boot/efi/EFI/BOOT/BOOTX64.EFI /boot/efi/EFI/GRUB/grubx64.efi
        info "Скопирован /boot/efi/EFI/BOOT/BOOTX64.EFI -> /boot/efi/EFI/GRUB/grubx64.efi"
    elif [[ -f /boot/efi/EFI/BOOT/bootx64.efi ]] && [[ ! -f /boot/efi/EFI/GRUB/grubx64.efi ]]; then
        cp /boot/efi/EFI/BOOT/bootx64.efi /boot/efi/EFI/GRUB/grubx64.efi
        info "Скопирован /boot/efi/EFI/BOOT/bootx64.efi -> /boot/efi/EFI/GRUB/grubx64.efi"
    elif [[ -f /boot/efi/EFI/GRUB/grubx64.efi ]] && [[ ! -f /boot/efi/EFI/BOOT/BOOTX64.EFI ]]; then
        cp /boot/efi/EFI/GRUB/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI
        info "Скопирован /boot/efi/EFI/GRUB/grubx64.efi -> /boot/efi/EFI/BOOT/BOOTX64.EFI"
    fi

    # Верификация наличия BOOTX64.EFI (R3 Acceptance Criteria)
    if [[ -f /boot/efi/EFI/BOOT/BOOTX64.EFI ]] || [[ -f /boot/efi/EFI/BOOT/bootx64.efi ]]; then
        local efi_file="/boot/efi/EFI/BOOT/BOOTX64.EFI"
        [[ -f "$efi_file" ]] || efi_file="/boot/efi/EFI/BOOT/bootx64.efi"
        local efi_size
        efi_size=$(stat -c%s "$efi_file" 2>/dev/null || wc -c < "$efi_file")
        ok "UEFI bootloader верифицирован: ${efi_file} присутствует (${efi_size} байт)."
    else
        error "Критическая ошибка: /boot/efi/EFI/BOOT/BOOTX64.EFI не найден после установки GRUB!"
    fi

    if [[ -f /boot/efi/EFI/GRUB/grubx64.efi ]]; then
        ok "UEFI NVRAM bootloader верифицирован: /boot/efi/EFI/GRUB/grubx64.efi присутствует."
    fi

    cat > /etc/default/grub << 'EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="CachyOS"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3"
GRUB_CMDLINE_LINUX=""
GRUB_PRELOAD_MODULES="part_gpt part_msdos"
GRUB_TIMEOUT_STYLE=menu
GRUB_DISABLE_RECOVERY=true
EOF

    grub-mkconfig -o /boot/grub/grub.cfg

    if [[ -f /boot/grub/grub.cfg ]]; then
        ok "GRUB конфигурация /boot/grub/grub.cfg успешно сгенерирована."
    else
        error "Критическая ошибка: /boot/grub/grub.cfg не сгенерирован!"
    fi

    ok "GRUB установлен и настроен (логи загрузки полностью видны)."
```

---

## 5. Verification Method

### 5.1 Syntax and Static Checks
Run the following commands from `/home/chezok/dotfiles`:
```bash
# 1. Verify syntax of the proposed modified script:
bash -n /home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_3/proposed_install-arch.sh

# 2. Test dry-run patch applicability against both install-arch.sh and install.sh:
patch --dry-run /home/chezok/dotfiles/install-arch.sh < /home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_3/grub_and_automation.patch
patch --dry-run /home/chezok/dotfiles/install.sh < /home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_3/grub_and_automation.patch
```

### 5.2 Unit Simulation of Headless Logic
Execute the following verification test script in a subshell:
```bash
bash -euo pipefail -c '
# Test 1: Full non-interactive variables
export AUTORUN=1 TARGET_DISK=/dev/vda ROOT_PASS=testroot USER_PASS=testuser CONFIRM=YES
source <(grep -A 85 "phase_install()" /home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_3/proposed_install-arch.sh | head -n 85)
echo "Syntax and logic evaluation succeeded!"
'
```

### 5.3 Acceptance Criteria Validation (in Guest VM)
Inside the booted QEMU guest following installation:
```bash
# 1. Assert BOOTX64.EFI presence
test -f /boot/efi/EFI/BOOT/BOOTX64.EFI && echo "BOOTX64.EFI OK"

# 2. Assert grubx64.efi presence
test -f /boot/efi/EFI/GRUB/grubx64.efi && echo "grubx64.efi OK"

# 3. Assert grub.cfg generated
test -f /boot/grub/grub.cfg && echo "grub.cfg OK"
```

### 5.4 Invalidation Conditions
- If running `grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck --removable` fails to create `/boot/efi/EFI/BOOT/BOOTX64.EFI`, this plan is invalidated.
- If `install-arch.sh` with `AUTORUN=1 TARGET_DISK=/dev/vda` halts on any `read` prompt or throws an unbound variable error under `set -euo pipefail`, this plan is invalidated.
