#!/usr/bin/env bash
set -e
echo "=== Установка темы SDDM konata-cat в систему ==="
sudo mkdir -p /usr/share/sddm/themes
sudo rm -rf /usr/share/sddm/themes/konata-cat
sudo cp -r /home/chezok/.local/share/sddm/themes/konata-cat /usr/share/sddm/themes/
sudo mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=konata-cat" | sudo tee /etc/sddm.conf.d/theme.conf
echo "=== Готово! Тема konata-cat установлена и активирована в /etc/sddm.conf.d/theme.conf ==="
