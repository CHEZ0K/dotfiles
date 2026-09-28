#!/usr/bin/env bash
# =============================================================================
# CACHYOS ARCH LINUX FULL AUTO-INSTALLER
# Версия: 3.0  |  Дата: 2026-09-28
# Автор: generated for chezok
#
# ЭТАПЫ:
#   1. Запуск с Arch ISO: разбивка диска, pacstrap, chroot
#   2. Внутри chroot: CachyOS репо, пакеты, пользователи, GRUB, службы
#   3. После перезагрузки: clone git-репо, деплой дотфайлов
#
# Использование:
#   # Из Arch ISO:
#   bash install-arch.sh
#
#   # Внутри chroot (вызывается автоматически):
#   bash /install-arch.sh --chroot
#
#   # После первого входа в систему:
#   bash ~/install-arch.sh --deploy
# =============================================================================

set -euo pipefail

# ─────────────── ЦВЕТА ───────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${NC}"; echo -e "${BOLD}${CYAN}  $*${NC}"; echo -e "${BOLD}${CYAN}══════════════════════════════════════════${NC}\n"; }

# ─────────────── КОНФИГУРАЦИЯ ───────────────
DOTFILES_REPO="https://github.com/chezok/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
USERNAME="chezok"
HOSTNAME="cachyos"
TIMEZONE="Europe/Moscow"
LOCALE_LANG="en_US.UTF-8"
LOCALE_RU="ru_RU.UTF-8"
KEYMAP="us"

# Полный список пакетов
PACMAN_PKGS=(
    # Base
    base base-devel linux-firmware sudo git curl nano vim

    # CachyOS ядро
    linux-cachyos-bore linux-cachyos-bore-headers
    cachyos-settings scx-scheds

    # Загрузчик и ФС
    grub efibootmgr xfsprogs

    # Сеть и bluetooth
    networkmanager bluez bluez-utils openssh

    # Wayland / Niri стек
    wayland niri sddm xwayland-satellite
    wl-clipboard cliphist

    # Звук
    pipewire pipewire-pulse wireplumber pavucontrol

    # GPU (AMD)
    mesa vulkan-radeon libva-mesa-driver mesa-vdpau vulkan-icd-loader

    # Утилиты и инструменты
    btop htop neofetch aria2 playerctl
    brightnessctl power-profiles-daemon
    libnotify matugen

    # Терминал и шрифты
    foot ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols-mono noto-fonts-emoji

    # Файловый менеджер
    nemo

    # Браузер (Zen через AUR, firefox как запасной)
    firefox

    # Медиа и зрение
    mpv

    # Ночник
    # wlsunset (через AUR или здесь)

    # Иконки и темы GTK
    nwg-look

    # Разное
    grim slurp
    nodejs npm
    rofi
    cava
    python-pywal
    qt6-5compat qt6-multimedia qt6-positioning qt6-sensors
    qt6-virtualkeyboard

    # Шрифты/иконки
    noto-fonts

    # Bluetooth утилиты
    blueberry

    # Системные
    upower acpi lm_sensors

    # Для quickshell и vibepanel
    qt6-declarative
)

AUR_PKGS=(
    # Браузер
    zen-browser-bin

    # Мессенджер
    ayugram-desktop

    # Панель и уведомления
    vibepanel-git
    swaync

    # Обои
    awww
    linux-wallpaperengine-git

    # Pywal интеграция
    python-pywal

    # Музыкальные субтитры
    sptlrx-bin
    waylyrics

    # Терминальные украшения
    unimatrix-git
    lavat
    genact
    tty-clock
    pipes.sh

    # Курсор
    xcursor-furina-git
)

# =============================================================================
# ФАЗА 1: УСТАНОВКА (из Arch ISO)
# =============================================================================
phase_install() {
    header "CACHYOS INSTALLER — ФАЗА 1: РАЗБИВКА И PACSTRAP"

    # Проверяем что мы в ISO
    if [[ ! -d /run/archiso ]]; then
        warn "Не похоже на среду Arch ISO. Продолжаем всё равно..."
    fi

    # ─── Выбор диска ───
    echo ""
    info "Доступные диски:"
    lsblk -d -o NAME,SIZE,TYPE,MODEL | grep -v "loop\|rom\|airoot"
    echo ""
    read -rp "$(echo -e "${YELLOW}Введите диск для установки (пример: nvme0n1, sda): ${NC}")" TARGET_DISK_RAW

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

    # ─── Разбивка диска ───
    header "Разбивка диска ${TARGET_DISK}..."

    # Очищаем все подписи
    wipefs -af "$TARGET_DISK"
    sgdisk --zap-all "$TARGET_DISK"

    # GPT разбивка
    sgdisk --new=1:0:+1G   --typecode=1:ef00 --change-name=1:"EFI"  "$TARGET_DISK"
    sgdisk --new=2:0:0      --typecode=2:8300 --change-name=2:"ROOT" "$TARGET_DISK"
    sgdisk --print "$TARGET_DISK"
    sleep 2; partprobe "$TARGET_DISK"

    ok "Разбивка завершена."

    # ─── Форматирование ───
    header "Форматирование разделов..."

    mkfs.fat -F32 -n EFI "$EFI_PART"
    mkfs.xfs -f -L ROOT "$ROOT_PART"

    ok "Форматирование XFS завершено."

    # ─── Монтирование ───
    header "Монтирование разделов..."

    mount "$ROOT_PART" /mnt
    mkdir -p /mnt/boot/efi
    mount "$EFI_PART" /mnt/boot/efi

    ok "Разделы смонтированы."

    # ─── Mirrorlist ───
    header "Настройка зеркал..."

    # Используем reflector для выбора быстрых зеркал
    if command -v reflector &>/dev/null; then
        reflector --country Russia,Germany,Finland --sort rate --save /etc/pacman.d/mirrorlist --latest 10 --protocol https
    else
        # Ставим быстрые зеркала вручную
        cat > /etc/pacman.d/mirrorlist << 'MIRRORS'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirror.yandex.ru/archlinux/$repo/os/$arch
Server = https://archlinux.thaller.ws/$repo/os/$arch
Server = https://archlinux.vi-di.fr/$repo/os/$arch
MIRRORS
    fi

    ok "Mirrorlist настроен."

    # ─── Pacstrap (минимальная система) ───
    header "Установка базовой системы (pacstrap)..."

    pacstrap -K /mnt \
        base base-devel linux-firmware \
        linux-cachyos-bore linux-cachyos-bore-headers \
        grub efibootmgr xfsprogs \
        networkmanager sudo git curl nano vim \
        2>&1 | tail -5 || true

    # Примечание: CachyOS пакеты пока не доступны — добавим репо внутри chroot
    # Поэтому сначала ставим стандартные пакеты, потом добавляем CachyOS

    # Делаем второй pacstrap с обычными пакетами без CachyOS-специфики
    pacstrap /mnt \
        base base-devel linux-firmware \
        grub efibootmgr xfsprogs \
        networkmanager sudo git curl nano vim \
        2>/dev/null || true

    ok "Базовая система установлена."

    # ─── fstab ───
    header "Генерация fstab..."

    genfstab -U /mnt >> /mnt/etc/fstab
    info "fstab:"
    cat /mnt/etc/fstab

    ok "fstab сгенерирован."

    # ─── Копирование скрипта в chroot ───
    cp "$(realpath "$0")" /mnt/install-arch.sh
    chmod +x /mnt/install-arch.sh

    # Передаём переменные
    cat > /mnt/install-vars.env << EOF
ROOT_PASS='${ROOT_PASS}'
USER_PASS='${USER_PASS}'
USERNAME='${USERNAME}'
HOSTNAME='${HOSTNAME}'
TIMEZONE='${TIMEZONE}'
LOCALE_LANG='${LOCALE_LANG}'
LOCALE_RU='${LOCALE_RU}'
TARGET_DISK='${TARGET_DISK}'
EFI_PART='${EFI_PART}'
ROOT_PART='${ROOT_PART}'
DOTFILES_REPO='${DOTFILES_REPO}'
EOF
    chmod 600 /mnt/install-vars.env

    # ─── Chroot ───
    header "Вход в chroot..."
    arch-chroot /mnt /bin/bash /install-arch.sh --chroot

    # ─── Завершение ───
    header "Размонтирование..."
    umount -R /mnt

    echo ""
    ok "════════════════════════════════════════════"
    ok " УСТАНОВКА ЗАВЕРШЕНА!"
    ok " Перезагрузитесь: reboot"
    ok " После входа выполните: bash ~/install-arch.sh --deploy"
    ok "════════════════════════════════════════════"
}

# =============================================================================
# ФАЗА 2: CHROOT (настройка системы)
# =============================================================================
phase_chroot() {
    header "CACHYOS INSTALLER — ФАЗА 2: НАСТРОЙКА СИСТЕМЫ (CHROOT)"

    # Загружаем переменные
    source /install-vars.env 2>/dev/null || {
        # Если запущен вручную — спрашиваем
        read -rsp "Пароль root: " ROOT_PASS; echo
        read -rsp "Пароль пользователя (${USERNAME}): " USER_PASS; echo
    }

    # ─── CachyOS репозитории ───
    header "Добавление CachyOS репозиториев..."

    # Устанавливаем необходимые инструменты
    pacman -Sy --noconfirm curl wget

    # Скачиваем установщик CachyOS репо
    cd /tmp
    curl -fsSL "https://mirror.cachyos.org/cachyos-repo.tar.xz" -o cachyos-repo.tar.xz
    tar xf cachyos-repo.tar.xz
    cd cachyos-repo
    echo "y" | ./cachyos-repo.sh || warn "CachyOS repo script завершился с ошибкой, продолжаем..."
    cd /tmp

    # Обновляем базу данных
    pacman -Syy --noconfirm

    ok "CachyOS репозитории добавлены."

    # ─── Системное время ───
    header "Настройка времени..."

    ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
    hwclock --systohc

    ok "Timezone: ${TIMEZONE}"

    # ─── Локализация ───
    header "Настройка локали..."

    # Раскомментируем нужные локали
    sed -i "s/^#${LOCALE_LANG}/${LOCALE_LANG}/" /etc/locale.gen
    sed -i "s/^#${LOCALE_RU}/${LOCALE_RU}/" /etc/locale.gen
    locale-gen

    echo "LANG=${LOCALE_LANG}" > /etc/locale.conf
    echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

    ok "Локаль настроена."

    # ─── Hostname ───
    header "Настройка hostname..."

    echo "${HOSTNAME}" > /etc/hostname
    cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

    ok "Hostname: ${HOSTNAME}"

    # ─── Пользователь ───
    header "Создание пользователя ${USERNAME}..."

    # Задаём пароль root
    echo "root:${ROOT_PASS}" | chpasswd

    # Создаём пользователя
    useradd -m -G wheel,audio,video,storage,optical,network,power -s /bin/bash "${USERNAME}" || true
    echo "${USERNAME}:${USER_PASS}" | chpasswd

    # sudoers
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
    # Без пароля для wheel (удобно при установке пакетов)
    # sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

    ok "Пользователь ${USERNAME} создан."

    # ─── mkinitcpio ───
    header "Генерация initramfs..."

    # Добавляем XFS в hooks для корректной загрузки с XFS
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/' /etc/mkinitcpio.conf

    mkinitcpio -P

    ok "initramfs сгенерирован."

    # ─── CachyOS ядро + основные пакеты ───
    header "Установка CachyOS ядра и основных пакетов..."

    # Ядро CachyOS Bore
    pacman -S --noconfirm --needed \
        linux-cachyos-bore linux-cachyos-bore-headers \
        cachyos-settings scx-scheds \
        linux-firmware \
        2>/dev/null || warn "Некоторые CachyOS пакеты не найдены (проверьте репо)"

    ok "Ядро CachyOS Bore установлено."

    # ─── GPU драйверы (автоопределение) ───
    header "Определение и установка GPU драйверов..."

    detect_and_install_gpu

    # ─── Все остальные пакеты (pacman) ───
    header "Установка всех pacman пакетов..."

    install_pacman_packages

    ok "Все pacman пакеты установлены."

    # ─── GRUB ───
    header "Установка и настройка GRUB..."

    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck

    # Настройка /etc/default/grub
    cat > /etc/default/grub << 'EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="CachyOS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 nowatchdog"
GRUB_CMDLINE_LINUX=""
GRUB_PRELOAD_MODULES="part_gpt part_msdos"
GRUB_TIMEOUT_STYLE=menu
GRUB_GFXMODE=1920x1080,auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_DISABLE_RECOVERY=true
EOF

    grub-mkconfig -o /boot/grub/grub.cfg

    ok "GRUB установлен и настроен."

    # ─── Службы ───
    header "Включение системных служб..."

    systemctl enable NetworkManager
    systemctl enable bluetooth
    systemctl enable sddm
    systemctl enable openssh
    systemctl enable power-profiles-daemon
    systemctl enable scx 2>/dev/null || warn "scx не найден, пропускаем"

    ok "Службы включены."

    # ─── SDDM настройка ───
    header "Настройка SDDM (Wayland + тема silent)..."

    mkdir -p /etc/sddm.conf.d
    cat > /etc/sddm.conf.d/default.conf << 'EOF'
[Theme]
Current=silent

[General]
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard

[Wayland]
CompositorCommand=weston --shell=kiosk
SessionDir=/usr/share/wayland-sessions
EOF

    # ─── Подготовка домашней папки пользователя ───
    header "Подготовка домашней папки..."

    # Копируем скрипт для пост-установки
    cp /install-arch.sh "/home/${USERNAME}/install-arch.sh"
    chmod +x "/home/${USERNAME}/install-arch.sh"

    # Копируем vars (без паролей root)
    cat > "/home/${USERNAME}/.install-vars.env" << EOF
USERNAME='${USERNAME}'
HOSTNAME='${HOSTNAME}'
DOTFILES_REPO='${DOTFILES_REPO}'
EOF
    chown "${USERNAME}:${USERNAME}" "/home/${USERNAME}/install-arch.sh" "/home/${USERNAME}/.install-vars.env"

    # ─── Установка yay (AUR helper) ───
    header "Установка yay..."

    # Устанавливаем как пользователь
    su - "${USERNAME}" -c "
        cd /tmp
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
    " || warn "yay не установлен — установите вручную: cd /tmp/yay && makepkg -si"

    # ─── AUR пакеты ───
    header "Установка AUR пакетов..."

    install_aur_packages

    # ─── Autologin для первого запуска (временно) ───
    # Раскомментируйте если хотите автологин:
    # mkdir -p /etc/sddm.conf.d
    # cat >> /etc/sddm.conf.d/default.conf << EOF
    # [Autologin]
    # User=${USERNAME}
    # Session=niri
    # EOF

    # ─── Очистка ───
    rm -f /install-vars.env /install-arch.sh

    ok "════════════════════════════════════════════"
    ok " CHROOT ФАЗА ЗАВЕРШЕНА!"
    ok " Выйдите из chroot, размонтируйте и перезагрузитесь"
    ok " После входа в систему: bash ~/install-arch.sh --deploy"
    ok "════════════════════════════════════════════"
}

# =============================================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (GPU, пакеты)
# =============================================================================

detect_and_install_gpu() {
    local vga
    vga=$(lspci 2>/dev/null | grep -iE "VGA|3D|Display" || true)

    info "Определено GPU: $vga"

    if echo "$vga" | grep -qi "AMD\|ATI"; then
        info "AMD GPU: устанавливаем mesa, vulkan-radeon, libva-mesa-driver..."
        pacman -S --noconfirm --needed \
            mesa vulkan-radeon libva-mesa-driver mesa-vdpau \
            vulkan-icd-loader lib32-mesa lib32-vulkan-radeon \
            xf86-video-amdgpu
        ok "AMD GPU драйверы установлены."

    elif echo "$vga" | grep -qi "Intel"; then
        info "Intel GPU: устанавливаем intel-media-driver, vulkan-intel..."
        pacman -S --noconfirm --needed \
            mesa vulkan-intel intel-media-driver \
            vulkan-icd-loader lib32-mesa lib32-vulkan-intel \
            xf86-video-intel
        ok "Intel GPU драйверы установлены."

    elif echo "$vga" | grep -qi "NVIDIA"; then
        info "NVIDIA GPU: устанавливаем nvidia драйверы..."
        pacman -S --noconfirm --needed \
            nvidia nvidia-utils lib32-nvidia-utils \
            vulkan-icd-loader
        # Для Wayland/Niri
        sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 nvidia-drm.modeset=1 nowatchdog"/' /etc/default/grub
        ok "NVIDIA GPU драйверы установлены."

    else
        warn "GPU не определён, устанавливаем mesa (универсально)..."
        pacman -S --noconfirm --needed mesa vulkan-icd-loader
    fi
}

install_pacman_packages() {
    # Пакеты сгруппированы — если один упадёт, остальные установятся
    local groups=(
        # Wayland стек
        "wayland niri sddm xwayland-satellite wl-clipboard cliphist"
        # Звук
        "pipewire pipewire-pulse wireplumber pavucontrol"
        # Утилиты
        "btop htop neofetch aria2 playerctl brightnessctl power-profiles-daemon libnotify matugen"
        # Терминал и шрифты
        "foot ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols-mono noto-fonts-emoji noto-fonts"
        # Файловый менеджер
        "nemo"
        # Браузер
        "firefox"
        # Медиа
        "mpv cava"
        # Pywal
        "python-pywal"
        # Qt6
        "qt6-5compat qt6-multimedia qt6-positioning qt6-sensors qt6-virtualkeyboard qt6-declarative"
        # Rofi
        "rofi"
        # Скриншоты
        "grim slurp"
        # Системные
        "upower acpi lm_sensors"
        # Дополнительно
        "nodejs npm blueberry nwg-look"
        # KDE зависимости для quickshell/vibepanel
        "kconfig kcoreaddons kdeclarative kiconthemes kirigami"
    )

    for group in "${groups[@]}"; do
        info "Устанавливаем: $group"
        # shellcheck disable=SC2086
        pacman -S --noconfirm --needed $group 2>/dev/null || warn "Некоторые пакеты из группы не найдены: $group"
    done
}

install_aur_packages() {
    if ! command -v yay &>/dev/null; then
        warn "yay не найден, пропускаем AUR пакеты."
        return
    fi

    local aur_groups=(
        # Браузер и мессенджер
        "zen-browser-bin ayugram-desktop"
        # Панель и уведомления
        "vibepanel-git swaync"
        # Обои
        "awww linux-wallpaperengine-git"
        # Музыка
        "sptlrx-bin waylyrics"
        # Терминальные украшения
        "unimatrix-git lavat genact tty-clock pipes.sh"
        # Курсор
        "xcursor-furina-git"
    )

    for group in "${aur_groups[@]}"; do
        info "AUR: устанавливаем $group"
        # shellcheck disable=SC2086
        su - "${USERNAME:-chezok}" -c "yay -S --noconfirm --needed $group 2>/dev/null" \
            || warn "Некоторые AUR пакеты не установлены: $group"
    done
}

# =============================================================================
# ФАЗА 3: ДЕПЛОЙ ДОТФАЙЛОВ (после перезагрузки, от пользователя)
# =============================================================================
phase_deploy() {
    header "CACHYOS INSTALLER — ФАЗА 3: ДЕПЛОЙ ДОТФАЙЛОВ"

    # Проверяем что мы пользователь, а не root
    if [[ "$EUID" -eq 0 ]]; then
        error "Запустите фазу деплоя от обычного пользователя: bash ~/install-arch.sh --deploy"
    fi

    source ~/.install-vars.env 2>/dev/null || true

    # ─── Клонируем репо с дотфайлами ───
    header "Клонирование репозитория дотфайлов..."

    if [[ -d "$DOTFILES_DIR" ]]; then
        info "Репозиторий уже существует. Обновляем..."
        git -C "$DOTFILES_DIR" pull
    else
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR" || {
            warn "Не удалось клонировать репо. Копируем из локального архива если есть..."
        }
    fi

    if [[ ! -d "$DOTFILES_DIR" ]]; then
        error "Репозиторий дотфайлов не найден! Сначала выполните: bash ~/install-arch.sh --github"
    fi

    # ─── Включение пользовательских служб ───
    header "Включение пользовательских служб..."

    systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber 2>/dev/null || true
    systemctl --user enable --now foot-server.socket 2>/dev/null || true

    # ─── Деплой дотфайлов ───
    deploy_dotfiles

    # ─── SDDM тема ───
    deploy_sddm_theme

    # ─── Zen Browser CSS ───
    deploy_zen_css

    # ─── xwayland-satellite ───
    deploy_xwayland_satellite

    # ─── Locale/User dirs ───
    header "Настройка директорий пользователя..."
    xdg-user-dirs-update 2>/dev/null || true

    # ─── Pywal первоначальная палитра ───
    header "Запуск pywal для генерации цветов..."
    if ls ~/67/*.jpg ~/67/*.png 2>/dev/null | head -1; then
        WALL=$(ls ~/67/*.jpg ~/67/*.png 2>/dev/null | shuf | head -1)
        wal -i "$WALL" --backend haishoku 2>/dev/null || wal -i "$WALL" 2>/dev/null || true
        ok "pywal запущен с обоями: $WALL"
    else
        warn "Обои не найдены в ~/67/ — запустите pywal вручную после установки"
    fi

    ok "════════════════════════════════════════════"
    ok " ДЕПЛОЙ ЗАВЕРШЁН!"
    ok " Перезагрузитесь или перезапустите SDDM:"
    ok "   sudo systemctl restart sddm"
    ok "════════════════════════════════════════════"
}

deploy_dotfiles() {
    header "Деплой конфигурационных файлов..."

    local df="$DOTFILES_DIR/dotfiles"
    local cfg="$HOME/.config"
    local bin="$HOME/.local/bin"

    mkdir -p "$cfg" "$bin" "$HOME/.local/share"

    # Функция безопасного копирования
    safe_copy() {
        local src="$1"
        local dst="$2"
        if [[ -e "$src" ]]; then
            mkdir -p "$(dirname "$dst")"
            cp -r "$src" "$dst"
            ok "Скопировано: $src → $dst"
        else
            warn "Источник не найден: $src"
        fi
    }

    # ─── Niri ───
    safe_copy "$df/niri" "$cfg/niri"
    # Меняем hardcoded пути с chezok на текущего пользователя
    if [[ "$USER" != "chezok" ]]; then
        find "$cfg/niri" -type f -exec sed -i "s|/home/chezok|/home/${USER}|g" {} +
    fi

    # ─── Vibepanel ───
    safe_copy "$df/vibepanel" "$cfg/vibepanel"

    # ─── Waybar ───
    safe_copy "$df/waybar" "$cfg/waybar"

    # ─── Foot terminal ───
    safe_copy "$df/foot" "$cfg/foot"

    # ─── Kitty ───
    safe_copy "$df/kitty" "$cfg/kitty"

    # ─── Cava ───
    safe_copy "$df/cava" "$cfg/cava"

    # ─── Matugen ───
    safe_copy "$df/matugen" "$cfg/matugen"

    # ─── Swaync ───
    safe_copy "$df/swaync" "$cfg/swaync"

    # ─── Rofi ───
    safe_copy "$df/rofi" "$cfg/rofi"

    # ─── GTK 3/4 ───
    safe_copy "$df/gtk-3.0" "$cfg/gtk-3.0"
    safe_copy "$df/gtk-4.0" "$cfg/gtk-4.0"

    # ─── Neofetch ───
    safe_copy "$df/neofetch" "$cfg/neofetch"

    # ─── Environment variables ───
    safe_copy "$df/environment.d" "$cfg/environment.d"

    # ─── sptlrx ───
    safe_copy "$df/sptlrx" "$cfg/sptlrx"

    # ─── waylyrics ───
    safe_copy "$df/waylyrics" "$cfg/waylyrics"

    # ─── Quickshell ───
    safe_copy "$df/quickshell" "$cfg/quickshell"

    # ─── Hypr (для скриптов, которые ссылаются на ~/.config/hypr) ───
    safe_copy "$df/hypr" "$cfg/hypr"

    # ─── Bashrc ───
    if [[ -f "$df/bash/.bashrc" ]]; then
        cp "$df/bash/.bashrc" "$HOME/.bashrc"
        ok "Скопировано: .bashrc"
    fi

    # ─── Скрипты (~/.local/bin) ───
    if [[ -d "$df/scripts" ]]; then
        cp -r "$df/scripts/." "$bin/"
        chmod +x "$bin/"*.sh "$bin/"*.py 2>/dev/null || true
        ok "Скопированы скрипты в ~/.local/bin"
    fi

    # ─── Обои (~/67/) ───
    if [[ -d "$df/wallpapers" ]]; then
        mkdir -p "$HOME/67"
        cp -r "$df/wallpapers/." "$HOME/67/"
        ok "Обои скопированы в ~/67/"
    fi

    # ─── Иконки ───
    if [[ -d "$df/themes/icons" ]]; then
        mkdir -p "$HOME/.local/share/icons"
        cp -r "$df/themes/icons/." "$HOME/.local/share/icons/"
        ok "Иконки скопированы"
    fi

    # ─── Курсор Furina ───
    if [[ -d "$df/themes/cursors" ]]; then
        mkdir -p "$HOME/.local/share/icons/Furina"
        cp -r "$df/themes/cursors/." "$HOME/.local/share/icons/Furina/"
        ok "Курсор Furina скопирован"
    fi

    # Обновляем GTK иконки
    if command -v gtk-update-icon-cache &>/dev/null; then
        gtk-update-icon-cache "$HOME/.local/share/icons" 2>/dev/null || true
    fi

    info "Дотфайлы задеплоены."
}

deploy_sddm_theme() {
    header "Установка SDDM темы 'silent'..."

    local src="$DOTFILES_DIR/themes/sddm/silent"
    local dst="/usr/share/sddm/themes/silent"

    if [[ -d "$src" ]]; then
        sudo mkdir -p "$dst"
        sudo cp -r "$src/." "$dst/"
        sudo chmod -R 755 "$dst"
        ok "SDDM тема 'silent' установлена."
    else
        warn "SDDM тема не найдена в репозитории дотфайлов. Установите вручную."
    fi

    # Конфигурация SDDM
    sudo mkdir -p /etc/sddm.conf.d
    sudo tee /etc/sddm.conf.d/default.conf > /dev/null << 'EOF'
[Theme]
Current=silent

[General]
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard

[Wayland]
CompositorCommand=weston --shell=kiosk
SessionDir=/usr/share/wayland-sessions
EOF
    ok "SDDM конфиг применён."
}

deploy_zen_css() {
    header "Настройка Zen Browser (userChrome.css)..."

    local zen_css_src="$DOTFILES_DIR/dotfiles/zen-css/userChrome.css"

    if [[ ! -f "$zen_css_src" ]]; then
        warn "userChrome.css не найден в репо."
        return
    fi

    # Находим профиль Zen Browser
    local zen_profiles_dir="$HOME/.config/zen"
    if [[ -d "$zen_profiles_dir" ]]; then
        local profile_dir
        profile_dir=$(find "$zen_profiles_dir" -maxdepth 1 -name "*.Default Profile" -type d | head -1)

        if [[ -n "$profile_dir" ]]; then
            mkdir -p "$profile_dir/chrome"
            cp "$zen_css_src" "$profile_dir/chrome/userChrome.css"
            ok "userChrome.css установлен в: $profile_dir/chrome/"
        else
            warn "Профиль Zen Browser не найден. Запустите Zen Browser первый раз, затем скопируйте вручную:"
            warn "  cp $zen_css_src ~/.config/zen/<ваш-профиль>/chrome/userChrome.css"
        fi
    else
        warn "Zen Browser ещё не запускался. После первого запуска выполните:"
        info "  mkdir -p ~/.config/zen/<профиль>/chrome"
        info "  cp $zen_css_src ~/.config/zen/<профиль>/chrome/userChrome.css"
    fi
}

deploy_xwayland_satellite() {
    header "Проверка xwayland-satellite..."

    # xwayland-satellite должен быть установлен через pacman
    if command -v xwayland-satellite &>/dev/null; then
        ok "xwayland-satellite найден в PATH."
        # Убеждаемся что niri config указывает на системный путь
        if [[ -f "$HOME/.config/niri/config.kdl" ]]; then
            local sys_path
            sys_path=$(which xwayland-satellite)
            sed -i "s|path \".*xwayland-satellite\"|path \"${sys_path}\"|g" "$HOME/.config/niri/config.kdl"
            ok "Путь к xwayland-satellite обновлён: $sys_path"
        fi
    else
        warn "xwayland-satellite не найден в PATH!"
        info "Установите: yay -S xwayland-satellite-git"
    fi
}

# =============================================================================
# ФАЗА 4: GITHUB — подготовка и push репозитория
# =============================================================================
phase_github() {
    header "CACHYOS INSTALLER — ФАЗА 4: ПОДГОТОВКА GITHUB РЕПОЗИТОРИЯ"

    if [[ "$EUID" -eq 0 ]]; then
        error "Запустите от пользователя, а не root!"
    fi

    local REPO_DIR="$HOME/dotfiles"

    # ─── Инициализация ───
    header "Инициализация репозитория..."

    mkdir -p "$REPO_DIR"
    cd "$REPO_DIR"

    if [[ ! -d ".git" ]]; then
        git init
        git checkout -b main
    fi

    # ─── Создаём структуру папок ───
    mkdir -p \
        dotfiles/niri \
        dotfiles/vibepanel \
        dotfiles/waybar \
        dotfiles/foot \
        dotfiles/kitty \
        dotfiles/cava \
        dotfiles/matugen \
        dotfiles/swaync \
        dotfiles/rofi \
        dotfiles/gtk-3.0 \
        dotfiles/gtk-4.0 \
        dotfiles/neofetch \
        dotfiles/environment.d \
        dotfiles/sptlrx \
        dotfiles/waylyrics \
        dotfiles/quickshell \
        dotfiles/hypr \
        dotfiles/zen-css \
        dotfiles/bash \
        dotfiles/scripts \
        dotfiles/wallpapers \
        themes/sddm \
        themes/icons \
        themes/cursors \
        packages

    # ─── Копируем конфиги ───
    header "Копирование конфигурационных файлов..."

    local cfg="$HOME/.config"
    local bin="$HOME/.local/bin"

    cp_config() {
        local src="$1"
        local dst="$2"
        if [[ -e "$src" ]]; then
            if [[ -d "$src" ]]; then
                cp -r "$src/." "$dst/"
            else
                cp "$src" "$dst"
            fi
            ok "✓ $src"
        else
            warn "✗ Не найдено: $src"
        fi
    }

    # Config dirs
    cp_config "$cfg/niri"           "dotfiles/niri/"
    cp_config "$cfg/vibepanel"      "dotfiles/vibepanel/"
    cp_config "$cfg/waybar"         "dotfiles/waybar/"
    cp_config "$cfg/foot"           "dotfiles/foot/"
    cp_config "$cfg/kitty"          "dotfiles/kitty/"
    cp_config "$cfg/cava"           "dotfiles/cava/"
    cp_config "$cfg/matugen"        "dotfiles/matugen/"
    cp_config "$cfg/swaync"         "dotfiles/swaync/"
    cp_config "$cfg/rofi"           "dotfiles/rofi/"
    cp_config "$cfg/gtk-3.0"        "dotfiles/gtk-3.0/"
    cp_config "$cfg/gtk-4.0"        "dotfiles/gtk-4.0/"
    cp_config "$cfg/neofetch"       "dotfiles/neofetch/"
    cp_config "$cfg/environment.d"  "dotfiles/environment.d/"
    cp_config "$cfg/sptlrx"         "dotfiles/sptlrx/"
    cp_config "$cfg/waylyrics"      "dotfiles/waylyrics/"
    cp_config "$cfg/quickshell"     "dotfiles/quickshell/"
    cp_config "$cfg/hypr"           "dotfiles/hypr/"

    # Zen Browser CSS (только userChrome.css, без личных данных!)
    local zen_profile
    zen_profile=$(find "$cfg/zen" -maxdepth 1 -name "*.Default Profile" -type d 2>/dev/null | head -1)
    if [[ -n "$zen_profile" && -f "$zen_profile/chrome/userChrome.css" ]]; then
        cp "$zen_profile/chrome/userChrome.css" "dotfiles/zen-css/userChrome.css"
        ok "✓ Zen Browser userChrome.css"
    fi

    # Bashrc
    cp_config "$HOME/.bashrc" "dotfiles/bash/.bashrc"

    # Скрипты (только bash/python, не бинарники)
    for f in "$bin"/*.sh "$bin"/*.py; do
        [[ -f "$f" ]] && cp "$f" "dotfiles/scripts/" && ok "✓ скрипт: $(basename "$f")"
    done
    # nemo скрипт (bash wrapper)
    [[ -f "$bin/nemo" ]] && cp "$bin/nemo" "dotfiles/scripts/"
    [[ -f "$bin/nightlight" ]] && cp "$bin/nightlight" "dotfiles/scripts/"
    [[ -f "$bin/wiki-stream" ]] && cp "$bin/wiki-stream" "dotfiles/scripts/wiki-stream.py"

    # Обои
    if [[ -d "$HOME/67" ]]; then
        info "Копирование обоев из ~/67/ (это может занять время — 254MB)..."
        cp -r "$HOME/67/." "dotfiles/wallpapers/"
        ok "✓ Обои скопированы"
    fi

    # SDDM тема
    if [[ -d "/usr/share/sddm/themes/silent" ]]; then
        sudo cp -r "/usr/share/sddm/themes/silent" "themes/sddm/"
        ok "✓ SDDM тема 'silent'"
    fi

    # Иконки (большой размер — будут в LFS или исключены)
    if [[ -d "$HOME/.local/share/icons/Tela-circle-wal" ]]; then
        info "Иконки Tela-circle-wal (112MB) — добавляем в Git LFS..."
        mkdir -p "themes/icons"
        cp -r "$HOME/.local/share/icons/Tela-circle-wal" "themes/icons/"
        ok "✓ Иконки Tela-circle-wal"
    fi

    # Курсор Furina
    if [[ -d "$HOME/.local/share/icons/Furina" ]]; then
        cp -r "$HOME/.local/share/icons/Furina" "themes/cursors/"
        ok "✓ Курсор Furina"
    fi

    # ─── Список пакетов ───
    header "Сохранение списка пакетов..."

    pacman -Qe > "packages/pacman.txt"
    yay -Qm > "packages/aur.txt" 2>/dev/null || true
    ok "Пакеты сохранены."

    # ─── .gitignore ───
    header "Создание .gitignore..."

    cat > .gitignore << 'EOF'
# Кэш и временные файлы
*.pyc
__pycache__/
.cache/
*.tmp
*.log

# Личные данные браузера (только CSS переносим!)
dotfiles/zen-css/*.json
dotfiles/zen-css/storage.js

# Большие бинарные файлы (устанавливаются через пакеты)
dotfiles/scripts/vibepanel
dotfiles/scripts/xwayland-satellite
dotfiles/scripts/foot
dotfiles/scripts/footclient
dotfiles/scripts/swaybg
dotfiles/scripts/wlsunset
dotfiles/scripts/gammastep
dotfiles/scripts/7z
dotfiles/scripts/7zz
dotfiles/scripts/nemo-archive-tool

# Дотфайлы с секретами
dotfiles/ssh/
.install-vars.env

# Git LFS tracking info (не игнорируем сами файлы, только атрибуты настроим отдельно)
EOF

    # ─── .gitattributes для LFS ───
    cat > .gitattributes << 'EOF'
# Обои и большие изображения — Git LFS
dotfiles/wallpapers/* filter=lfs diff=lfs merge=lfs -text
themes/icons/**/* filter=lfs diff=lfs merge=lfs -text
themes/sddm/silent/backgrounds/* filter=lfs diff=lfs merge=lfs -text
themes/cursors/**/* filter=lfs diff=lfs merge=lfs -text
EOF

    # ─── README ───
    generate_readme

    # ─── Git LFS ───
    if command -v git-lfs &>/dev/null; then
        git lfs install
        ok "Git LFS инициализирован."
    else
        warn "git-lfs не установлен! Установите: sudo pacman -S git-lfs"
        warn "Затем: cd ~/dotfiles && git lfs install"
    fi

    # ─── Первый коммит ───
    header "Создание первого коммита..."

    git add -A
    git commit -m "feat: initial dotfiles export from CachyOS ($(date +%Y-%m-%d))"

    # ─── Push ───
    header "Push на GitHub..."

    echo ""
    info "Для загрузки на GitHub:"
    info "1. Создайте репозиторий на github.com/chezok/dotfiles"
    info "2. Добавьте remote:"
    info "   git remote add origin git@github.com:chezok/dotfiles.git"
    info "3. Включите Git LFS в настройках репозитория на GitHub"
    info "4. Выполните push:"
    info "   git push -u origin main"
    echo ""

    read -rp "Введите GitHub remote URL (или нажмите Enter чтобы пропустить): " GH_REMOTE
    if [[ -n "$GH_REMOTE" ]]; then
        git remote add origin "$GH_REMOTE" 2>/dev/null || git remote set-url origin "$GH_REMOTE"
        git push -u origin main
        ok "Репозиторий загружен на GitHub!"
    fi

    ok "════════════════════════════════════════════"
    ok " РЕПОЗИТОРИЙ ГОТОВ: $REPO_DIR"
    ok " Команды для деплоя на новом PC:"
    ok "   git clone ${DOTFILES_REPO} ~/dotfiles"
    ok "   bash ~/install-arch.sh --deploy"
    ok "════════════════════════════════════════════"
}

generate_readme() {
    cat > README.md << 'MARKDOWN'
# CachyOS Dotfiles — chezok

Полная конфигурация рабочего стола на базе Arch Linux / CachyOS.

## 🖥️ Окружение

| Компонент | Значение |
|-----------|----------|
| Compositor | **Niri** (Wayland tiling, scrollable) |
| Ядро | **linux-cachyos-bore** |
| Shell | **bash** |
| Терминал | **foot** (socket mode) |
| Панель | **vibepanel** |
| Лаунчер | **rofi** |
| Уведомления | **swaync** |
| Обои | **awww** / **linux-wallpaperengine** |
| Цвета | **pywal** + **matugen** |
| Вход | **SDDM** (тема: silent, Wayland) |
| Браузер | **Zen Browser** |
| Мессенджер | **AyuGram** |
| GPU | AMD Radeon Vega Mobile (radeonsi/RADV) |

## 📦 Установка

### Шаг 1: Из Arch ISO
```bash
# Загружаетесь с Arch ISO
curl -L https://raw.githubusercontent.com/chezok/dotfiles/main/install-arch.sh -o install.sh
bash install.sh
# Отвечаете на вопросы (диск, пароли)
# После завершения: reboot
```

### Шаг 2: После первой загрузки
```bash
# Войдите как chezok
bash ~/install-arch.sh --deploy
```

## 🗂️ Структура

```
dotfiles/
├── niri/              # ~/.config/niri (compositor + все скрипты)
├── vibepanel/         # ~/.config/vibepanel (панель)
├── foot/              # ~/.config/foot (терминал)
├── kitty/             # ~/.config/kitty (альтернативный терминал)
├── cava/              # ~/.config/cava (визуализатор аудио)
├── rofi/              # ~/.config/rofi (лаунчер)
├── swaync/            # ~/.config/swaync (уведомления)
├── waybar/            # ~/.config/waybar (waybar конфиги)
├── matugen/           # ~/.config/matugen (генерация Material You цветов)
├── quickshell/        # ~/.config/quickshell (виджеты)
├── hypr/              # ~/.config/hypr (для скриптов, ссылающихся на этот путь)
├── gtk-3.0/           # GTK3 тема
├── gtk-4.0/           # GTK4 тема
├── neofetch/          # neofetch конфиг
├── environment.d/     # Переменные окружения
├── sptlrx/            # sptlrx (lyrics)
├── waylyrics/         # waylyrics
├── zen-css/           # Zen Browser userChrome.css (только стили!)
├── bash/              # .bashrc
├── scripts/           # ~/.local/bin скрипты (bash/python)
└── wallpapers/        # ~/67/ (обои, LFS)
themes/
├── sddm/silent/       # SDDM тема
├── icons/             # ~/.local/share/icons (LFS)
└── cursors/           # Курсор Furina (LFS)
packages/
├── pacman.txt         # pacman -Qe
└── aur.txt            # yay -Qm
```

## ⌨️ Хоткеи Niri

| Хоткей | Действие |
|--------|----------|
| `Mod+Q` | Новый терминал (foot) |
| `Mod+R` | Rofi (лаунчер) |
| `Mod+E` | Nemo (файловый менеджер) |
| `Mod+W` | Выбор обоев |
| `Mod+A` | Переключить cava |
| `Mod+N` | Панель управления |
| `Mod+O` | Overview (обзор) |
| `Mod+H/J/K/L` | Навигация (vim-style) |
| `Mod+C` | Закрыть окно |
| `Mod+F` | Максимизировать колонку |
| `Mod+Shift+F` | Полный экран |
| `Mod+V` | Toggle floating |
| `Print` / `Mod+Shift+S` | Скриншот |
| `Mod+1..9` | Переключить workspace |

## 🎨 Цветовая схема

Динамически генерируется через **pywal** + **matugen** из текущих обоев.
Цвета применяются к: foot, Zen Browser, GTK3/4, quickshell виджетам.

## 📝 Заметки

- Обои хранятся в `~/67/` (*.jpg, *.png, *.gif, *.mp4 для wallpaperengine)
- Скрипт выбора обоев: `~/.config/niri/scripts/wallpaper-selector.sh`
- Цветовой демон: `~/.config/niri/scripts/wallpaper-color-watcher.sh`
- Vibepanel бинарник устанавливается через AUR: `vibepanel-git`
- SDDM тема `silent` устанавливается автоматически скриптом

## 🔧 Устранение проблем

**Чёрный экран при входе**: проверьте `/var/log/sddm.log`

**Vibepanel не запускается**: `yay -S vibepanel-git`

**Обои не применяются**: `~/.config/niri/scripts/restore-wallpaper.sh`

**pywal не генерирует цвета**: `wal -i ~/67/<обои>.jpg`
MARKDOWN

    ok "README.md создан."
}

# =============================================================================
# ТОЧКА ВХОДА
# =============================================================================
main() {
    case "${1:-}" in
        --chroot)  phase_chroot  ;;
        --deploy)  phase_deploy  ;;
        --github)  phase_github  ;;
        "")        phase_install ;;
        *)
            echo "Использование: $0 [--chroot|--deploy|--github]"
            echo ""
            echo "  (без флага)  — Фаза 1: из Arch ISO (разбивка, pacstrap, chroot)"
            echo "  --chroot     — Фаза 2: внутри chroot (вызывается автоматически)"
            echo "  --deploy     — Фаза 3: деплой дотфайлов (после перезагрузки)"
            echo "  --github     — Фаза 4: подготовка и push на GitHub"
            exit 1
            ;;
    esac
}

main "$@"
