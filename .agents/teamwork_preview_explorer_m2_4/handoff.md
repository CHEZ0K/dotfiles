# Handoff Report: Pacman Package Audit, Conflicts & Verification Analysis

**Agent**: `teamwork_preview_explorer_m2_4` (Explorer 2)  
**Roles**: Explorer, Investigator, Synthesist  
**Target Recipient**: Orchestrator (`d3c70754-2d26-4597-8573-bf4cb644d11f`)  
**Working Directory**: `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m2_4`  
**Date**: 2026-10-10  
**Status**: COMPLETE (Hard Handoff)  
**Associated Patch**: `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m2_4/package_audit.patch`

---

## 1. Observation

### 1.1 Scope of the Audit
Conducted an exhaustive audit of all packages declared across all installation stages in `/home/chezok/dotfiles/install-arch.sh` and `/home/chezok/dotfiles/install.sh`:
1. **Pacstrap base**: 14 packages (`base`, `base-devel`, `mkinitcpio`, `linux-firmware`, `intel-ucode`, `grub`, `efibootmgr`, `xfsprogs`, `networkmanager`, `sudo`, `git`, `curl`, `nano`, `vim`).
2. **Kernel & CachyOS base**: 10 packages (`mkinitcpio`, `linux-cachyos-bore`, `linux-cachyos-bore-headers`, `cachyos-settings`, `scx-scheds`, `ananicy-cpp`, `cachyos-ananicy-rules`, `zram-generator`, `linux-firmware`, `intel-ucode`).
3. **GPU Drivers (`detect_and_install_gpu`)**:
   - Intel/Universal: `mesa`, `libva-intel-driver`, `intel-media-driver`, `vulkan-intel`, `vulkan-icd-loader`, `xf86-video-intel`, `intel-ucode`.
   - AMD: `mesa`, `vulkan-radeon`, `libva-mesa-driver`, `mesa-vdpau`, `vulkan-icd-loader`, `xf86-video-amdgpu`.
   - NVIDIA: `mesa`, `vulkan-icd-loader`, `nvidia`, `nvidia-utils`.
4. **`install_pacman_packages`**: 11 groups (81 packages total).
5. **`install_aur_packages`**: 5 groups (10 packages total).
6. **Reference snapshots**: `/home/chezok/dotfiles/packages/pacman.txt` (91 entries) and `packages/aur.txt` (9 entries).

Every package was queried directly on the host using `pacman -Si <pkg>` and `yay -Si <pkg>`.

---

### 1.2 Verbatim Findings & Tool Commands

#### Finding 1: Verification of `neofetch` Deprecation & Replacement with `fastfetch`
- **Host Query**:
  ```bash
  $ pacman -Si neofetch
  error: package 'neofetch' was not found
  ```
- **Observed Failure in Stage 1 Serial Log (`tests/build/stage1_serial.log`, lines 2932-2937)**:
  ```text
  [INFO]  Устанавливаем: btop htop nvtop cmatrix neofetch genact aria2 playerctl brightnessctl libnotify jq tty-clock nodejs npm lua-luv
  error: target not found: neofetch
  warning: playerctl-2.4.1-5 is up to date -- skipping
  warning: libnotify-0.8.8-1 is up to date -- skipping
  warning: jq-1.8.2-1 is up to date -- skipping
  [WARN]  Некоторые пакеты из группы не найдены: btop htop nvtop cmatrix neofetch genact aria2 playerctl brightnessctl libnotify jq tty-clock nodejs npm lua-luv
  ```
- **Replacement Package Verification**:
  ```bash
  $ pacman -Si fastfetch
  Repository      : cachyos-extra-v3
  Name            : fastfetch
  Version         : 2.69.0-1.1
  Description     : Like neofetch, but much faster because written in C
  ```
- **Current Repository Status**:
  In commit `295a136` (`fix(installer): replace neofetch with fastfetch and fix yay noninteractive flags`), `neofetch` has already been substituted with `fastfetch` in line 850 of both `install-arch.sh` and `install.sh`.

---

#### Finding 2: Dead Package `mesa-vdpau` in AMD GPU Installation Block
- **Source Files**: `/home/chezok/dotfiles/install-arch.sh` line 796 and `install.sh` line 796:
  ```bash
  pacman -S --noconfirm --needed \
      mesa vulkan-radeon libva-mesa-driver mesa-vdpau vulkan-icd-loader \
      xf86-video-amdgpu 2>/dev/null || true
  ```
- **Host Query**:
  ```bash
  $ pacman -Si mesa-vdpau
  error: package 'mesa-vdpau' was not found
  $ pacman -Sp mesa vulkan-radeon libva-mesa-driver mesa-vdpau vulkan-icd-loader xf86-video-amdgpu
  error: target not found: mesa-vdpau
  ```
- **Impact**:
  Because pacman transactions are atomic, specifying `mesa-vdpau` causes `pacman -S` to abort immediately with exit code 1. On any system with an AMD GPU, the entire driver group (`vulkan-radeon`, `xf86-video-amdgpu`, etc.) fails to install silently due to `2>/dev/null || true`.
- **Note on `libva-mesa-driver`**:
  `libva-mesa-driver` is a virtual package provided by `mesa` (`Provides: libva-mesa-driver=3:26.2.4-1`). Since `mesa` is already installed, `libva-mesa-driver` is redundant, while `mesa-vdpau` is completely missing and must be removed.

---

#### Finding 3: Missing Generic `nvidia` Package in CachyOS Repository
- **Source Files**: `/home/chezok/dotfiles/install-arch.sh` line 811 and `install.sh` line 811:
  ```bash
  pacman -S --noconfirm --needed nvidia nvidia-utils vulkan-icd-loader 2>/dev/null || true
  ```
- **Host Query**:
  ```bash
  $ pacman -Si nvidia
  error: package 'nvidia' was not found
  ```
- **Root Cause**:
  In Arch Linux, `nvidia` targets the upstream Arch `linux` kernel. In CachyOS with `linux-cachyos-bore`, the kernel module package is named `linux-cachyos-bore-nvidia-open` (or `nvidia-open-dkms`). Requesting `nvidia` fails with `target not found: nvidia`.
- **Verified Replacement**:
  ```bash
  $ pacman -Si linux-cachyos-bore-nvidia-open
  Repository      : cachyos
  Name            : linux-cachyos-bore-nvidia-open
  Version         : 7.2.7-1
  Description     : nvidia open modules of 615.71.09 driver for the linux-cachyos-bore kernel
  ```

---

#### Finding 4: Direct Package Conflict: `ayugram-desktop` vs `ayugram-desktop-bin`
- **Source Files**:
  - `install_pacman_packages` (line 847):
    `"zen-browser-bin ayugram-desktop firefox mpv cava"`
  - `install_aur_packages` (line 879):
    `"zen-browser-bin ayugram-desktop-bin"`
- **Host Query**:
  ```bash
  $ yay -Si ayugram-desktop-bin | grep -i conflicts
  Conflicts With                : ayugram-desktop
  $ pacman -Qe | grep ayu
  ayugram-desktop 7.0.9-5
  $ grep ayu packages/pacman.txt
  ayugram-desktop 7.0.9-5
  ```
- **Impact**:
  `ayugram-desktop` is an official binary package provided directly by the CachyOS repository (`cachyos/ayugram-desktop 7.0.9-5`), and is already installed via `pacman` in Phase 2.
  When `install_aur_packages` subsequently executes `yay -S ... ayugram-desktop-bin`, `ayugram-desktop-bin` conflicts with the installed `ayugram-desktop`.
- **Duplication with `zen-browser-bin`**:
  `zen-browser-bin` is also an official binary package provided by CachyOS repository (`cachyos/zen-browser-bin 1.22.3b-1`). It is already installed via pacman in Group 8. Re-requesting it in `aur_groups` is redundant and unnecessary.

---

#### Finding 5: Inter-Phase Redundancies and Duplications
1. **Intel GPU Stack Duplication**:
   - `detect_and_install_gpu` (lines 781-783, 819): Installs `mesa libva-intel-driver intel-media-driver vulkan-intel vulkan-icd-loader xf86-video-intel intel-ucode`.
   - `install_pacman_packages` Group 4 (line 835): Identically requests `"mesa libva-intel-driver intel-media-driver vulkan-intel vulkan-icd-loader xf86-video-intel intel-ucode libglvnd at-spi2-core"`.
   - Only `libglvnd` and `at-spi2-core` are unique in Group 4.
2. **`intel-ucode` Multi-Installation**:
   - Requested 4 separate times: Pacstrap (line 231), Kernel (line 515), GPU detection (lines 783, 789, 819), and Group 4 (line 835).
3. **`networkmanager`**:
   - Installed in Pacstrap (line 233) and re-requested in Group 1 (line 826).

---

### 1.3 Full Audit Table of All 112 Unique Packages

| Package Name | Origin | Status | Repository / Provider | Notes |
|:---|:---:|:---:|:---:|:---|
| `ananicy-cpp` | pacman | **VALID** | `cachyos-extra-v3 1.2.0-1.1` | Kernel process priority daemon |
| `aria2` | pacman | **VALID** | `cachyos-extra-v3 1.37.0-3.1` | Download utility |
| `at-spi2-core` | pacman | **VALID** | `cachyos-extra-v3 2.60.7-1.1` | Accessibility framework |
| `awww` | pacman | **VALID** | `cachyos-extra-v3 0.12.1-1.1` | Wayland wallpaper daemon |
| `ayugram-desktop` | pacman | **VALID** | `cachyos 7.0.9-5` | Telegram desktop client (CachyOS binary) |
| `ayugram-desktop-bin` | AUR | **CONFLICT** | `AUR 7.0.9-5` | Conflicts with `ayugram-desktop` |
| `base` | pacman | **VALID** | `core 3-3` | Base system |
| `base-devel` | pacman | **VALID** | `core 1-2` | Build essentials for makepkg |
| `bluez` | pacman | **VALID** | `cachyos-extra-v3 5.87-2.1` | Bluetooth daemon |
| `bluez-utils` | pacman | **VALID** | `cachyos-extra-v3 5.87-2.1` | Bluetooth tools |
| `brightnessctl` | pacman | **VALID** | `extra 0.5.1-3` | Display brightness tool |
| `btop` | pacman | **VALID** | `cachyos-extra-v3 1.4.7-1.1` | Resource monitor |
| `cachyos-ananicy-rules`| pacman | **VALID** | `cachyos 1` | Ananicy rule presets |
| `cachyos-settings` | pacman | **VALID** | `cachyos 1` | CachyOS system optimization config |
| `cava` | pacman | **VALID** | `cachyos-extra-v3 1.0.0-1.1` | Audio visualizer |
| `cliphist` | pacman | **VALID** | `cachyos-extra-v3 1:0.7.0-2.1` | Wayland clipboard manager |
| `cmatrix` | pacman | **VALID** | `cachyos-extra-v3 2.0-4.1` | Terminal screensaver |
| `curl` | pacman | **VALID** | `cachyos-core-v3 8.22.0-1.1` | HTTP client |
| `dosfstools` | pacman | **VALID** | `cachyos-core-v3 4.2-5.1` | FAT32 filesystem utilities |
| `efibootmgr` | pacman | **VALID** | `cachyos-core-v3 18-4.1` | UEFI boot manager tool |
| `exfatprogs` | pacman | **VALID** | `cachyos-extra-v3 1.4.3-1.1` | exFAT filesystem utilities |
| `fastfetch` | pacman | **VALID** | `cachyos-extra-v3 2.69.0-1.1` | System information fetch (replaces neofetch) |
| `firefox` | pacman | **VALID** | `cachyos-extra-v3 157.0-1.1` | Web browser |
| `foot` | pacman | **VALID** | `cachyos-extra-v3 1.28.0-2.1` | Wayland terminal emulator |
| `genact` | pacman | **VALID** | `cachyos-extra-v3 1.6.0-1.1` | Activity generator |
| `git` | pacman | **VALID** | `cachyos-extra-v3 2.56.0-1.1` | Version control |
| `gnu-free-fonts` | pacman | **VALID** | `extra 20120503-9` | Unicode fonts |
| `grub` | pacman | **VALID** | `cachyos-core-v3 2:2.16-1.1` | UEFI bootloader |
| `htop` | pacman | **VALID** | `cachyos-extra-v3 3.5.3-1.1` | Interactive process viewer |
| `hyprland` | pacman | **VALID** | `cachyos-extra-v3 0.56.2-3.1` | Wayland dynamic tiling compositor |
| `intel-media-driver` | pacman | **VALID** | `cachyos-extra-v3 26.3.5-1.1` | Intel Broadwell+ VA-API driver |
| `intel-ucode` | pacman | **VALID** | `extra 20260925-1` | Intel CPU microcode |
| `jq` | pacman | **VALID** | `cachyos-extra-v3 1.8.2-1.1` | JSON parser |
| `kconfig` | pacman | **VALID** | `cachyos-extra-v3 6.30.0-1.1` | KDE Frameworks 6 |
| `kcoreaddons` | pacman | **VALID** | `cachyos-extra-v3 6.30.0-1.1` | KDE Frameworks 6 |
| `kdeclarative` | pacman | **VALID** | `cachyos-extra-v3 6.30.0-1.1` | KDE Frameworks 6 |
| `kiconthemes` | pacman | **VALID** | `cachyos-extra-v3 6.30.0-1.1` | KDE Frameworks 6 |
| `kirigami` | pacman | **VALID** | `cachyos-extra-v3 6.30.0-1.1` | KDE Frameworks 6 UI components |
| `kitty` | pacman | **VALID** | `cachyos-extra-v3 0.49.2-1.1` | GPU accelerated terminal emulator |
| `lavat` | AUR | **VALID** | `AUR 3.0.0-1` | Lava lamp effect |
| `libglvnd` | pacman | **VALID** | `cachyos-extra-v3 1.7.0-3.1` | GL Vendor-Neutral Dispatch |
| `libnotify` | pacman | **VALID** | `cachyos-extra-v3 0.8.8-1.1` | Desktop notification library |
| `libva-intel-driver` | pacman | **VALID** | `cachyos-extra-v3 2.4.5-1.1` | Intel Ivy Bridge VA-API legacy driver |
| `libva-mesa-driver` | pacman | **VIRTUAL** | Provided by `mesa` | Redundant with `mesa` |
| `linux-cachyos-bore` | pacman | **VALID** | `cachyos-v3 7.2.8-1` | BORE scheduler optimized kernel |
| `linux-cachyos-bore-headers`| pacman | **VALID** | `cachyos-v3 7.2.8-1` | Kernel headers |
| `linux-firmware` | pacman | **VALID** | `cachyos 1:20260916-1` | Hardware firmware |
| `lua-luv` | pacman | **VALID** | `extra 1.52.1-1` | Libuv bindings for Lua |
| `matugen` | pacman | **VALID** | `cachyos-extra-v3 4.2.0-1.1` | Material You color palette generator |
| `mesa` | pacman | **VALID** | `cachyos 3:26.2.4-1` | Open-source OpenGL/Vulkan/VA-API drivers |
| `mesa-vdpau` | pacman | **DEAD** | *None* | Dropped from repos; breaks AMD group |
| `mkinitcpio` | pacman | **VALID** | `core 42.1-1` | Initramfs generator |
| `mpv` | pacman | **VALID** | `cachyos-extra-v3 1:0.40.0-1.1`| Media player |
| `nano` | pacman | **VALID** | `cachyos-core-v3 9.2-1.1` | Simple text editor |
| `nemo` | pacman | **VALID** | `cachyos-extra-v3 6.6.4-1.1` | Cinnamon file manager |
| `neofetch` | pacman | **DEAD** | *None* | Replaced by `fastfetch` in commit 295a136 |
| `networkmanager` | pacman | **VALID** | `extra 1.58.1-2` | Network management daemon |
| `niri` | pacman | **VALID** | `cachyos-extra-v3 26.04-1.1` | Scrollable-tiling Wayland compositor |
| `nodejs` | pacman | **VALID** | `cachyos-v3 26.10.0-3` | JavaScript runtime |
| `noto-fonts` | pacman | **VALID** | `extra 1:26.4.1-1` | Google Noto TTF fonts |
| `noto-fonts-emoji` | pacman | **VALID** | `extra 1:2.051-1` | Color emoji font |
| `npm` | pacman | **VALID** | `extra 12.2.0-1` | Node.js package manager |
| `ntfs-3g` | pacman | **VALID** | `cachyos-extra-v3 2026.9.28-1.1`| NTFS read/write driver |
| `nvidia` | pacman | **MISSING** | *None (Arch stock only)* | Use `linux-cachyos-bore-nvidia-open` |
| `nvidia-utils` | pacman | **VALID** | `cachyos-v3 615.71.09-1` | NVIDIA driver userland utilities |
| `nvtop` | pacman | **VALID** | `cachyos-extra-v3 3.3.2-1.1` | GPU process monitor |
| `openssh` | pacman | **VALID** | `cachyos-core-v3 10.5p1-1.1` | SSH daemon |
| `pavucontrol` | pacman | **VALID** | `cachyos-extra-v3 1:6.2-1.1` | PulseAudio/PipeWire volume control |
| `pipes.sh` | AUR | **VALID** | `AUR 1.3.0-1` | Terminal screensaver |
| `pipewire` | pacman | **VALID** | `extra 1:1.6.9-1` | Low-latency audio server |
| `pipewire-jack` | pacman | **VALID** | `extra 1:1.6.9-1` | JACK client library wrapper |
| `pipewire-pulse` | pacman | **VALID** | `extra 1:1.6.9-1` | PulseAudio replacement daemon |
| `playerctl` | pacman | **VALID** | `cachyos-extra-v3 2.4.1-5.1` | MPRIS media player controller |
| `power-profiles-daemon`| pacman | **VALID** | `cachyos 0.30-3` | Power management service |
| `python-pywal` | AUR | **VALID** | `AUR 3.3.0-11` | Color scheme generator from wallpapers |
| `qt6-5compat` | pacman | **VALID** | `cachyos-extra-v3 6.11.2-1.1` | Qt6 5-compatibility module |
| `qt6-declarative` | pacman | **VALID** | `cachyos-extra-v3 6.11.2-2.1` | Qt6 QML / Quick engine |
| `qt6-multimedia` | pacman | **VALID** | `cachyos-extra-v3 6.11.2-1.1` | Qt6 multimedia classes |
| `qt6-positioning` | pacman | **VALID** | `cachyos-extra-v3 6.11.2-1.1` | Qt6 positioning classes |
| `qt6-sensors` | pacman | **VALID** | `cachyos-extra-v3 6.11.2-1.1` | Qt6 sensor classes |
| `qt6-virtualkeyboard` | pacman | **VALID** | `cachyos-extra-v3 6.11.2-1.1` | Qt6 virtual keyboard framework |
| `quickshell` | pacman | **VALID** | `cachyos-extra-v3 0.3.1-1.1` | QML desktop shell library |
| `rofi` | pacman | **VALID** | `cachyos-extra-v3 2.0.0-1.1` | Application launcher |
| `scx-scheds` | pacman | **VALID** | `extra 1.1.3-2` | sched_ext BPF schedulers |
| `sddm` | pacman | **VALID** | `cachyos-v3 0.21.0-8` | QML-based display manager |
| `sptlrx-bin` | AUR | **VALID** | `AUR 1.3.1-1` | Synchronized lyrics in terminal |
| `sudo` | pacman | **VALID** | `cachyos-core-v3 1.9.17.p2-6.1` | Privilege escalation |
| `swaync` | pacman | **VALID** | `cachyos-extra-v3 0.12.6-1.1` | Sway notification center |
| `ttf-jetbrains-mono-nerd`| pacman | **VALID** | `extra 3.5.1-2` | Monospace nerd font |
| `ttf-nerd-fonts-symbols-mono`| pacman | **VALID** | `extra 3.5.1-1` | Nerd fonts symbols |
| `tty-clock` | pacman | **VALID** | `cachyos 2.3-2` | Terminal digital clock |
| `udiskie` | pacman | **VALID** | `extra 2.7.0-2` | Removable drive automounter |
| `udisks2` | pacman | **VALID** | `cachyos-extra-v3 2.11.2-1.1` | Disk management service |
| `unimatrix-git` | AUR | **VALID** | `AUR r89.5cf67aa-1` | Matrix digital rain effect |
| `vibepanel-bin` | AUR | **VALID** | `AUR 0.16.1-1` | Pre-built binary bar/panel |
| `vibepanel-git` | AUR | **VALID** | `AUR 0.16.1.r0.g92420c6-1` | Git source fallback for vibepanel |
| `vim` | pacman | **VALID** | `cachyos-extra-v3 9.2.1046-1.1` | Text editor |
| `vulkan-icd-loader` | pacman | **VALID** | `cachyos-extra-v3 1.4.357.0-1.1`| Vulkan Installable Client Driver loader |
| `vulkan-intel` | pacman | **VALID** | `cachyos 3:26.2.4-1` | Intel open-source Vulkan driver |
| `vulkan-radeon` | pacman | **VALID** | `cachyos 3:26.2.4-1` | AMD open-source Vulkan driver |
| `waybar` | pacman | **VALID** | `cachyos-extra-v3 0.15.0-3.1` | Highly customizable Wayland bar |
| `wayland` | pacman | **VALID** | `cachyos-extra-v3 1.26.0-1.1` | Wayland display protocol libraries |
| `waylyrics` | AUR | **VALID** | `AUR 0.4.6-1` | Desktop lyrics widget |
| `weston` | pacman | **VALID** | `cachyos-extra-v3 15.0.1-3.1` | Wayland reference compositor |
| `wireplumber` | pacman | **VALID** | `cachyos-extra-v3 0.5.18-1.1` | PipeWire session/policy manager |
| `wl-clipboard` | pacman | **VALID** | `cachyos-extra-v3 1:2.3.0-1.1` | Command line Wayland clipboard tools |
| `xdg-desktop-portal-gtk`| pacman | **VALID** | `cachyos-extra-v3 1.15.3-1.1` | Desktop portal backend for GTK |
| `xf86-video-amdgpu` | pacman | **VALID** | `cachyos-extra-v3 25.0.0-1.1` | AMD GPU Xorg DDX driver |
| `xf86-video-intel` | pacman | **VALID** | `cachyos-extra-v3 1:2.99.917+939+g4a64400e-1` | Intel Ivy Bridge DDX driver |
| `xfsprogs` | pacman | **VALID** | `cachyos-core-v3 7.2.0-1.1` | XFS filesystem utilities |
| `xwayland-satellite` | pacman | **VALID** | `cachyos-extra-v3 0.8.3-1.1` | Xwayland manager outside window manager |
| `zen-browser-bin` | pacman | **VALID** | `cachyos 1.22.3b-1` | Performance-oriented browser (CachyOS binary) |
| `zram-generator` | pacman | **VALID** | `cachyos-extra-v3 1.2.1-1.1` | Dynamic zram swap generator |

---

## 2. Logic Chain

1. **Transaction Atomicity in `pacman`**:
   - `pacman -S` validates all targets before downloading or committing any packages. If a single target fails name/provider resolution (`target not found`), pacman halts and rejects the transaction.
   - Observations 1.2 (Finding 1 and Finding 2) confirm that `neofetch` and `mesa-vdpau` cause immediate termination of their respective commands.
   - In Stage 1, the presence of `neofetch` resulted in 11 system utilities (`btop`, `htop`, `nvtop`, `cmatrix`, `genact`, `aria2`, `tty-clock`, `nodejs`, `npm`, `lua-luv`) being omitted from the disk.
   - In `detect_and_install_gpu`, the presence of `mesa-vdpau` causes `pacman -S` to fail for AMD graphics hardware.

2. **CachyOS Kernel Module Packaging**:
   - Upstream Arch package `nvidia` is linked to Arch's `linux` package. CachyOS packages kernel-specific open modules (`linux-cachyos-bore-nvidia-open`) or DKMS modules (`nvidia-open-dkms`).
   - Invoking `pacman -S nvidia` in the installer fails because `nvidia` does not exist in CachyOS repository indexes.

3. **Package Ownership and AUR Conflict Resolution**:
   - In Arch Linux and CachyOS, `ayugram-desktop` is the repository binary package, while `ayugram-desktop-bin` is an AUR recipe that explicitly specifies `Conflicts With: ayugram-desktop`.
   - Because `install_pacman_packages` installs `ayugram-desktop` from CachyOS binary mirrors, subsequent execution of `yay -S ayugram-desktop-bin` triggers an interactive or conflict-aborted replacement prompt.
   - Similarly, `zen-browser-bin` is already packaged in CachyOS official binary mirrors.
   - By removing `zen-browser-bin ayugram-desktop-bin` from unconditional AUR installation and guarding them with `pacman -Q` checks as fallbacks, conflict and duplicate transactions are completely avoided.

4. **In-Guest Acceptance Test Integrity**:
   - The test suite in `tests/vm_acceptance_check.sh` asserted only 14 checks (kernel, services, bootloader files), omitting package verification for desktop components (`vibepanel`, `zen-browser-bin`, `ayugram-desktop`, `niri`, `hyprland`, `waybar`, `sddm`, `btop`).
   - Because installer shell scripts masked failures with `|| warn "..."`, exit code 0 was returned despite failed package groups, producing a misleading 14/14 PASS result.
   - Expanding `tests/vm_acceptance_check.sh` with 6 explicit package checks (Checks 15–20) establishes a verifiable contract guaranteeing all R1 features are actually installed on disk.

---

## 3. Caveats

1. **Repository Synchronization**: The audit was conducted against host CachyOS and Arch mirrors (`cachyos-v3`, `cachyos-extra-v3`, `extra`, `core`). In isolated offline environments, mirrorlist fallback behavior must rely on local pacman cache or valid nameservers in `/etc/resolv.conf`.
2. **`mesa` Virtual Provides**: While `libva-mesa-driver` is provided by `mesa`, it is not a standalone package. `pacman -S libva-mesa-driver` succeeds due to virtual provides, but explicitly passing it is redundant when `mesa` is present.
3. **Hardware Specifics**: The test runner runs in QEMU with a generic display controller, which exercises the Intel/Universal fallback driver path (`mesa`, `vulkan-intel`, `intel-media-driver`, `xf86-video-intel`). AMD and NVIDIA branches are verified for repository package syntax but not exercised at runtime in standard QEMU VM runs.

---

## 4. Conclusion

1. **Dead Packages**:
   - `neofetch`: Discontinued. Successfully replaced by `fastfetch` in commit `295a136`.
   - `mesa-vdpau`: Non-existent. Must be removed from AMD GPU installation line.
   - `nvidia`: Non-existent in CachyOS. Must be replaced with `linux-cachyos-bore-nvidia-open` / `nvidia-open-dkms`.
2. **Conflicts & Duplicates**:
   - `ayugram-desktop-bin` conflicts with repository `ayugram-desktop`.
   - `zen-browser-bin` is a duplicate between pacman and AUR groups.
   - Resolution: Keep `zen-browser-bin` and `ayugram-desktop` in pacman groups; in AUR, wrap them with fallback guards (`pacman -Q <pkg> &>/dev/null || yay -S ...`).
3. **Test Suite Expansion**:
   - Added Checks 15–20 to `tests/vm_acceptance_check.sh` to validate `vibepanel`, `zen-browser-bin`, `ayugram-desktop`, desktop environment compositors (`niri`, `hyprland`, `waybar`, `sddm`), CLI utilities (`btop`, `htop`, `fastfetch`), and the graphics stack.
4. **Patch Ready**:
   - The unified patch `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m2_4/package_audit.patch` has been generated and validated with `patch --dry-run -p1`.

---

## 5. Verification Method

To independently verify the audit and proposed patch:

```bash
# 1. Verify that all audited packages exist in repositories
python3 -c "
import subprocess
pkgs = ['fastfetch', 'btop', 'htop', 'ayugram-desktop', 'zen-browser-bin', 'niri', 'hyprland', 'waybar', 'sddm', 'mesa', 'vulkan-intel']
for p in pkgs:
    r = subprocess.run(['pacman', '-Si', p], capture_output=True)
    assert r.returncode == 0, f'Package {p} missing!'
print('All core packages verified in pacman!')
"

# 2. Verify that dead packages are truly missing
pacman -Si neofetch 2>&1 | grep -q "not found" && echo "Confirmed: neofetch is dead"
pacman -Si mesa-vdpau 2>&1 | grep -q "not found" && echo "Confirmed: mesa-vdpau is dead"
pacman -Si nvidia 2>&1 | grep -q "not found" && echo "Confirmed: generic nvidia is missing in CachyOS"

# 3. Test patch application with dry run
patch --dry-run -p1 < /home/chezok/dotfiles/.agents/teamwork_preview_explorer_m2_4/package_audit.patch

# 4. Verify bash syntax on target scripts
bash -n /home/chezok/dotfiles/install-arch.sh
bash -n /home/chezok/dotfiles/install.sh
bash -n /home/chezok/dotfiles/tests/vm_acceptance_check.sh
```
