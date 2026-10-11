#!/usr/bin/env bash
# =============================================================================
# Universal GRUB Theme Installer: Asuka (Evangelion)
# Works on any Arch/CachyOS system, any resolution, any user
# =============================================================================
set -euo pipefail

THEME_NAME="asuka"
THEME_DEST="/boot/grub/themes/${THEME_NAME}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Установка темы GRUB Asuka ==="

# 1. Проверяем источник файлов темы
if [[ ! -f "${SCRIPT_DIR}/theme.txt" ]]; then
    if [[ -d "/home/${SUDO_USER:-$USER}/.local/share/grub-themes/asuka" ]]; then
        SCRIPT_DIR="/home/${SUDO_USER:-$USER}/.local/share/grub-themes/asuka"
    else
        echo "Ошибка: файлы темы не найдены в ${SCRIPT_DIR}" >&2
        exit 1
    fi
fi

# 2. Копируем файлы темы
echo "Копирование темы в ${THEME_DEST}..."
mkdir -p "${THEME_DEST}"
cp -a "${SCRIPT_DIR}"/* "${THEME_DEST}"/
rm -f "${THEME_DEST}/install-asuka.sh"

# 3. Гарантируем наличие иконки для CachyOS
if [[ -f "${THEME_DEST}/icons/archlinux.png" ]] && [[ ! -f "${THEME_DEST}/icons/cachyos.png" ]]; then
    cp "${THEME_DEST}/icons/archlinux.png" "${THEME_DEST}/icons/cachyos.png"
fi

# 4. Определение разрешения экрана и адаптация фона
DETECTED_RES=""
for m in /sys/class/drm/card*-*/modes; do
    res="$(head -n 1 "$m" 2>/dev/null || true)"
    if [[ -n "$res" ]]; then
        DETECTED_RES="$res"
        break
    fi
done

if [[ -n "$DETECTED_RES" ]]; then
    TARGET_GFXMODE="${DETECTED_RES},auto"
    echo "Определено нативное разрешение дисплея: ${DETECTED_RES}"
    if command -v magick &>/dev/null && [[ -f "${THEME_DEST}/background.png" ]]; then
        echo "Адаптация фонового изображения под ${DETECTED_RES}..."
        magick "${THEME_DEST}/background.png" -resize "${DETECTED_RES}^" -gravity center -extent "${DETECTED_RES}" "${THEME_DEST}/background.png" 2>/dev/null || true
    fi
else
    TARGET_GFXMODE="1920x1080,auto"
    echo "Нативное разрешение не определено, используется: ${TARGET_GFXMODE}"
fi

# 5. Определение системного шрифта для GRUB_FONT
TARGET_FONT="/boot/grub/fonts/unicode.pf2"
if [[ ! -f "$TARGET_FONT" ]]; then
    if [[ -f "/usr/share/grub/unicode.pf2" ]]; then
        mkdir -p /boot/grub/fonts
        cp /usr/share/grub/unicode.pf2 "$TARGET_FONT"
    elif [[ -f "${THEME_DEST}/JetBrainsMono_20.pf2" ]]; then
        TARGET_FONT="${THEME_DEST}/JetBrainsMono_20.pf2"
    fi
fi

# 6. Копирование шрифтов на ESP-раздел в качестве fallback для UEFI
if [[ -f "/boot/grub/fonts/unicode.pf2" ]]; then
    for esp_dir in /boot/efi/EFI/BOOT/fonts /boot/efi/EFI/fonts /boot/efi/fonts /boot/efi/grub/fonts /boot/EFI/BOOT/fonts; do
        if [[ -d "$(dirname "$esp_dir")" ]]; then
            mkdir -p "$esp_dir" 2>/dev/null || true
            cp "/boot/grub/fonts/unicode.pf2" "${esp_dir}/unicode.pf2" 2>/dev/null || true
            cp -a "${THEME_DEST}"/*.pf2 "${esp_dir}"/ 2>/dev/null || true
        fi
    done
fi

# 7. Бэкап /etc/default/grub
if [[ ! -f /etc/default/grub.bak ]]; then
    cp /etc/default/grub /etc/default/grub.bak 2>/dev/null || true
    echo "Бэкап сохранен в /etc/default/grub.bak"
fi

# 8. Настройка /etc/default/grub
echo "Настройка параметров в /etc/default/grub..."

# Установка GRUB_THEME
if grep -q "^GRUB_THEME=" /etc/default/grub; then
    sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"${THEME_DEST}/theme.txt\"|" /etc/default/grub
elif grep -q "^#GRUB_THEME=" /etc/default/grub; then
    sed -i "s|^#GRUB_THEME=.*|GRUB_THEME=\"${THEME_DEST}/theme.txt\"|" /etc/default/grub
else
    echo "GRUB_THEME=\"${THEME_DEST}/theme.txt\"" >> /etc/default/grub
fi

# Установка GRUB_GFXMODE
if grep -q "^GRUB_GFXMODE=" /etc/default/grub; then
    sed -i "s|^GRUB_GFXMODE=.*|GRUB_GFXMODE=\"${TARGET_GFXMODE}\"|" /etc/default/grub
else
    echo "GRUB_GFXMODE=\"${TARGET_GFXMODE}\"" >> /etc/default/grub
fi

# Установка GRUB_GFXPAYLOAD_LINUX=keep
if grep -q "^GRUB_GFXPAYLOAD_LINUX=" /etc/default/grub; then
    sed -i "s|^GRUB_GFXPAYLOAD_LINUX=.*|GRUB_GFXPAYLOAD_LINUX=keep|" /etc/default/grub
elif grep -q "^#GRUB_GFXPAYLOAD_LINUX=" /etc/default/grub; then
    sed -i "s|^#GRUB_GFXPAYLOAD_LINUX=.*|GRUB_GFXPAYLOAD_LINUX=keep|" /etc/default/grub
else
    echo "GRUB_GFXPAYLOAD_LINUX=keep" >> /etc/default/grub
fi

# Установка GRUB_FONT
if [[ -n "$TARGET_FONT" ]]; then
    if grep -q "^GRUB_FONT=" /etc/default/grub; then
        sed -i "s|^GRUB_FONT=.*|GRUB_FONT=\"${TARGET_FONT}\"|" /etc/default/grub
    elif grep -q "^#GRUB_FONT=" /etc/default/grub; then
        sed -i "s|^#GRUB_FONT=.*|GRUB_FONT=\"${TARGET_FONT}\"|" /etc/default/grub
    else
        echo "GRUB_FONT=\"${TARGET_FONT}\"" >> /etc/default/grub
    fi
fi

# Отключаем чисто консольный режим
sed -i 's|^GRUB_TERMINAL_OUTPUT=console|#GRUB_TERMINAL_OUTPUT=console|' /etc/default/grub 2>/dev/null || true
sed -i 's|^GRUB_TERMINAL_INPUT=console|#GRUB_TERMINAL_INPUT=console|' /etc/default/grub 2>/dev/null || true

# 9. Генерация grub.cfg
echo "Обновление /boot/grub/grub.cfg..."
grub-mkconfig -o /boot/grub/grub.cfg

echo "=== Готово! Тема Asuka успешно установлена в GRUB ==="
