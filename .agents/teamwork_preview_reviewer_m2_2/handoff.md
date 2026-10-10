# Handoff Report: Reviewer 2 & Adversarial Critic Audit for Milestone 2

**Agent**: `teamwork_preview_reviewer_m2_2`  
**Role**: Reviewer & Adversarial Critic  
**Working Directory**: `/home/chezok/dotfiles/.agents/teamwork_preview_reviewer_m2_2`  
**Target Recipient**: Orchestrator (`d3c70754-2d26-4597-8573-bf4cb644d11f`)  
**Date**: 2026-10-10  
**Verdict**: **REQUEST_CHANGES**  

---

## 1. Observation

### 1.1 Verbatim Code & Log Findings

#### Observation 1: Invalid yay Flag Crashing All AUR Packages (Including Core Desktop Vibepanel)
- **Source Files**: `/home/chezok/dotfiles/install-arch.sh` (lines 873–874, 895) and `/home/chezok/dotfiles/install.sh`:
  ```bash
  873: su - "${USERNAME:-chezok}" -c "yay -S --noconfirm --needed --answerclean None --answerdiff None --answeredit None --answermenu None vibepanel-bin" 2>/dev/null \
  874:     || su - "${USERNAME:-chezok}" -c "yay -S --noconfirm --needed --answerclean None --answerdiff None --answeredit None --answermenu None vibepanel-git" \
  875:     || warn "vibepanel не удалось установить из AUR"
  ...
  895: su - "${USERNAME:-chezok}" -c "yay -S --noconfirm --needed --answerclean None --answerdiff None --answeredit None --answermenu None $group" \
  896:     || warn "Некоторые AUR пакеты не установлены: $group"
  ```
- **Observed yay 13.0.1 Help Specification**:
  ```text
  $ yay --help | grep -i answer
      --answerclean   <a>   Set a predetermined answer for the clean build menu
      --answerdiff    <a>   Set a predetermined answer for the diff menu
      --answeredit    <a>   Set a predetermined answer for the edit pkgbuild menu
      --answerupgrade <a>   Set a predetermined answer for the upgrade menu
  ```
  *(Note: `--answermenu` is non-existent in yay).*
- **Observed Verbatim Error in `/home/chezok/dotfiles/tests/build/stage1_serial.log`**:
  ```text
  Line 3125:  -> invalid option 'answermenu'
  Line 3126: [WARN]  vibepanel не удалось установить из AUR
  Line 3128:  -> invalid option 'answermenu'
  Line 3129: [WARN]  Некоторые AUR пакеты не установлены: zen-browser-bin ayugram-desktop-bin
  Line 3131:  -> invalid option 'answermenu'
  Line 3132: [WARN]  Некоторые AUR пакеты не установлены: python-pywal
  Line 3134:  -> invalid option 'answermenu'
  Line 3135: [WARN]  Некоторые AUR пакеты не установлены: sptlrx-bin waylyrics
  Line 3137:  -> invalid option 'answermenu'
  Line 3138: [WARN]  Некоторые AUR пакеты не установлены: unimatrix-git lavat pipes.sh
  ```
- **Consequence**: `vibepanel` (the primary bar/panel required in `ORIGINAL_REQUEST.md` R1 and invoked in `dotfiles/niri/config.kdl` line 166 `spawn-at-startup "vibepanel"` and lines 230-237 layer-rule) **was not installed**. Neither was `python-pywal` (causing `wal` in line 708 to fail), `sptlrx-bin`, `waylyrics`, `unimatrix-git`, `lavat`, or `pipes.sh`.

---

#### Observation 2: Atomic pacman Failure Dropping 11 Utility Packages Due to Dead `neofetch`
- **Source Files**: `/home/chezok/dotfiles/install-arch.sh` (lines 850, 861) and `/home/chezok/dotfiles/install.sh`:
  ```bash
  850: "btop htop nvtop cmatrix neofetch genact aria2 playerctl brightnessctl libnotify jq tty-clock nodejs npm lua-luv"
  ...
  861: printf '\n' | pacman -S --noconfirm --needed $group || warn "Некоторые пакеты из группы не найдены: $group"
  ```
- **Observed Verbatim Error in `/home/chezok/dotfiles/tests/build/stage1_serial.log`**:
  ```text
  Line 2932: [INFO]  Устанавливаем: btop htop nvtop cmatrix neofetch genact aria2 playerctl brightnessctl libnotify jq tty-clock nodejs npm lua-luv
  Line 2933: error: target not found: neofetch
  Line 2937: [WARN]  Некоторые пакеты из группы не найдены: btop htop nvtop cmatrix neofetch genact aria2 playerctl brightnessctl libnotify jq tty-clock nodejs npm lua-luv
  ```
- **Repository Verification on Host**:
  `pacman -Ss "^neofetch$"` returns exit code 0 with 0 results. `neofetch` is discontinued and removed from Arch Linux repositories (superseded by `fastfetch`).
- **Consequence**: Because pacman operations are atomic, the missing package `neofetch` caused the entire command to abort. The following packages were **never installed**: `btop`, `htop`, `nvtop`, `cmatrix`, `genact`, `aria2`, `brightnessctl`, `tty-clock`, `nodejs`, `npm`, `lua-luv`.

---

#### Observation 3: Acceptance Test Suite Blind Spot (Self-Certifying Verification)
- **Source File**: `/home/chezok/dotfiles/tests/vm_acceptance_check.sh`:
  The guest verification suite asserts exactly 14 checks:
  1. `UEFI_BOOTX64_EXISTS`
  2. `UEFI_GRUBX64_EXISTS`
  3. `KERNEL_CACHYOS_BORE`
  4–7. `SERVICE_ENABLED_` (`NetworkManager`, `bluetooth`, `sddm`, `udisks2`)
  8–11. `SERVICE_ACTIVE_` (`NetworkManager`, `bluetooth`, `sddm`, `udisks2`)
  12. `USER_CHEZOK_WHEEL`
  13. `DNS_RESOLV_CONF`
  14. `PKG_CACHYOS_BORE`
- **What is NOT Checked**:
  - `vm_acceptance_check.sh` contains zero checks for `vibepanel` (or `vibepanel-bin` / `vibepanel-git`).
  - Zero checks for `zen-browser-bin` or `ayugram-desktop`.
  - Zero checks for CLI tools (`btop`, `htop`).
  - Zero checks for graphics drivers (`mesa`, `vulkan-intel`, `intel-media-driver`).
- **Impact**: Because the installer uses `|| warn "..."` around package installations, exit code 0 was preserved, and `vm_acceptance_check.sh` passed 14/14, creating a misleading self-certification that masked the total absence of `vibepanel` and 11+ system tools.

---

### 1.2 Independent Live Verification of Passing Components
Independent execution of Stage 2 test harness was performed on the existing disk (`bash tests/qemu_test_runner.sh stage2`):
- **Exit code**: `0`.
- **UEFI Boot**: Cold boot via OVMF UEFI fallback into `/boot/efi/EFI/BOOT/BOOTX64.EFI` succeeded.
- **Kernel**: `7.2.7-1-cachyos-bore` loaded cleanly.
- **Services**: `NetworkManager` (active), `sddm` (active), `udisks2` (active), `bluetooth` (enabled, inactive due to hardware absence in VM).
- **Configurations Verified**:
  - `dotfiles/niri/config.kdl` lines 230–237: `layer-rule { match namespace="^vibepanel... background-effect { blur true xray false } }` is correctly configured.
  - `dotfiles/systemd/user/udiskie.service` line 7: `ExecStart=/usr/bin/udiskie --automount --notify --no-tray -f nemo` is correctly configured.
  - SDDM: Preserved with `Current=silent` and `CursorTheme=Furina`.

---

## 2. Logic Chain

1. **Premise**: `ORIGINAL_REQUEST.md` (R1) demands installation of the exact system package set, explicitly including `vibepanel-git`, `zen-browser-bin`, `ayugram-desktop-bin`, and user utilities (`btop`, `htop`, etc.).
2. **Observation**: `install-arch.sh` invoked `yay` with `--answermenu None`.
3. **Inference**: In `yay` version 13.0.1, `--answermenu` is an unrecognized option. Therefore, all `yay` invocations exited immediately with error code 1 without cloning or building any packages.
4. **Observation**: `install-arch.sh` included `neofetch` in an atomic pacman transaction.
5. **Inference**: Because `neofetch` no longer exists in Arch/CachyOS repos, pacman aborted the command, omitting `btop`, `htop`, `nvtop`, `cmatrix`, `genact`, `aria2`, `brightnessctl`, `tty-clock`, `nodejs`, `npm`, `lua-luv`.
6. **Observation**: Both failure points were shielded with `|| warn "..."`.
7. **Inference**: The installer completed with return code 0, and the in-guest acceptance test (`vm_acceptance_check.sh`) only tested 14 selected items, omitting package checks for `vibepanel` and the omitted utilities.
8. **Conclusion**: Although the UEFI boot and virtualization infrastructure (R3, R4) operate effectively, Acceptance Criterion R1 is incomplete due to unhandled package failures, and the test suite exhibits a coverage gap masking these omissions.

---

## 3. Caveats

1. **No Deliberate Falsification**: The QEMU virtual test stand is authentic; Stage 1 and Stage 2 runs were physically executed in QEMU, generating valid 7.5GB disk images and serial logs. The issue is unintended argument incompatibility and package deprecation combined with silent error catchers, not fabricated artifacts.
2. **Hardware Constraints**: As confirmed in Stage 2, `bluetooth.service` being in `inactive` state in QEMU is normal behavior due to systemd unit condition `ConditionPathIsDirectory=/sys/class/bluetooth`.
3. **Scope of Fix**: The fix does not require architectural redesign; it requires correcting the CLI parameters in `install-arch.sh` / `install.sh` and updating the acceptance assertions in `tests/vm_acceptance_check.sh`.

---

## 4. Conclusion & Required Actions

**Verdict**: **REQUEST_CHANGES**

### Required Modifications Before Approval:

1. **Fix `yay` AUR Invocations**:
   - In `/home/chezok/dotfiles/install-arch.sh` and `/home/chezok/dotfiles/install.sh`:
   - Replace:
     ```bash
     yay -S --noconfirm --needed --answerclean None --answerdiff None --answeredit None --answermenu None <pkgs>
     ```
     with:
     ```bash
     yay -S --noconfirm --needed --answerclean None --answerdiff None --answeredit None --answerupgrade None <pkgs>
     ```
     *(or simply `yay -S --noconfirm --needed <pkgs>`)*.
   - This will allow `vibepanel-bin`/`vibepanel-git`, `python-pywal`, `sptlrx-bin`, `waylyrics`, `unimatrix-git`, `lavat`, and `pipes.sh` to install cleanly.

2. **Replace Deprecated `neofetch` in pacman Package List**:
   - In `/home/chezok/dotfiles/install-arch.sh` and `/home/chezok/dotfiles/install.sh`:
   - Replace `neofetch` with `fastfetch` in line 850:
     ```bash
     "btop htop nvtop cmatrix fastfetch genact aria2 playerctl brightnessctl libnotify jq tty-clock nodejs npm lua-luv"
     ```
   - This unblocks the entire transaction so `btop`, `htop`, and all other CLI utilities install.

3. **Expand In-Guest Acceptance Test Assertions**:
   - In `/home/chezok/dotfiles/tests/vm_acceptance_check.sh`:
   - Add verification checks for:
     * `vibepanel` (e.g. `pacman -Q vibepanel-bin 2>/dev/null || pacman -Q vibepanel-git 2>/dev/null || which vibepanel`)
     * `zen-browser-bin` (e.g. `pacman -Q zen-browser-bin`)
     * `fastfetch` and `btop` (e.g. `pacman -Q fastfetch btop`)
     * Intel graphics driver stack (`pacman -Q mesa vulkan-intel intel-media-driver xf86-video-intel`)
   - This ensures the test suite genuinely validates R1 and prevents future regressions from being silently masked.

4. **Re-run Full QEMU Test**:
   - Run `bash tests/qemu_test_runner.sh all` and verify that all AUR and pacman packages install with zero warnings.

---

## 5. Verification Method

To verify these findings independently:

```bash
# 1. Verify yay argument incompatibility:
yay --answermenu None 2>&1
# Expected output: "-> invalid option 'answermenu'"

# 2. Verify absence of neofetch in pacman:
pacman -Ss "^neofetch$"
# Expected output: empty (package not found)

# 3. Check failure records in Stage 1 serial log:
grep -E "invalid option|neofetch" /home/chezok/dotfiles/tests/build/stage1_serial.log

# 4. Check absence of vibepanel and btop in stage1 log:
grep "installing vibepanel" /home/chezok/dotfiles/tests/build/stage1_serial.log || echo "vibepanel was NOT installed"
grep "installing btop" /home/chezok/dotfiles/tests/build/stage1_serial.log || echo "btop was NOT installed"
```
