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
