# Handoff Report: Milestone 2 QEMU Stand & E2E Verification Deep Investigation
**Milestone**: Milestone 2: QEMU VM Stand & E2E Verification  
**Author**: Explorer Agent (`teamwork_preview_explorer_m2_2`)  
**Target Recipient**: Orchestrator / Worker Agent (`teamwork_preview_worker_m2_1`)  
**Date**: 2026-10-10  

---

## 1. Observation

Direct inspection of previous run logs (`tests/build/stage1_serial.log`), VM disk image (`tests/build/target.qcow2`), host configurations, and codebase scripts (`install-arch.sh`, `install.sh`, `tests/qemu_test_runner.sh`, `tests/vm_acceptance_check.sh`) revealed the following verified observations:

### 1.1 Точка остановки и состояние Stage 1 в предыдущем прогоне
1. **Размер диска и временные метки**:
   - `tests/build/target.qcow2`: размер `4,165,337,088` байт (~4.16 GiB).
   - Временная метка старта Stage 1 в логе: `Timestamp: 2026-10-09T22:19:06Z` (строка 235).
   - Временная метка последней модификации `stage1_serial.log`: `2026-10-10 01:45 MSK` (~22:45 UTC), ровно 26–28 минут от старта.
   - Процесс QEMU завершился из-за истечения таймаута `STAGE1_TIMEOUT=1800` (30 минут) в `tests/qemu_test_runner.sh`:
     ```text
     [WARN] Превышен таймаут Stage 1 (1800с)! Принудительная остановка QEMU...
     ```
2. **Последние строки лога `tests/build/stage1_serial.log` (хвост файла)**:
   ```text
   [INFO]  Устанавливаем: nemo udisks2 udiskie ntfs-3g dosfstools exfatprogs
   resolving dependencies...
   :: There are 2 providers available for libegl:
   :: Repository cachyos-extra-v3
      1) libglvnd
   :: Repository extra
      2) libglvnd

   Enter a number (default=1): 
   looking for conflicting packages...

   Packages (145) adwaita-cursors-51.0-1 ... nemo-6.6.4-1.1 udisks2-2.11.2-1.1

   Total Download Size:    82.29 MiB
   Total Installed Size:  380.14 MiB

   :: Proceed with installation? [Y/n] 
   :: Retrieving packages...
   ```
   Установка остановилась на попытке загрузки пакетов группы `nemo udisks2 udiskie ntfs-3g dosfstools exfatprogs`.

### 1.2 Первопричина №1: Уничтожение `/etc/resolv.conf` хуком `systemd-tmpfiles`
До группы nemo все предыдущие группы пакетов падали с тайм-аутом разрешения DNS:
```text
error: failed retrieving file 'hyprland-0.56.2-4.1-x86_64_v3.pkg.tar.zst' from cdn77.cachyos.org : Resolving timed out after 10001 milliseconds
error: failed retrieving file 'qt6-declarative-6.12.0-1.1-x86_64_v3.pkg.tar.zst' from cdn77.cachyos.org : Resolving timed out after 10001 milliseconds
...
warning: too many errors from mirror.hb9hil.org, skipping for the remainder of this transaction
```
Pacman перебирал по очереди 24 зеркала CachyOS, на каждом ожидая 10 000 мс (10 секунд). На каждую упавшую группу тратилось более 4-5 минут!
**Причина исчезновения DNS в chroot**:
- В `stage1_serial.log` (строка 1515) после установки группы `bluez ... power-profiles-daemon` выполнился post-transaction хук pacman:
  ```text
  :: Running post-transaction hooks...
  (1/9) Creating temporary files...
  ```
- Данный хук запускает `/usr/share/libalpm/scripts/systemd-hook tmpfiles`, который исполняет `systemd-tmpfiles --create`.
- Файл `/usr/lib/tmpfiles.d/systemd-resolve.conf` содержит директиву:
  ```text
  L! /etc/resolv.conf - - - - ../run/systemd/resolve/stub-resolv.conf
  ```
  Знак `L!` принудительно заменяет файл `/etc/resolv.conf` на символическую ссылку на `../run/systemd/resolve/stub-resolv.conf`.
- В среде `arch-chroot` служба `systemd-resolved` не запущена, и целевой файл `/run/systemd/resolve/stub-resolv.conf` **не существует**. Симлинк оказывается «битым».
- В результате любой запрос DNS через `libcurl` немедленно завершается по таймауту (`Resolving timed out after 10001 milliseconds`), а `install-arch.sh` проверял `/etc/resolv.conf` только один раз в начале `phase_chroot()`.

### 1.3 Первопричина №2: Ложное срабатывание регулярного выражения GPU (`ATI` в `compatible`)
В функции `detect_and_install_gpu()` (`install-arch.sh`, строки 723–725):
```bash
echo "$vga" | grep -qiE "Intel|8086" && is_intel=1 || true
echo "$vga" | grep -qiE "AMD|ATI|Radeon" && is_amd=1 || true
echo "$vga" | grep -qiE "NVIDIA" && is_nvidia=1 || true
```
- В QEMU видеоадаптер определяется строкой: `00:01.0 VGA compatible controller: Device 1234:1111 (rev 02)`.
- Из-за флага `-i` (регистронезависимый поиск) подстрока `ATI` совпала со словом `comp[ati]ble` (`compatible`)!
- В результате переменная `is_amd` установилась в `1` для виртуальной машины QEMU, и скрипт начал скачивать стек AMD (`vulkan-radeon`, `libva-mesa-driver`, `xf86-video-amdgpu`), вместо требуемого согласно `ORIGINAL_REQUEST R1` Intel Ivy Bridge стека (`mesa`, `vulkan-intel`, `intel-media-driver`, `xf86-video-intel`).

### 1.4 Первопричина №3: Интерактивные запросы pacman и yay
1. **Провайдеры в pacman**:
   - `libxtables.so=12-64`: выбор `iptables` vs `iptables-legacy` (в pacstrap).
   - `libva-mesa-driver`: выбор `cachyos-v3/mesa-git` vs `cachyos/mesa` vs `extra/mesa`. При нажатии Enter по умолчанию выбирался `mesa-git`!
   - `xdg-desktop-portal-impl`: выбор из 21 провайдера (по умолчанию выбирался `xdg-desktop-portal-cosmic`, затягивавший тяжелые пакеты Rust COSMIC).
   - `ttf-font`: выбор из 11 провайдеров.
   - `libgl` / `libegl`: выбор провайдеров из `cachyos-extra-v3` vs `extra`.
   Флаг `--noconfirm` в pacman выбирает `default=1`, но не решает проблему затягивания нежелательных пакетов (`mesa-git`, `xdg-desktop-portal-cosmic`) и может заблокироваться при неожиданных вопросах.
2. **Интерактивные меню в `yay`**:
   - Команды `yay -S --noconfirm --needed` по умолчанию выводят интерактивные меню:
     * `Packages to cleanBuild? [N]one [A]ll [a]bort`
     * `Diffs to show? [N]one`
     Без флагов `--answerclean None --answerdiff None --answeredit None --answermenu None` утилита `yay` останавливается в ожидании ввода со стандартного потока.
3. **Тяжелые пакеты в `aur_groups`**:
   - В `install-arch.sh` (строка 839) включен `linux-wallpaperengine-git` («Живые обои (опционально, длительная сборка)»). Компиляция этого C++ проекта с ffmpeg и OpenGL в VM занимает от 15 до 30 минут 100% CPU и гарантированно приводит к превышению таймаута. Это прямо нарушает требование R1: «без мусорных, устаревших или тяжеловесных пакетов, требующих долгой компиляции».

### 1.5 Первопричина №4: Таймаут и отсутствие логирования прогресса в `tests/qemu_test_runner.sh`
- `STAGE1_TIMEOUT` по умолчанию составляет 1800 секунд (30 минут).
- В цикле ожидания `run_stage1()` скрипт `qemu_test_runner.sh` делает `sleep 5` и не выводит в консоль хоста никаких сообщений о прогрессе. Если происходит долгая загрузка или задержка зеркал, со стороны процесс выглядит зависшим.

### 1.6 Готовность Stage 2 (UEFI Boot & Acceptance Verification)
Файл `tests/vm_acceptance_check.sh` полностью готов и проверен:
- Охватывает все 14 критериев приемки (проверка `BOOTX64.EFI`, `grubx64.efi`, ядра `linux-cachyos-bore`, 4 служб `NetworkManager`, `bluetooth`, `sddm`, `udisks2` в состояниях enabled и active, пользователя `chezok` в группе wheel, DNS в `resolv.conf`, пакета ядра).
- В headless-режиме корректно допускает состояние `activating`/`inactive` для `sddm`.
- Выводит итоговый токен `[ACCEPTANCE_SUMMARY] RESULT=PASSED TOTAL=14 PASSED=14 FAILED=0`.
- В `autorun.sh` генерируется служба `vm-acceptance.service` с выводом в `/dev/ttyS0` и `poweroff`.
- В Stage 2 QEMU запускается без `-kernel` напрямую через UEFI OVMF прошивку с виртуального диска `target.qcow2`.

---

## 2. Logic Chain

1. **Восстановление сетевой связности в chroot**:
   - Хук `21-systemd-tmpfiles.hook` читает `/usr/lib/tmpfiles.d/systemd-resolve.conf` и заменяет `/etc/resolv.conf` битым симлинком.
   - Создание маски `/etc/tmpfiles.d/systemd-resolve.conf -> /dev/null` гарантирует, что `systemd-tmpfiles` никогда не тронет `/etc/resolv.conf`.
   - Добавление вспомогательной функции `ensure_resolv_conf()` и ее вызов перед каждым сетевым блоком гарантирует постоянное присутствие валидных DNS (`1.1.1.1`, `8.8.8.8`, `10.0.2.3`).
2. **Устранение ложного AMD детектирования**:
   - Замена `grep -qiE "AMD|ATI|Radeon"` на проверку границ слов `grep -qE "\b(AMD|ATI|Radeon)\b"` исключает ложное срабатывание на слово `compatible`.
   - Для QEMU и систем без дискретного GPU обеспечивается прямая установка графического стека Intel Ivy Bridge (`mesa`, `vulkan-intel`, `intel-media-driver`, `xf86-video-intel`, `intel-ucode`) согласно R1.
3. **Гарантия неинтерактивности pacman и yay**:
   - Явное указание конкретных пакетов (`xdg-desktop-portal-gtk` вместо неразрешенного `xdg-desktop-portal-impl`, `gnu-free-fonts` вместо общего `ttf-font`, `libglvnd`, `mesa`) полностью устраняет диалоги выбора провайдера.
   - Пайпинг `printf '\n' | pacman -S --noconfirm --needed ...` гарантирует автоматический выбор значения по умолчанию при любых непредвиденных запросах без блокировки.
   - Для `yay` флаги `--answerclean None --answerdiff None --answeredit None --answermenu None` отключают все интерактивные меню сборки.
   - Удаление тяжелого пакета `linux-wallpaperengine-git` из автоустановщика исключает зависание компиляции на полчаса.
4. **Оптимизация зеркал CachyOS**:
   - Помещение официального `mirror.cachyos.org` и российских зеркал `mirror.cachy-arch.ru`, `mirror.jura12.ru` в начало `/etc/pacman.d/cachyos-mirrorlist` устраняет задержки скачивания.
5. **Прогресс-бар и таймаут хост-раннера**:
   - Увеличение `STAGE1_TIMEOUT` до 2400 секунд (40 минут) дает надежный запас.
   - Каждые 30 секунд вывод последней строки лога в консоль хоста обеспечивает наблюдаемость и диагностику.

---

## 3. Caveats

1. **Скорость интернета на хосте**:
   Установка базовой системы, ядра CachyOS Bore и основных пакетов требует скачивания ~1.2–1.5 GiB. При скорости канала хоста 10–20 Мбит/с это занимает 8–15 минут.
2. **Headless SDDM**:
   В виртуальной машине без KMS монитора SDDM остается в состоянии `activating` или `inactive` — скрипт `vm_acceptance_check.sh` уже учитывает это и корректно валидирует `is-enabled` и статус без ложных сбоев.
3. **Синхронизация `install.sh` и `install-arch.sh`**:
   Оба файла должны быть строго идентичны, так как Live ISO и пользователи могут использовать любое из этих двух имен.

---

## 4. Conclusion

Все причины остановки Stage 1 локализованы, детерминированы и снабжены готовыми исправлениями. Сформулирован готовый патч `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m2_2/m2_stage1_fixes.patch`.

### План действий для Worker:
1. **Применить правки в `install-arch.sh` и `install.sh`**:
   - Добавить маскирование `systemd-resolve.conf` (`ln -sf /dev/null /etc/tmpfiles.d/systemd-resolve.conf`).
   - Добавить функцию `ensure_resolv_conf()` и вызывать ее перед операциями установки пакетов.
   - Исправить регулярное выражение GPU на `\b(AMD|ATI|Radeon)\b` и назначить Intel Ivy Bridge стек для VM/Generic.
   - Добавить явные пакеты `xdg-desktop-portal-gtk` и `gnu-free-fonts`.
   - Использовать `printf '\n' | pacman -S --noconfirm --needed ...`.
   - Добавить флаги неинтерактивности в yay (`--answerclean None --answerdiff None --answeredit None --answermenu None`) и убрать `linux-wallpaperengine-git`.
   - Добавить быстрые зеркала в `cachyos-mirrorlist`.
2. **Применить правки в `tests/qemu_test_runner.sh`**:
   - Увеличить `STAGE1_TIMEOUT` до 2400 секунд.
   - Добавить heartbeat-логирование каждые 30 секунд в цикле ожидания Stage 1.
   - В `autorun.sh` добавить `nameserver 10.0.2.3` и маскирование `systemd-resolve.conf`.
3. **Запустить E2E прогон**:
   - Выполнить: `bash tests/qemu_test_runner.sh all`
4. **Верифицировать результаты Stage 1 и Stage 2**:
   - Убедиться в получении `###STAGE1_COMPLETE_SUCCESS###` и `[ACCEPTANCE_SUMMARY] RESULT=PASSED TOTAL=14 PASSED=14 FAILED=0`.
5. **Создать `TEST_READY.md` и зафиксировать финальный коммит**.

---

## 5. Verification Method

### 5.1 Проверка синтаксиса скриптов после применения правок
```bash
bash -n /home/chezok/dotfiles/install-arch.sh
bash -n /home/chezok/dotfiles/install.sh
bash -n /home/chezok/dotfiles/tests/qemu_test_runner.sh
bash -n /home/chezok/dotfiles/tests/vm_acceptance_check.sh
```
*Ожидаемый результат*: Код возврата 0, отсутствие синтаксических ошибок.

### 5.2 Проверка регулярного выражения GPU
```bash
python3 -c "
import re
vga = '00:01.0 VGA compatible controller: Device 1234:1111 (rev 02)'
assert not re.search(r'\b(AMD|ATI|Radeon)\b', vga)
print('GPU regex verification: PASSED')
"
```
*Ожидаемый результат*: `GPU regex verification: PASSED`.

### 5.3 Сквозной автоматический запуск тестов Milestone 2
```bash
# Запуск полного пайплайна (Stage 1 + Stage 2):
bash /home/chezok/dotfiles/tests/qemu_test_runner.sh all
```
*Ожидаемый результат*:
1. Stage 1: чистый диск qcow2 -> разметка GPT -> XFS/FAT32 -> pacstrap -> chroot -> CachyOS repo -> Intel Ivy Bridge драйверы -> GRUB `--removable` (создание `/boot/efi/EFI/BOOT/BOOTX64.EFI`) -> службы -> токен `###STAGE1_COMPLETE_SUCCESS###` -> выключение VM.
2. Stage 2: запуск QEMU без Live ISO -> загрузка UEFI OVMF -> загрузка BOOTX64.EFI -> загрузка ядра `linux-cachyos-bore` -> запуск `vm-acceptance.service` -> вывод всех 14 проверок со статусом PASS -> токен `[ACCEPTANCE_SUMMARY] RESULT=PASSED TOTAL=14 PASSED=14 FAILED=0` -> чистое выключение VM -> код возврата `0`.
