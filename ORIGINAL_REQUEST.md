# Original User Request

## Initial Request — 2026-09-30T20:56:29Z

Автоматизация и верификация скрипта установки Arch Linux / CachyOS (Niri + Hyprland + Vibepanel + дотфайлы), точно повторяющего установленную у пользователя систему, с устранением сбоев UEFI/GRUB и сети в chroot, а также сквозным тестированием в виртуальной машине (QEMU).

Working directory: /home/chezok/dotfiles
Integrity mode: development

## Requirements

### R1. Полная синхронизация пакетов с текущей системой пользователя
Скрипт должен устанавливать ровно тот набор пакетов, который сейчас реально работает в системе пользователя (согласно `pacman -Qe`), без мусорных, устаревших или тяжеловесных пакетов, требующих долгой компиляции:
- Ядро: `linux-cachyos-bore`, `linux-cachyos-bore-headers`, `cachyos-settings`, `scx-scheds`.
- Графика: Intel Ivy Bridge (`mesa`, `xf86-video-intel`, `vulkan-intel`).
- Wayland/Окружения: Niri (`niri`, `xwayland-satellite`), Hyprland (`hyprland`), SDDM (`sddm`), `quickshell`, `vibepanel-git`, `swaync`, `awww`, `waybar`.
- Сеть и звук: `bluez`, `bluez-utils`, `networkmanager`, `pipewire`, `wireplumber`, `pavucontrol`.
- Софт и утилиты: `zen-browser-bin`, `ayugram-desktop-bin` (бинарники из AUR), `foot`, `nemo`, `udisks2`, `udiskie`, `ntfs-3g`, `dosfstools`, `exfatprogs`.

### R2. Гарантия сетевого разрешения в chroot и надежная сборка yay
Перед запуском любых сетевых команд и сборки `yay` внутри chroot:
- Убедиться, что `/etc/resolv.conf` внутри `/mnt` валиден (при необходимости записать публичные DNS `1.1.1.1` и `8.8.8.8`, чтобы исключить ошибку `Could not resolve host`).
- Настроить временные права для пользователя `nobody` или созданного пользователя `chezok` в `sudoers` без пароля для корректной сборки `makepkg` и `yay`.

### R3. Исправление загрузчика GRUB для UEFI (решение проблемы видимости диска)
- Использовать флаги `grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck --removable`. Флаг `--removable` обязателен: он копирует бинарник загрузчика в `/EFI/BOOT/BOOTX64.EFI`, благодаря чему UEFI BIOS материнской платы (особенно на ноутбуках Ivy Bridge/Pentium 2020M) видит диск в списке загрузки, даже если BIOS игнорирует записи NVRAM efibootmgr.

### R4. Тестирование и верификация установки в виртуальной машине (QEMU/KVM)
- Развернуть виртуальный тестовый стенд с QEMU (`qemu-system-x86_64` с поддержкой OVMF/UEFI).
- Запустить процесс установки на виртуальный образ диска.
- Проанализировать логи, убедиться в отсутствии сбоев на всех этапах (разметка, форматирование, pacstrap, chroot, cachyos repo, yay, grub).
- Проверить успешный запуск созданной системы из GRUB в QEMU в режиме UEFI.

## Acceptance Criteria

### Boot & UEFI
- [ ] Диск распознается UEFI BIOS (файл `BOOTX64.EFI` присутствует в `/boot/efi/EFI/BOOT/BOOTX64.EFI`).
- [ ] GRUB меню успешно генерируется и загружает ядро `linux-cachyos-bore`.

### Network & AUR
- [ ] DNS внутри chroot работает стабильно, `yay` клонируется и компилируется без сетевых ошибок (`Could not resolve host`).
- [ ] Пакеты `ayugram-desktop-bin` и `zen-browser-bin` устанавливаются как бинарные пакеты.

### System Verification
- [ ] Сквозной прогон установки в QEMU UEFI завершается без ошибок (`exit code 0`).
- [ ] Все службы (`NetworkManager`, `bluetooth`, `sddm`, `udisks2`) включены и стартуют.


## Follow-up — 2026-10-09T20:37:09Z

Продолжение работы над проектом: Arch Linux / CachyOS Installer Automation & QEMU Verification.

Предыдущий прогресс сохранен в директории: /home/chezok/dotfiles/.agents/
Файлы проекта:
- Архитектура и задачи: /home/chezok/dotfiles/.agents/PROJECT.md
- Тестовая инфраструктура: /home/chezok/dotfiles/.agents/TEST_INFRA.md
- Готовые сформулированные патчи и скрипты:
  * /home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_1/m1_packages_and_configs.patch
  * /home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_2/r2_network_sudoers.patch
  * /home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_3/grub_and_automation.patch
  * /home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_3/proposed_install-arch.sh

Важное уточнение от пользователя:
- SDDM оставляем как есть (не удалять и не заменять).
- Значок монтирования флешек (udiskie tray) уже отключен (--no-tray) и дубликат убран.
- В Niri уже добавлено правило с xray false для Vibepanel.

Текущая задача для команды:
1. Завершить Milestone 1: применить обновления в install-arch.sh и install.sh:
   - Полная синхронизация пакетов с реальной системой (CachyOS Bore, Intel Ivy Bridge драйверы, Niri, Hyprland, Waybar, Vibepanel, SDDM, Zen Browser, AyuGram и др.).
   - DNS resolv.conf (1.1.1.1, 8.8.8.8) и беспарольный sudo для сборки yay в chroot.
   - grub-install с обязательным флагом --removable для fallback UEFI (BOOTX64.EFI).
   - Поддержка неинтерактивного режима AUTORUN=1.
2. Провести Milestone 2: QEMU виртуальный стенд с UEFI (OVMF):
   - Запустить сквозное тестирование установки на виртуальный диск.
   - Проверить логи и подтвердить загрузку установленной системы.
3. Проверить Acceptance Criteria и зафиксировать финальный результат в git.
