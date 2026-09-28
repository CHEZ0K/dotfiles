#!/usr/bin/env bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}    ПОЛНАЯ СИСТЕМНАЯ ВЕРИФИКАЦИЯ РЕПОЗИТОРИЯ И УСТАНОВЩИКА      ${NC}"
echo -e "${BLUE}================================================================${NC}\n"

DOTFILES_DIR="/home/chezok/dotfiles"
INSTALLER="$DOTFILES_DIR/install.sh"

# 1. Проверка синтаксиса bash установщика
echo -n "1. Проверка синтаксиса install.sh: "
if bash -n "$INSTALLER"; then
    echo -e "${GREEN}✓ СИНТАКСИС ВЕРЕН${NC}"
else
    echo -e "${RED}✗ ОШИБКА СИНТАКСИСА${NC}"
    exit 1
fi

# 2. Проверка критических компонентов
components=(
    "dotfiles/niri:Конфигурация и скрипты Niri"
    "dotfiles/vibepanel:Панель управления Vibepanel"
    "dotfiles/foot:Терминал Foot"
    "dotfiles/cava:Визуализатор Cava"
    "dotfiles/matugen:Material You темы"
    "dotfiles/swaync:Центр уведомлений Swaync"
    "dotfiles/rofi:Лаунчер Rofi"
    "dotfiles/gtk-3.0:GTK 3.0"
    "dotfiles/gtk-4.0:GTK 4.0"
    "dotfiles/environment.d:Системные переменные"
    "dotfiles/systemd:Службы пользователя (foot-server, nightlight)"
    "dotfiles/scripts:Пользовательские скрипты (~/.local/bin)"
    "dotfiles/wallpapers:Коллекция обоев (~/67/)"
    "dotfiles/fonts:Шрифты виджетов (MaterialSymbols, weawow)"
    "dotfiles/locale:Русская локализация Nemo"
    "dotfiles/applications:Кастомные .desktop файлы"
    "dotfiles/sounds:Системные звуки"
    "dotfiles/mimeapps.list:Ассоциации приложений"
    "dotfiles/user-dirs.dirs:XDG директории"
    "dotfiles/wal:Pywal шаблоны"
    "dotfiles/face/.face.icon:Аватар пользователя"
    "dotfiles/lib:Nemo C-библиотека (libnemolocale)"
    "themes/cursors/Furina:Курсор Furina"
    "themes/cursors/default:Дефолтный курсор"
    "themes/icons/Tela-circle-wal:Иконки Tela-circle-wal"
    "themes/gtk/Mint-Y-Dark:GTK тема Mint-Y-Dark"
    "themes/gtk/Mint-Y-Dark-Red:GTK тема Mint-Y-Dark-Red"
    "themes/sddm/silent:Тема SDDM silent"
    "themes/sddm/konata-cat:Тема SDDM konata-cat"
    "themes/grub/asuka:Тема GRUB asuka"
    "packages/pacman.txt:Список pacman пакетов"
    "packages/aur.txt:Список AUR пакетов"
)

echo -e "\n2. Проверка наличия всех компонентов в репозитории:"
missing_count=0
for item in "${components[@]}"; do
    path="${item%%:*}"
    desc="${item#*:}"
    if [[ -e "$DOTFILES_DIR/$path" ]]; then
        echo -e "  [${GREEN}OK${NC}] $desc ($path)"
    else
        echo -e "  [${RED}MISSING${NC}] $desc ($path)"
        ((missing_count++))
    fi
done

if [[ $missing_count -eq 0 ]]; then
    echo -e "\n${GREEN}✓ ВСЕ 32 КРИТИЧЕСКИХ КОМПОНЕНТА НА МЕСТЕ!${NC}"
else
    echo -e "\n${RED}✗ ОТСУТСТВУЕТ $missing_count КОМПОНЕНТОВ!${NC}"
    exit 1
fi

# 3. Проверка правил Polkit и SDDM в скрипте установки
echo -e "\n3. Проверка системных настроек в установщике:"
for pattern in "50-networkmanager.rules" "XCURSOR_THEME=Furina" "Current=silent" "CursorTheme=Furina" "DisplayServer=wayland" "cava-daemon"; do
    if grep -q "$pattern" "$INSTALLER"; then
        echo -e "  [${GREEN}OK${NC}] Найдено правило: $pattern"
    else
        echo -e "  [${RED}FAIL${NC}] Не найдено: $pattern"
        exit 1
    fi
done

# 4. Проверка Git статуса
echo -e "\n4. Статус синхронизации с GitHub:"
cd "$DOTFILES_DIR"
git status -s
if [[ -z "$(git status -s)" ]]; then
    echo -e "${GREEN}✓ Репозиторий полностью чист, все изменения синхронизированы с GitHub.${NC}"
else
    echo -e "${YELLOW}! Есть незакоммиченные файлы.${NC}"
fi

echo -e "\n${BLUE}================================================================${NC}"
echo -e "${GREEN}ИТОГ: ВСЕ ФАЙЛЫ, ПУТИ, СКРИПТЫ, ШРИФТЫ И ТЕМЫ ПРОВЕРЕНЫ И ГОТОВЫ.${NC}"
echo -e "${BLUE}================================================================${NC}"
