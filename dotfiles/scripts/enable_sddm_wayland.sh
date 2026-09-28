#!/usr/bin/env bash
set -e

echo "=== Настройка SDDM на Wayland ==="

if [[ $EUID -ne 0 ]]; then
    echo "Пожалуйста, запустите этот скрипт с sudo:"
    echo "sudo ~/.local/bin/enable_sddm_wayland.sh"
    exit 1
fi

echo "1. Установка Weston (композитор для экрана входа SDDM Wayland)..."
pacman -S --needed --noconfirm weston

echo "2. Создание конфигурации /etc/sddm.conf.d/wayland.conf..."
mkdir -p /etc/sddm.conf.d
cat << 'CONF' > /etc/sddm.conf.d/wayland.conf
[General]
DisplayServer=wayland

[Wayland]
CompositorCommand=weston --shell=kiosk
CONF

echo "=== Готово! SDDM переведён на Wayland. ==="
echo "Для проверки можно перезапустить sddm: sudo systemctl restart sddm"
echo "(или перезагрузить компьютер: reboot)"
