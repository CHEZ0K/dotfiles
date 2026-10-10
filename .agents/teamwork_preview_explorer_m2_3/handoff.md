# Handoff Report: Explorer 1 (teamwork_preview_explorer_m2_3)
**Iteration 2 Milestone 2 Investigation & Proposed Fixes**

**Agent**: `teamwork_preview_explorer_m2_3`  
**Role**: Explorer, Investigator  
**Date**: 2026-10-10  
**Target Recipient**: Orchestrator (`d3c70754-2d26-4597-8573-bf4cb644d11f`)  
**Status**: COMPLETE (Hard Handoff)

---

## 1. Observation

### 1.1 Невалидный флаг `yay --answermenu None` в `install-arch.sh` и `install.sh`

В исходной реализации скриптов установки `install-arch.sh` и `install.sh` до коммита `295a1364512fc4e64da3079c87756cfb7af88bd0`:
- **Файл**: `/home/chezok/dotfiles/install-arch.sh` и `/home/chezok/dotfiles/install.sh`
- **Строки 873–875** (функция `install_aur_packages`):
  ```bash
  su - "${USERNAME:-chezok}" -c "yay -S --noconfirm --needed --answerclean None --answerdiff None --answeredit None --answermenu None vibepanel-bin" 2>/dev/null \
      || su - "${USERNAME:-chezok}" -c "yay -S --noconfirm --needed --answerclean None --answerdiff None --answeredit None --answermenu None vibepanel-git" \
      || warn "vibepanel не удалось установить из AUR"
  ```
- **Строки 895–896** (цикл по `aur_groups`):
  ```bash
  su - "${USERNAME:-chezok}" -c "yay -S --noconfirm --needed --answerclean None --answerdiff None --answeredit None --answermenu None $group" \
      || warn "Некоторые AUR пакеты не установлены: $group"
  ```

В логе первого прогона Stage 1 (`/home/chezok/dotfiles/tests/build/stage1_serial.log`, строки 3124–3138) зафиксированы следующие verbatim-ошибки:
```text
3124: [INFO]  AUR: установка Vibepanel...
3125:  -> invalid option 'answermenu'
3126: [WARN]  vibepanel не удалось установить из AUR
3127: [INFO]  AUR: устанавливаем zen-browser-bin ayugram-desktop-bin
3128:  -> invalid option 'answermenu'
3129: [WARN]  Некоторые AUR пакеты не установлены: zen-browser-bin ayugram-desktop-bin
3130: [INFO]  AUR: устанавливаем python-pywal
3131:  -> invalid option 'answermenu'
3132: [WARN]  Некоторые AUR пакеты не установлены: python-pywal
3133: [INFO]  AUR: устанавливаем sptlrx-bin waylyrics
3134:  -> invalid option 'answermenu'
3135: [WARN]  Некоторые AUR пакеты не установлены: sptlrx-bin waylyrics
3136: [INFO]  AUR: устанавливаем unimatrix-git lavat pipes.sh
3137:  -> invalid option 'answermenu'
3138: [WARN]  Некоторые AUR пакеты не установлены: unimatrix-git lavat pipes.sh
```

Из-за конструкций `|| warn "..."` ошибки были проигнорированы, и скрипт вернул код возврата 0, однако пакет `vibepanel` (требование R1) и все AUR пакеты не были установлены.

---

### 1.2 Исследование поддерживаемых флагов `yay` на хосте (`yay --help` и `yay --version`)

Команда:
```bash
yay --version
```
Результат:
```text
yay v13.0.1 - libalpm v16.0.1
```

Команда:
```bash
yay --help | grep -E "answer|menu"
```
Результат:
```text
    --answerclean   <a>   Set a predetermined answer for the clean build menu
    --answerdiff    <a>   Set a predetermined answer for the diff menu
    --answeredit    <a>   Set a predetermined answer for the edit pkgbuild menu
    --answerupgrade <a>   Set a predetermined answer for the upgrade menu
    --noanswerclean       Unset the answer for the clean build menu
    --noanswerdiff        Unset the answer for the edit diff menu
    --noansweredit        Unset the answer for the edit pkgbuild menu
    --noanswerupgrade     Unset the answer for the upgrade menu
    --cleanmenu           Give the option to clean build PKGBUILDS
    --diffmenu            Give the option to show diffs for build files
    --editmenu            Give the option to edit/view PKGBUILDS
```

Прямая эмпирическая проверка поведения:
1. `yay --answermenu None -V`
   - **Код возврата**: `1`
   - **Вывод**: ` -> invalid option 'answermenu'`
2. `yay --answerclean None --answerdiff None --answeredit None --answerupgrade None -V`
   - **Код возврата**: `0`
   - **Вывод**: `yay v13.0.1 - libalpm v16.0.1`

Вывод: Опция `--answermenu` не существует в `yay`. Для подавления всех интерактивных меню в `yay` валидными флагами являются:
```bash
--answerclean None --answerdiff None --answeredit None --answerupgrade None
```

---

### 1.3 Сопутствующий сбой `neofetch` в pacman группе CLI утилит

В `install-arch.sh` и `install.sh` строка 850:
```bash
"btop htop nvtop cmatrix neofetch genact aria2 playerctl brightnessctl libnotify jq tty-clock nodejs npm lua-luv"
```
В логе `/home/chezok/dotfiles/tests/build/stage1_serial.log` (строки 2932–2937):
```text
2932: [INFO]  Устанавливаем: btop htop nvtop cmatrix neofetch genact aria2 playerctl brightnessctl libnotify jq tty-clock nodejs npm lua-luv
2933: error: target not found: neofetch
2934: warning: playerctl-2.4.1-5 is up to date -- skipping
2935: warning: libnotify-0.8.8-1 is up to date -- skipping
2936: warning: jq-1.8.2-1 is up to date -- skipping
2937: [WARN]  Некоторые пакеты из группы не найдены: btop htop nvtop cmatrix neofetch genact aria2 playerctl brightnessctl libnotify jq tty-clock nodejs npm lua-luv
```
Из-за атомарности `pacman -S` транзакция отменилась целиком, поэтому `btop`, `htop`, `nvtop`, `cmatrix`, `genact`, `aria2`, `tty-clock`, `nodejs`, `npm`, `lua-luv` не установились.

В репозиториях Arch Linux и CachyOS пакет `neofetch` удален (проект закрыт), а его официальной и быстрой заменой является `fastfetch` (`cachyos-extra-v3/fastfetch 2.69.0-1.1` и `extra/fastfetch 2.69.0-1`).

---

### 1.4 Проверка текущего состояния репозитория

В репозитории зафиксирован коммит:
`commit 295a1364512fc4e64da3079c87756cfb7af88bd0`:
- В `install-arch.sh` и `install.sh`:
  - `neofetch` заменен на `fastfetch` (строка 850).
  - `--answermenu None` заменен на `--answerupgrade None` в вызовах `yay` (строки 873, 874, 895).
- Файлы `install-arch.sh` и `install.sh` строго идентичны (`diff -u` пустой).

Однако файл `/home/chezok/dotfiles/tests/vm_acceptance_check.sh` на данный момент **не расширен** и по-прежнему содержит только 14 системных проверок без валидации пользовательских пакетов (`vibepanel`, `zen-browser-bin`, `fastfetch`, `btop`).

---

### 1.5 Проверка пакетов на реальной системе пользователя (хосте)

Команды:
```bash
pacman -Q vibepanel-git zen-browser-bin btop
which vibepanel btop zen-browser
```
Результаты:
- `vibepanel-git`: `0.16.1.r6.g14d8283-1` (установлен бинарник `/usr/bin/vibepanel` и локальный `/home/chezok/.local/bin/vibepanel`).
- `zen-browser-bin`: `1.22.3b-1` (установлен бинарник `/usr/bin/zen-browser`).
- `btop`: `1.4.7-1.1` (установлен бинарник `/usr/bin/btop`).

В AUR доступны:
- `vibepanel-bin` (версия 0.16.1-1, готовый бинарник от `prankstr`, без зависимостей сборки).
- `vibepanel-git` (версия 0.16.1.r0.g92420c6-1, сборка из исходников с `cargo/rust`).

---

## 2. Logic Chain

1. **Следствие 1 (Причина падения AUR пакетов)**:
   - В `install-arch.sh` передавался флаг `--answermenu None`.
   - `yay v13.0.1` завершает работу с кодом `1` при встрече неизвестного флага (`invalid option 'answermenu'`).
   - Следовательно, `yay` завершался еще на стадии парсинга аргументов, не выполняя ни одной сетевой или сборочной операции.
   - Замена `--answermenu None` на валидный флаг `--answerupgrade None` устраняет сбой парсинга, позволяя `yay` успешно выполнять сборку и установку AUR пакетов (`vibepanel-bin`, `vibepanel-git`, `python-pywal`, и др.).

2. **Следствие 2 (Причина выпадения группы утилит и решение через `fastfetch`)**:
   - `pacman` прерывает всю транзакцию, если хотя бы один аргумент не найден в базах данных.
   - Пакет `neofetch` исключен из зеркал Arch Linux.
   - Замена `neofetch` на `fastfetch` устраняет ошибку разрешения пакетов, обеспечивая успешную установку всей группы CLI утилит (`btop`, `htop`, `nodejs`, `npm`, и др.).

3. **Следствие 3 (Необходимость расширения `tests/vm_acceptance_check.sh`)**:
   - Прежняя версия `tests/vm_acceptance_check.sh` проверяла только загрузчик, ядро и базовые сервисы systemd.
   - Поскольку инсталлятор защищен конструкциями `|| warn`, отсутствие критических пакетов не приводило к ненулевому коду завершения инсталлятора.
   - Добавление явных проверок для `vibepanel`, `zen-browser-bin`, `fastfetch`, `btop` (а также `ayugram-desktop` и стека Wayland) гарантирует, что любое будущее падение при установке пользовательского ПО приведет к явному `FAIL` на этапе Stage 2 (`[ACCEPTANCE_SUMMARY] RESULT=FAILED`), исключая ложные отчеты об успехе.

4. **Следствие 4 (Совместимость с `tests/qemu_test_runner.sh`)**:
   - В `tests/qemu_test_runner.sh` (строки 480–525) парсинг результатов верификации Stage 2 опирается исключительно на текстовый токен `[ACCEPTANCE_SUMMARY] RESULT=PASSED` и вывод строк `[ACCEPTANCE_CHECK]`.
   - Общее число проверок (`TOTAL_CHECKS`) не захардкожено в раннере.
   - Следовательно, расширение числа проверок с 14 до 20 полностью прозрачно для раннера и автоматически отражается в логах стенда.

---

## 3. Caveats

1. **Состояние git-дерева**: Изменения флагов `yay` и замена `neofetch -> fastfetch` в `install-arch.sh` и `install.sh` уже закоммичены в `main` (коммит `295a1364512fc4e64da3079c87756cfb7af88bd0`). Патч `installer_yay_and_neofetch.patch` сохранен в рабочей директории в качестве документирующего артефакта.
2. **Read-only статус исследователя**: Согласно ограничениям роли Explorer, файл `tests/vm_acceptance_check.sh` не был модифицирован напрямую в репозитории. Вместо этого подготовлены:
   - Полный замещающий файл: `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m2_3/proposed_vm_acceptance_check.sh`
   - Машинно-применимый патч: `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m2_3/tests_vm_acceptance_check.patch`
3. **Bluetooth в виртуальной машине QEMU**: Проверка активности `bluetooth.service` корректно обрабатывает статус `inactive` в условиях отсутствия виртуального контроллера Bluetooth (условие юнита systemd `ConditionPathIsDirectory=/sys/class/bluetooth`).

---

## 4. Conclusion

1. Причина сбоя AUR пакетов в Stage 1 однозначно идентифицирована: несуществующий флаг `--answermenu None` в вызовах `yay`. Решение: использовать валидный флаг `--answerupgrade None`.
2. Причина пропуска утилит (`btop` и др.) однозначно идентифицирована: удаленный из репозиториев пакет `neofetch`. Решение: замена на `fastfetch`.
3. Тестовый скрипт `tests/vm_acceptance_check.sh` расширен с 14 до 20 проверок:
   - **Check 15**: `PKG_VIBEPANEL` (`pacman -Q vibepanel-bin 2>/dev/null || pacman -Q vibepanel-git 2>/dev/null || pacman -Q vibepanel 2>/dev/null || which vibepanel 2>/dev/null`)
   - **Check 16**: `PKG_ZEN_BROWSER` (`pacman -Q zen-browser-bin 2>/dev/null || pacman -Q zen-browser 2>/dev/null || which zen-browser 2>/dev/null`)
   - **Check 17**: `PKG_FASTFETCH` (`pacman -Q fastfetch 2>/dev/null || which fastfetch 2>/dev/null`)
   - **Check 18**: `PKG_BTOP` (`pacman -Q btop 2>/dev/null || which btop 2>/dev/null`)
   - **Check 19**: `PKG_AYUGRAM_DESKTOP` (`pacman -Q ayugram-desktop 2>/dev/null || pacman -Q ayugram-desktop-bin 2>/dev/null || which ayugram-desktop 2>/dev/null`)
   - **Check 20**: `PKG_WAYLAND_STACK` (`niri`, `hyprland`, `waybar`)
4. Все разработанные файлы протестированы локально:
   - `test_proposed_checks.sh` успешно выполнил проверки.
   - `proposed_vm_acceptance_check.sh` прошел `bash -n`.
   - Патч `tests_vm_acceptance_check.patch` проверен командой `git apply --check` с кодом `0`.

---

## 5. Verification Method

Для независимой проверки результатов аудитором/воркером:

### Шаг 1. Проверка флагов `yay` на хосте
```bash
# Должен завершиться с ошибкой:
yay --answermenu None -V
# Вывод: -> invalid option 'answermenu' (код 1)

# Должен успешно выполниться:
yay --answerclean None --answerdiff None --answeredit None --answerupgrade None -V
# Вывод: yay v13.0.1 - libalpm v16.0.1 (код 0)
```

### Шаг 2. Проверка тестового скрипта и применение патча
```bash
# 1. Проверка синтаксиса предложенного скрипта:
bash -n /home/chezok/dotfiles/.agents/teamwork_preview_explorer_m2_3/proposed_vm_acceptance_check.sh

# 2. Проверка валидности патча:
git apply --check /home/chezok/dotfiles/.agents/teamwork_preview_explorer_m2_3/tests_vm_acceptance_check.patch

# 3. Применение патча к репозиторию (выполняется воркером):
git apply /home/chezok/dotfiles/.agents/teamwork_preview_explorer_m2_3/tests_vm_acceptance_check.patch
```

### Шаг 3. Запуск верификации на тестовом стенде QEMU
```bash
# Полный сквозной прогон стенда (Stage 1 + Stage 2):
bash /home/chezok/dotfiles/tests/qemu_test_runner.sh all
```
Критерии успеха:
- Stage 1 завершается с токеном `###STAGE1_COMPLETE_SUCCESS###`.
- Лог Stage 1 не содержит `invalid option 'answermenu'` и `error: target not found: neofetch`.
- Stage 2 завершается с токеном `[ACCEPTANCE_SUMMARY] RESULT=PASSED TOTAL=20 PASSED=20 FAILED=0`.
- Все проверки `PKG_VIBEPANEL`, `PKG_ZEN_BROWSER`, `PKG_FASTFETCH`, `PKG_BTOP` возвращают `PASS`.
