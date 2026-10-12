#!/usr/bin/env bash
# =============================================================================
# Исправление GRUB: удаление лишних пунктов меню и фикс маленького окна загрузки
# Работает на Arch Linux / CachyOS (как на Lenovo G500, так и на IdeaPad)
# =============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "Этот скрипт должен быть запущен с правами root (sudo)!" >&2
   exit 1
fi

echo "=== 1. Очистка меню GRUB от мусора и лишних пунктов ==="

# 1.1 Отключаем 25_bli и 31_efi_bootnext (убирает мусорные записи 'EFI BootNext: EFI HDD Device', 'EFI USB Device')
if [[ -f /etc/grub.d/25_bli ]]; then
    echo "Отключение 25_bli..."
    chmod -x /etc/grub.d/25_bli
fi
if [[ -f /etc/grub.d/31_efi_bootnext ]]; then
    echo "Отключение 31_efi_bootnext (убирает дублирующиеся EFI диски)..."
    chmod -x /etc/grub.d/31_efi_bootnext
fi

# 1.2 Отключаем 30_uefi-firmware (убирает пункт 'UEFI Firmware Settings' из списка ОС)
if [[ -f /etc/grub.d/30_uefi-firmware ]]; then
    echo "Отключение 30_uefi-firmware..."
    chmod -x /etc/grub.d/30_uefi-firmware
fi

# 1.3 Настройка /etc/default/grub для чистого меню
echo "Настройка параметров отображения в /etc/default/grub..."

# Отключаем режим восстановления (убирает fallback/recovery дубли)
if grep -q "^GRUB_DISABLE_RECOVERY=" /etc/default/grub; then
    sed -i 's|^GRUB_DISABLE_RECOVERY=.*|GRUB_DISABLE_RECOVERY=true|' /etc/default/grub
else
    echo 'GRUB_DISABLE_RECOVERY=true' >> /etc/default/grub
fi

# Прячем дополнительные ядра и fallback в аккуратное подменю, не засоряя главный экран
if grep -q "^GRUB_DISABLE_SUBMENU=" /etc/default/grub; then
    sed -i 's|^GRUB_DISABLE_SUBMENU=.*|#GRUB_DISABLE_SUBMENU=y|' /etc/default/grub
fi

# Отключаем сканирование os-prober (если нужна только основная система)
if grep -q "^GRUB_DISABLE_OS_PROBER=" /etc/default/grub; then
    sed -i 's|^GRUB_DISABLE_OS_PROBER=.*|GRUB_DISABLE_OS_PROBER=true|' /etc/default/grub
else
    echo 'GRUB_DISABLE_OS_PROBER=true' >> /etc/default/grub
fi

echo "=== 2. Исправление маленького окна экрана загрузки (Plymouth/KMS) ==="
# Причина маленького окна: GRUB_GFXPAYLOAD_LINUX=keep передает ядру режим 1024x768 из старого UEFI GOP,
# из-за чего экран загрузки рисуется в маленьком квадрате в центре с черными полями,
# пока драйвер видеокарты не переключит матрицу на нативные 1366x768/1920x1080.

# 2.1 Убираем принудительный keep
sed -i 's|^GRUB_GFXPAYLOAD_LINUX=keep|#GRUB_GFXPAYLOAD_LINUX=keep|' /etc/default/grub 2>/dev/null || true

# 2.2 Настройка Early KMS в mkinitcpio (ранняя инициализация видеодрайвера)
GPU_MODULE=""
if lspci | grep -iE "vga|3d|display" | grep -iq "intel"; then
    GPU_MODULE="i915"
elif lspci | grep -iE "vga|3d|display" | grep -iq "amd"; then
    GPU_MODULE="amdgpu"
fi

if [[ -n "$GPU_MODULE" ]] && [[ -f /etc/mkinitcpio.conf ]]; then
    if ! grep -q "$GPU_MODULE" /etc/mkinitcpio.conf; then
        echo "Включение Early KMS ($GPU_MODULE) в /etc/mkinitcpio.conf..."
        sed -i "s|^MODULES=(\(.*\))|MODULES=($GPU_MODULE \1)|" /etc/mkinitcpio.conf
        # Убираем двойные пробелы если появились
        sed -i 's/  */ /g' /etc/mkinitcpio.conf
        echo "Пересборка initramfs для нативного разрешения при старте..."
        mkinitcpio -P
    fi
fi

# 2.3 Перегенерация конфигурации GRUB
echo "=== 3. Генерация чистого /boot/grub/grub.cfg ==="
grub-mkconfig -o /boot/grub/grub.cfg

echo "=== Готово! Лишние пункты удалены, экран загрузки настроен на полный экран ==="
