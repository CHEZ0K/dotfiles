#!/usr/bin/env bash
# Запуск темы SilentSDDM (rei.conf с котиком и Конатой) в отдельном окне
cd /home/chezok/.local/share/sddm/themes/silent
QT_IM_MODULE=qtvirtualkeyboard QML2_IMPORT_PATH=./components/ sddm-greeter-qt6 --test-mode --theme .
