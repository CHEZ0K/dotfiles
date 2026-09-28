#!/usr/bin/env bash
set -e

echo "=== Настройка прав NetworkManager для пользователя chezok ==="

if [[ $EUID -ne 0 ]]; then
    echo "Пожалуйста, запустите этот скрипт с sudo:"
    echo "sudo ~/.local/bin/fix_wifi_permissions.sh"
    exit 1
fi

# 1. Добавление пользователя в группу wheel
echo "1. Добавление пользователя chezok в группу wheel..."
usermod -aG wheel chezok

# 2. Создание правила Polkit для полного управления NetworkManager без запроса root
echo "2. Создание правила Polkit /etc/polkit-1/rules.d/50-networkmanager.rules..."
mkdir -p /etc/polkit-1/rules.d
cat << 'RULE' > /etc/polkit-1/rules.d/50-networkmanager.rules
/* Разрешить пользователю chezok управление NetworkManager без пароля root */
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.NetworkManager.") === 0 && subject.user === "chezok") {
        return polkit.Result.YES;
    }
});
RULE

# 3. Удаление битых дубликатов профиля '1 1'
echo "3. Очистка повреждённых дубликатов подключений..."
rm -f "/etc/NetworkManager/system-connections/1 1.nmconnection" 2>/dev/null || true
nmcli connection reload 2>/dev/null || true

echo "=== Готово! Права на управление Wi-Fi и сохранение паролей настроены. ==="
