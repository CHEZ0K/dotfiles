# Handoff Report: Challenger M2_2 (teamwork_preview_challenger_m2_2)

**Verdict**: **REQUEST_CHANGES**

## 1. Observation

### 1.1 GPU Detection Regexes (`detect_and_install_gpu`)
- **File**: `/home/chezok/dotfiles/install-arch.sh` (lines 760–819) and `/home/chezok/dotfiles/install.sh` (lines 760–819):
```bash
    local vga
    vga=$(lspci 2>/dev/null | grep -iE "VGA|3D|Display" || true)

    local is_intel=0
    local is_amd=0
    local is_nvidia=0

    echo "$vga" | grep -qiE "Intel|8086" && is_intel=1 || true
    echo "$vga" | grep -qE "\b(AMD|ATI|Radeon)\b" && is_amd=1 || true
    echo "$vga" | grep -qE "\b(NVIDIA)\b" && is_nvidia=1 || true
```
- **Test**: Executed empirical test suite `/home/chezok/dotfiles/.agents/teamwork_preview_challenger_m2_2/test_gpu_regex.py` covering:
  - Intel Ivy Bridge / Pentium 2020M (`Intel Corporation 3rd Gen Core processor Graphics Controller (rev 09)` and `Device 8086:0156`) -> `INTEL=1, AMD=0, NVIDIA=0`.
  - QEMU default VGA (`Device 1234:1111 (rev 02)`), VirtIO GPU, QXL, Cirrus, Bochs, VMware, VirtualBox -> `INTEL=0, AMD=0, NVIDIA=0` (correct fallback to Generic/VM stack `mesa` on line 815).
  - AMD / ATI (`[AMD/ATI] Navi 21`, `[AMD] Picasso/Raven 2`, `ATI Technologies Inc RV770`) -> `INTEL=0, AMD=1, NVIDIA=0`.
  - NVIDIA (`NVIDIA Corporation GA106`, `3D controller: NVIDIA Corporation GP107M`) -> `INTEL=0, AMD=0, NVIDIA=1`.
  - Hybrid Intel+NVIDIA Optimus -> `INTEL=1, AMD=0, NVIDIA=1` (correct fallback to nouveau + mesa on lines 804–806).
- **Result**: 20/20 unit tests passed without false positives or false negatives.
- **Log confirmation**: In `/home/chezok/dotfiles/tests/build/stage1_serial.log` (lines 2490–2498), QEMU emulated GPU was identified as:
  `00:01.0 VGA compatible controller: Device 1234:1111 (rev 02)`
  `[INFO]  Виртуальная машина / Generic GPU: установка Intel/Universal стека mesa, vulkan-intel, xf86-video-intel...`

### 1.2 Non-Interactive Behavior of pacman and yay — CRITICAL FAILURE FOUND
- **File**: `/home/chezok/dotfiles/install-arch.sh` and `/home/chezok/dotfiles/install.sh` (lines 871–895):
```bash
871:     su - "${USERNAME:-chezok}" -c "yay -S --noconfirm --needed --answerclean None --answerdiff None --answeredit None --answermenu None vibepanel-bin" 2>/dev/null \
872:         || su - "${USERNAME:-chezok}" -c "yay -S --noconfirm --needed --answerclean None --answerdiff None --answeredit None --answermenu None vibepanel-git" \
873:         || warn "vibepanel не удалось установить из AUR"
...
893:         su - "${USERNAME:-chezok}" -c "yay -S --noconfirm --needed --answerclean None --answerdiff None --answeredit None --answermenu None $group" \
894:             || warn "Некоторые AUR пакеты не установлены: $group"
```
- **CLI Test**: Executed on host with installed `yay v13.0.1`:
  Command: `yay --answermenu None -V`
  Output: ` -> invalid option 'answermenu'`, Exit code: `1`.
- **Serial Log Verification**: In `/home/chezok/dotfiles/tests/build/stage1_serial.log`:
```
Line 3124: [INFO]  AUR: установка Vibepanel...
Line 3125:  -> invalid option 'answermenu'
Line 3126: [WARN]  vibepanel не удалось установить из AUR
Line 3127: [INFO]  AUR: устанавливаем zen-browser-bin ayugram-desktop-bin
Line 3128:  -> invalid option 'answermenu'
Line 3129: [WARN]  Некоторые AUR пакеты не установлены: zen-browser-bin ayugram-desktop-bin
Line 3130: [INFO]  AUR: устанавливаем python-pywal
Line 3131:  -> invalid option 'answermenu'
Line 3132: [WARN]  Некоторые AUR пакеты не установлены: python-pywal
Line 3133: [INFO]  AUR: устанавливаем sptlrx-bin waylyrics
Line 3134:  -> invalid option 'answermenu'
Line 3135: [WARN]  Некоторые AUR пакеты не установлены: sptlrx-bin waylyrics
Line 3136: [INFO]  AUR: устанавливаем unimatrix-git lavat pipes.sh
Line 3137:  -> invalid option 'answermenu'
Line 3138: [WARN]  Некоторые AUR пакеты не установлены: unimatrix-git lavat pipes.sh
```
- **Consequence**: 100% of AUR packages failed to install due to the invalid option `--answermenu None`. `vibepanel-bin`/`vibepanel-git`, explicitly required by Requirement R1, was NOT installed into the target system.
- **Test infra gap**: `/home/chezok/dotfiles/tests/vm_acceptance_check.sh` did not verify `vibepanel`, allowing Stage 2 to report a false-positive `RESULT=PASSED`.

### 1.3 Protection of `/etc/resolv.conf` from `systemd-tmpfiles`
- **Configuration**:
  - `/usr/lib/tmpfiles.d/systemd-resolve.conf:10:L! /etc/resolv.conf - - - - ../run/systemd/resolve/stub-resolv.conf`
  - In `install-arch.sh` lines 290 and 748:
    `mkdir -p /etc/tmpfiles.d`
    `ln -sf /dev/null /etc/tmpfiles.d/systemd-resolve.conf`
- **Empirical test**: Executed `/home/chezok/dotfiles/.agents/teamwork_preview_challenger_m2_2/test_resolv_conf_tmpfiles.sh`:
  - `systemd-tmpfiles --cat-config` in masked tree confirms `systemd-resolve.conf` is completely masked (overridden by `/dev/null`).
  - `systemd-tmpfiles --create --boot` does NOT touch `/etc/resolv.conf`.
  - In guest serial log (`stage2_serial.log` line 258):
    `[ACCEPTANCE_CHECK] id=DNS_RESOLV_CONF status=PASS details="Valid nameservers present in /etc/resolv.conf: nameserver 1.1.1.1 nameserver 8.8.8.8 nameserver 10.0.2.3 "`

---

## 2. Logic Chain

1. **Step 1 (GPU Detection)**: Observation 1.1 proves that `grep -qiE "Intel|8086"` matches Intel Ivy Bridge without false positives; `grep -qE "\b(AMD|ATI|Radeon)\b"` matches AMD devices without substring issues; QEMU `Device 1234:1111` correctly misses all three and routes to Generic/VM mesa drivers. (Passes verification).
2. **Step 2 (Resolv.conf Protection)**: Observation 1.3 proves that creating a symlink `/etc/tmpfiles.d/systemd-resolve.conf -> /dev/null` adheres to `tmpfiles.d(5)` spec and effectively prevents `systemd-tmpfiles` from replacing `/etc/resolv.conf` with a stub symlink. (Passes verification).
3. **Step 3 (pacman/yay Non-Interactive Behavior)**: Observation 1.2 demonstrates that `yay` was invoked with `--answermenu None`.
4. **Step 4 (Syntax / Compatibility Error)**: Observation 1.2 proves that `yay v13.0.1` does not recognize `--answermenu`, exiting with code 1 immediately on argument parsing.
5. **Step 5 (Silent Failure of Requirement R1)**: Observation 1.2 shows that `vibepanel` (mandated by R1) along with other AUR packages crashed and was bypassed via `|| warn`.
6. **Step 6 (Test Masking)**: `vm_acceptance_check.sh` omits checks for `vibepanel`, reporting false-positive success.
7. **Conclusion**: The installer fails to meet Requirement R1 due to broken `yay` invocations, requiring changes.

---

## 3. Caveats

- CachyOS repositories provide `zen-browser-bin` and `ayugram-desktop` natively via pacman (lines 845 in `install-arch.sh`), so those two binaries were installed via pacman. However, `vibepanel` (both `-bin` and `-git`) is exclusively in AUR, meaning `vibepanel` was completely missing from the installed system.
- Removing `--answermenu None` and using valid flags (`--answerclean None --answerdiff None --answeredit None --answerupgrade None`) is known to work non-interactively on `yay v13`.

---

## 4. Conclusion

- **Verdict**: **REQUEST_CHANGES**
- **Actionable Remediation**:
  1. In `install-arch.sh` and `install.sh`, remove `--answermenu None` from lines 871, 872, and 893. Use valid non-interactive flags:
     `yay -S --noconfirm --needed --answerclean None --answerdiff None --answeredit None --answerupgrade None <package>`
  2. In `tests/vm_acceptance_check.sh`, add a check verifying `vibepanel` is installed:
     `pacman -Q vibepanel-git &>/dev/null || pacman -Q vibepanel-bin &>/dev/null || pacman -Q vibepanel &>/dev/null`
  3. Re-run `tests/qemu_test_runner.sh` to confirm 100% clean installation of AUR packages and successful VM boot acceptance.

---

## 5. Verification Method

To independently reproduce and verify this finding:

1. **Test `yay` CLI flag invalidity**:
   ```bash
   yay --answermenu None -V
   # Output: -> invalid option 'answermenu' (exit code 1)
   ```

2. **Inspect Stage 1 serial log for verbatim failure**:
   ```bash
   grep -n -C 2 "invalid option 'answermenu'" /home/chezok/dotfiles/tests/build/stage1_serial.log
   # Lines 3123-3138 reveal 5 consecutive fatal aborts for all AUR packages including vibepanel
   ```

3. **Run GPU regex empirical test harness**:
   ```bash
   python3 /home/chezok/dotfiles/.agents/teamwork_preview_challenger_m2_2/test_gpu_regex.py
   # 20 passed unit tests
   ```

4. **Run resolv.conf protection test harness**:
   ```bash
   bash /home/chezok/dotfiles/.agents/teamwork_preview_challenger_m2_2/test_resolv_conf_tmpfiles.sh
   # Confirms masking and self-healing
   ```
