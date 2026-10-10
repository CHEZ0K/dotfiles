# Handoff Report — Survey Explorer 2: Host System State, Package Inventory & Dependency Mapping (R1 & R2)

## 1. Observation

### 1.1 Host Environment & Hardware Profile
- **Kernel (`uname -a`)**:
  ```text
  Linux cachyos 7.2.4-3-cachyos-bore #1 SMP PREEMPT_DYNAMIC Fri, 11 Sep 2026 21:55:52 +0000 x86_64 GNU/Linux
  ```
- **OS Release (`/etc/os-release`)**:
  ```text
  NAME="Arch Linux"
  PRETTY_NAME="Arch Linux"
  ID=arch
  BUILD_ID=rolling
  ```
- **Current Host CPU & Architecture (`lscpu`)**:
  - Architecture: `x86_64`
  - Vendor / Model: `AuthenticAMD`, `AMD Ryzen 5 3500U with Radeon Vega Mobile Gfx`
  - Instruction set: Supports `x86-64-v3` (`/lib/ld-linux-x86-64.so.2 --help` confirms `x86-64-v3 (supported, search path ...)`).
- **Target Hardware Identified in ORIGINAL_REQUEST.md (R1 & R3)**:
  - CPU: Intel Ivy Bridge / Pentium 2020M (`x86_64` generic, **no AVX, no x86-64-v3**).
  - GPU: Intel Ivy Bridge Gen 7 HD Graphics (`crocus` OpenGL, `i965` VA-API, `anv` Vulkan).
  - UEFI BIOS: Strict requirement for fallback removable bootloader (`/boot/efi/EFI/BOOT/BOOTX64.EFI`).

---

### 1.2 Pacman Repository Configuration (`/etc/pacman.conf`)
The host `/etc/pacman.conf` enables seven repositories in the following order:
```ini
[cachyos-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-core-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos-extra-v3]
Include = /etc/pacman.d/cachyos-v3-mirrorlist

[cachyos]
Include = /etc/pacman.d/cachyos-mirrorlist

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[multilib]
Include = /etc/pacman.d/mirrorlist
```
**Architecture Precedence Rule**:
- On `x86-64-v3` CPUs (host), pacman prioritizes `cachyos-*-v3` repos.
- On Intel Ivy Bridge / Pentium 2020M (target), `cachyos-*-v3` **must be omitted**, and only `[cachyos]` (generic x86_64), `[core]`, `[extra]`, and `[multilib]` must be enabled. Binaries compiled for v3 will fail with `Illegal instruction` (`SIGILL`) on Pentium 2020M.

---

### 1.3 Complete Inventory of Explicitly Installed Packages (`pacman -Qe`)
There are **exactly 90 explicitly installed packages** on the current system, grouped by source repository:

| Repository | Count | Packages |
|---|---|---|
| **cachyos** (generic x86_64) | 12 | `ayugram-desktop`, `cachyos-keyring`, `cachyos-mirrorlist`, `cachyos-settings`, `cachyos-v3-mirrorlist`, `cachyos-v4-mirrorlist`, `linux-firmware`, `neofetch`, `power-profiles-daemon`, `tty-clock`, `yay`, `zen-browser-bin` |
| **cachyos-core-v3** / **core** | 9 | `base`, `base-devel`, `dosfstools`, `efibootmgr`, `grub`, `nano`, `openssh`, `sudo`, `xfsprogs` |
| **cachyos-extra-v3** / **extra** | 55 | `aria2`, `awww`, `bluez`, `bluez-utils`, `brightnessctl`, `btop`, `cava`, `cliphist`, `cmatrix`, `exfatprogs`, `firefox`, `foot`, `genact`, `git`, `htop`, `hyprland`, `jq`, `kconfig`, `kcoreaddons`, `kdeclarative`, `kiconthemes`, `kirigami`, `kitty`, `libnotify`, `lua-luv`, `matugen`, `nemo`, `networkmanager`, `niri`, `noto-fonts-emoji`, `npm`, `ntfs-3g`, `nvtop`, `pavucontrol`, `pipewire`, `pipewire-pulse`, `qt6-5compat`, `qt6-multimedia`, `qt6-positioning`, `qt6-sensors`, `qt6-virtualkeyboard`, `quickshell`, `rofi`, `scx-scheds`, `swaync`, `ttf-jetbrains-mono-nerd`, `ttf-nerd-fonts-symbols-mono`, `udiskie`, `vim`, `waybar`, `wayland`, `weston`, `wireplumber`, `wl-clipboard`, `xwayland-satellite` |
| **cachyos-v3** / **cachyos** | 4 | `linux-cachyos-bore`, `linux-cachyos-bore-headers`, `nodejs`, `sddm` |
| **multilib** | 1 | `steam` |
| **AUR / Foreign** (`pacman -Qm`) | 9 | `antigravity-cli`, `lavat`, `linux-wallpaperengine-git`, `pipes.sh`, `python-pywal`, `sptlrx-bin`, `unimatrix-git`, `vibepanel-git`, `waylyrics` |

---

### 1.4 Functional Categorization of Packages

#### A. Kernel, Scheduling & Hardware Layer
- `linux-cachyos-bore` (7.2.4-3) — CachyOS BORE scheduler kernel.
- `linux-cachyos-bore-headers` (7.2.4-3) — Kernel headers.
- `cachyos-settings` (1:1.4.0-1) — CachyOS udev rules, sysctl tweaks, zram/ananicy configs.
- `scx-scheds` (1.1.3-2) — sched_ext BPF schedulers (starts via `scx.service`).
- `linux-firmware` (1:20260910-1) — Base firmware images.
- `power-profiles-daemon` (0.30-3) — D-Bus power state management.
- `brightnessctl` (0.5.1-3) — Backlight control for laptops.

#### B. Graphics Stack (Intel Ivy Bridge Target vs Host)
- Target Ivy Bridge packages (all available in `extra` / `cachyos`):
  - `mesa` (3:26.2.2-2) — Provides `crocus` Gallium driver for Intel Gen 7 GPU.
  - `xf86-video-intel` (1:2.99.917+939+g4a64400e-1) — Intel X11 video driver.
  - `vulkan-intel` (3:26.2.2-2) — `anv` Vulkan driver.
  - `libva-intel-driver` (2.4.5-1) — VA-API `i965_drv_video.so` hardware video acceleration.
  - `vulkan-icd-loader` (1.4.357.0-1.1) — Vulkan dispatch loader.

#### C. Wayland Compositors & Display Management
- `niri` (26.04-1.1) — Primary tiling scrollable Wayland compositor.
- `hyprland` (0.56.2-3.1) — Secondary dynamic tiling Wayland compositor.
- `xwayland-satellite` (0.8.2-1) — Rootless Xwayland integration for Niri.
- `sddm` (0.21.0-8) — Display manager.
- `weston` (15.0.1-3.1) — Used as kiosk backend for SDDM Wayland greeter (`CompositorCommand=weston --shell=kiosk`).
- `wayland` (1.26.0-1.1), `wl-clipboard` (1:2.3.0-1.1), `cliphist` (1:0.7.0-2.1).

#### D. Desktop Shell, Widgets, Panels & Theming
- `vibepanel-git` (0.16.1.r6.g14d8283-1, AUR) — GTK4 panel with quick settings.
  - *Alternative*: `vibepanel-bin` (0.16.1-1, AUR) downloads prebuilt GitHub release with `Make Deps: None`.
- `quickshell` (0.3.1-1.1, `extra` / `cachyos-extra-v3`) — QML desktop shell.
- `waybar` (0.15.0-3.1, `extra` / `cachyos-extra-v3`) — Modular status bar.
- `swaync` (0.12.6-1.1, `extra` / `cachyos-extra-v3`) — Notification center.
- `awww` (0.12.1-1.1, `extra` / `cachyos-extra-v3`) — Wayland wallpaper daemon.
- `rofi` (2.0.0-1.1, `extra` / `cachyos-extra-v3`) — App launcher.
- `matugen` (4.2.0-1.1, `extra` / `cachyos-extra-v3`) — Material You palette generator.
- `python-pywal` (3.3.0-11, AUR) — Dynamic wallpaper palette generation.
- Qt6 & KDE Frameworks libraries: `qt6-5compat`, `qt6-multimedia`, `qt6-positioning`, `qt6-sensors`, `qt6-virtualkeyboard`, `kconfig`, `kcoreaddons`, `kdeclarative`, `kiconthemes`, `kirigami`.
- Fonts: `ttf-jetbrains-mono-nerd`, `ttf-nerd-fonts-symbols-mono`, `noto-fonts-emoji`.

#### E. Network & Audio Stack
- `networkmanager` (1.58.1-1) — Network manager.
- `bluez` (5.87-2.1), `bluez-utils` (5.87-2.1) — Bluetooth stack.
- `pipewire` (1:1.6.8-1), `pipewire-pulse` (1:1.6.8-1), `wireplumber` (0.5.17-1.1), `pavucontrol` (1:6.2-1.1).

#### F. Applications & Utilities
- `zen-browser-bin` (1.22.1b-1, `cachyos`) — Zen Browser. Prebuilt binary in `cachyos` repo!
- `ayugram-desktop` (7.0.9-5, `cachyos`) / `ayugram-desktop-bin` (AUR) — AyuGram Telegram client. Prebuilt binary in `cachyos` repo!
- `foot` (1.28.0-2.1) & `kitty` (0.48.2-1.1) — Terminals.
- `nemo` (6.6.4-1.1) — Cinnamon file manager.
- Storage utilities: `udisks2` (installed as dep), `udiskie` (2.7.0-2), `ntfs-3g` (2026.7.7-1.1), `dosfstools` (4.2-5.1), `exfatprogs` (1.4.3-1.1), `xfsprogs` (7.1.1-1.1).
- Terminal & Audio eye-candy: `cava` (1.0.0-1.1), `cmatrix` (2.0-4.1), `tty-clock` (2.3-2), `lavat` (3.0.0-1, AUR), `pipes.sh` (1.3.0-1, AUR), `unimatrix-git` (r103, AUR), `sptlrx-bin` (1.3.1-1, AUR), `waylyrics` (0.4.6-1, AUR), `linux-wallpaperengine-git` (AUR).
- System monitors: `btop` (1.4.7-1.1), `htop` (3.5.3-1.1), `nvtop` (3.3.2-1.1), `neofetch` (7.1.0-4), `genact` (1.5.1-2.1).
- Scripting & CLI tools: `jq` (1.8.2-1.1), `aria2` (1.37.0-3.1), `libnotify` (0.8.8-1.1), `nodejs` (26.8.2-1), `npm` (12.0.2-1), `lua-luv` (1.52.1-1), `vim` (9.2.1046-1.1), `nano` (9.2-1.1), `openssh` (10.5p1-1.1).

---

### 1.5 Current Script Audit (`install-arch.sh` / `install.sh`)

1. **Pacstrap Redundancy (lines 174-179)**:
   ```bash
   pacstrap -K /mnt \
       base base-devel \
       linux linux-headers linux-firmware \
       grub efibootmgr xfsprogs \
       networkmanager sudo git curl nano vim
   ```
   *Issue*: It installs standard Arch `linux` and `linux-headers`, then later installs `linux-cachyos-bore` inside chroot. Standard Arch kernel is not present in `pacman -Qe` on the host, wastes 250MB disk space, and causes `grub-mkconfig` to generate multiple boot entries.

2. **Packages Missing from `install-arch.sh` but required by R1 / Host**:
   - `hyprland` — Explicitly mandated in R1 ("Hyprland (`hyprland`)"); missing from `install_pacman_packages`.
   - `waybar` — Explicitly mandated in R1 ("`waybar`"); missing from `install_pacman_packages`.
   - `weston` — Required by line 469 (`CompositorCommand=weston --shell=kiosk`) for SDDM Wayland greeter.
   - `jq` — Installed on host, required by several waybar and utility scripts.
   - `cmatrix`, `nvtop`, `kitty` — Installed on host.

3. **Unnecessary Packages in `install-arch.sh` that fail or are absent on host**:
   - `grim`, `slurp` — Line 623. Niri has built-in screenshot shortcuts (`screenshot`, `screenshot-screen`, `screenshot-window` in `config.kdl:395-398`). Neither package is installed on the host.
   - `fastfetch`, `nwg-look`, `acpi` — Line 604 & 623. None are installed on the host.

4. **AUR vs CachyOS Binary Distribution (R1 / R2)**:
   - `zen-browser-bin`: Placed in `aur_groups` (line 641), but is an official prebuilt binary in `cachyos` repo (`pacman -S zen-browser-bin`).
   - `ayugram-desktop`: Placed in `aur_groups` as `ayugram-desktop-bin` (line 641), but `ayugram-desktop` is an official prebuilt binary package in `cachyos` repo (`pacman -S ayugram-desktop`).
   - `yay`: Compiled from git in chroot (lines 476-481), but `yay` and `yay-bin` are prebuilt in `cachyos` repo (`pacman -S yay`).
   - `vibepanel-git`: Compiles Rust code with `cargo` (`Make Deps: git cargo rust pkg-config`), taking substantial time. `vibepanel-bin` in AUR downloads the prebuilt binary directly.

5. **Chroot Network Resolution Failure (R2)**:
   - `install-arch.sh` does NOT configure `/etc/resolv.conf` before or inside chroot.
   - On modern Arch ISOs with `systemd-resolved`, `/etc/resolv.conf` is `127.0.0.53`. Inside chroot, `127.0.0.53` is unreachable. Network calls (`curl`, `git clone`, `yay`, `pacman`) fail with `Could not resolve host: ...`.

6. **Chroot Sudoers Failure for Non-Root User (R2)**:
   - Lines 353-358 create `chezok` with password and set `chezok ALL=(ALL:ALL) ALL`.
   - Lines 476 and 662 run `su - "${USERNAME}" -c "..."` to invoke `makepkg` and `yay`.
   - `makepkg` and `yay` invoke `sudo pacman` to install dependencies.
   - Because `sudo` requires a password and there is no TTY attached in automated/chroot scripts, `sudo` terminates with `sudo: a password is required` or `no tty present and no askpass program specified`.

7. **GRUB Removable Flag Omission (R3)**:
   - Line 403: `grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck`
   - Ommits `--removable`. On host, `/boot/efi/EFI/BOOT/BOOTX64.EFI` does NOT exist. On Ivy Bridge laptops (Pentium 2020M), UEFI BIOS fails to recognize the disk in NVRAM and fails to boot unless `/EFI/BOOT/BOOTX64.EFI` is present.

---

## 2. Logic Chain

```
[Observation 1.1: Host kernel is linux-cachyos-bore; pacman -Q linux returns empty]
   │
   ├─► [Inference 1]: Standard 'linux' and 'linux-headers' should NOT be pacstrapped or kept in final system.
   │
[Observation 1.1: Target hardware is Ivy Bridge / Pentium 2020M without AVX / x86-64-v3]
   │
   ├─► [Inference 2]: On non-v3 CPUs, /etc/pacman.conf must NOT enable [cachyos-v3], [cachyos-core-v3], [cachyos-extra-v3].
   │                  It must enable generic [cachyos], [core], [extra], and [multilib].
   │
[Observation 1.2 & 1.3: ayugram-desktop, zen-browser-bin, yay, and yay-bin exist in [cachyos] repo]
   │
   ├─► [Inference 3]: R1 and R2 can be satisfied without compiling yay or downloading heavy packages from AUR.
   │                  'pacman -S yay' installs the official prebuilt helper immediately.
   │                  'pacman -S ayugram-desktop zen-browser-bin' installs directly via pacman.
   │
[Observation 1.3 & 1.4: vibepanel-git requires cargo/rust to compile; vibepanel-bin exists in AUR with 0 build deps]
   │
   ├─► [Inference 4]: For fast, reliable VM test and target installs without Rust toolchain,
   │                  vibepanel-bin or prebuilt package is the optimal match for R1's "no heavy compilation" rule.
   │
[Observation 1.5: arch-chroot inherits /etc/resolv.conf containing 127.0.0.53 stub resolver]
   │
   ├─► [Inference 5]: Writing public nameservers (1.1.1.1, 8.8.8.8) to /mnt/etc/resolv.conf before entering chroot
   │                  is strictly necessary to prevent "Could not resolve host" failures (R2).
   │
[Observation 1.5: sudo in chroot lacks tty, and user chezok has password-protected sudo]
   │
   ├─► [Inference 6]: A temporary passwordless sudoers entry (/etc/sudoers.d/99-installer-nopasswd)
   │                  must be created for makepkg/yay to execute 'sudo pacman' non-interactively (R2).
   │
[Observation 1.5: grub-install lacks --removable and host only has /boot/efi/EFI/arch/grubx64.efi]
   │
   └─► [Inference 7]: Adding '--removable' to grub-install guarantees creation of /boot/efi/EFI/BOOT/BOOTX64.EFI,
                      fulfilling R3 and acceptance criterion for Ivy Bridge UEFI visibility.
```

---

## 3. Caveats
1. **Host CPU vs Target Architecture**: The host machine is an AMD Ryzen 5 3500U running `x86_64-v3` packages. The target laptop (Ivy Bridge / Pentium 2020M) only supports standard `x86_64` (v1/v2). The script's dynamic architecture detection (`/lib/ld-linux-x86-64.so.2 --help | grep -q "x86-64-v3"`) works well, but installer logic must ensure `cachyos-*-v3` repos are completely stripped when running on non-v3 hardware or standard QEMU VM CPUs.
2. **`ayugram-desktop` naming**: In CachyOS repo, the package is named `ayugram-desktop`. In AUR, it is named `ayugram-desktop-bin`. Both provide the identical desktop application; installing `ayugram-desktop` via `pacman` is faster and does not require AUR.
3. **`python-pywal` repo status**: Arch Linux dropped `python-pywal` from official repos; it is now only installable via AUR (`aur/python-pywal` or `aur/python-pywal16`).
4. **Testing in QEMU**: In QEMU, the virtual graphics card is not Intel (`VirtIO` or `Standard VGA`). The installer's GPU autodetection properly falls back to `mesa vulkan-icd-loader`, but for the real Ivy Bridge target, `mesa libva-intel-driver vulkan-intel vulkan-icd-loader xf86-video-intel` are installed when Intel GPU is detected.

---

## 4. Conclusion & Concrete Recommendations

### 4.1 Exact Package Arrays for `install-arch.sh`

#### Stage 1: Pacstrap (Base System)
```bash
pacstrap -K /mnt \
    base base-devel \
    linux-firmware \
    grub efibootmgr xfsprogs \
    networkmanager sudo git curl nano vim
```
*(Notice standard `linux` and `linux-headers` removed; CachyOS BORE kernel installed immediately in chroot).*

#### Stage 2: CachyOS Kernel & Core Stack (Chroot)
```bash
pacman -S --noconfirm --needed \
    linux-cachyos-bore linux-cachyos-bore-headers \
    cachyos-settings scx-scheds \
    linux-firmware yay
```

#### Stage 3: Intel Ivy Bridge GPU Stack
```bash
pacman -S --noconfirm --needed \
    mesa libva-intel-driver vulkan-intel vulkan-icd-loader \
    xf86-video-intel
```

#### Stage 4: Official & CachyOS Desktop Packages (Grouped)
```bash
# Network, Bluetooth, Audio & Services
pacman -S --noconfirm --needed \
    bluez bluez-utils openssh power-profiles-daemon \
    pipewire pipewire-pulse wireplumber pavucontrol

# Wayland Compositors & Display Manager (R1)
pacman -S --noconfirm --needed \
    wayland niri hyprland sddm weston xwayland-satellite wl-clipboard cliphist

# Desktop Shell, Bars & Notifications (R1)
pacman -S --noconfirm --needed \
    quickshell waybar swaync awww rofi matugen

# Qt6 & KDE Frameworks dependencies for Quickshell / Vibepanel
pacman -S --noconfirm --needed \
    qt6-5compat qt6-multimedia qt6-positioning qt6-sensors qt6-virtualkeyboard qt6-declarative \
    kconfig kcoreaddons kdeclarative kiconthemes kirigami

# User Applications, Storage & Terminals (R1)
pacman -S --noconfirm --needed \
    zen-browser-bin ayugram-desktop \
    foot kitty nemo udisks2 udiskie ntfs-3g dosfstools exfatprogs

# Fonts & CLI Tools
pacman -S --noconfirm --needed \
    ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols-mono noto-fonts-emoji \
    btop htop nvtop cmatrix cava tty-clock jq aria2 libnotify brightnessctl nodejs npm
```

#### Stage 5: AUR Packages (Installed via `yay` as user `chezok`)
```bash
su - "${USERNAME}" -c "yay -S --noconfirm --needed \
    vibepanel-bin \
    python-pywal \
    sptlrx-bin \
    waylyrics \
    unimatrix-git \
    lavat \
    pipes.sh"
```
*(Note: Using `vibepanel-bin` eliminates Rust compilation; `ayugram-desktop`, `zen-browser-bin`, and `tty-clock` are already installed via `pacman`).*

---

### 4.2 Fix for R2 (Network Resolution & Sudoers)

```bash
# 1. Guarantee valid DNS before chroot and inside chroot
cat > /mnt/etc/resolv.conf << 'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 9.9.9.9
EOF

# 2. Temporary passwordless sudo for chezok during installation
mkdir -p /mnt/etc/sudoers.d
echo "${USERNAME} ALL=(ALL:ALL) NOPASSWD: ALL" > "/mnt/etc/sudoers.d/99-installer-nopasswd"
chmod 440 "/mnt/etc/sudoers.d/99-installer-nopasswd"

# 3. Inside chroot: install yay directly from cachyos repo
pacman -S --noconfirm --needed yay

# 4. Cleanup temporary sudo rule at the end of chroot
rm -f /etc/sudoers.d/99-installer-nopasswd
```

---

### 4.3 Fix for R3 (UEFI Bootloader Removable Flag)

In `phase_chroot`:
```bash
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck --removable
```
*(Produces `/boot/efi/EFI/BOOT/BOOTX64.EFI`, guaranteeing detection on older UEFI implementations).*

---

## 5. Verification Method

To verify these findings independently:

1. **Verify repository availability for key binary packages**:
   ```bash
   pacman -Si cachyos/ayugram-desktop cachyos/zen-browser-bin cachyos/yay cachyos/linux-cachyos-bore
   ```
   *Expected*: All 4 packages return valid metadata with `Packager: CachyOS <admin@cachyos.org>`.

2. **Verify Intel Ivy Bridge driver packages in official repositories**:
   ```bash
   pacman -Si mesa libva-intel-driver vulkan-intel xf86-video-intel vulkan-icd-loader
   ```
   *Expected*: All packages found in `extra` or `cachyos`.

3. **Verify Wayland stack package availability**:
   ```bash
   pacman -Si niri hyprland sddm weston quickshell waybar swaync awww xwayland-satellite
   ```
   *Expected*: All packages found in official `extra` or `cachyos-extra-v3`.

4. **Verify AUR packages vs binary alternatives**:
   ```bash
   yay -Si vibepanel-bin python-pywal sptlrx-bin waylyrics unimatrix-git
   ```
   *Expected*: `vibepanel-bin` has `Make Deps: None`.

5. **Invalidation Conditions**:
   - If CachyOS removes `ayugram-desktop` or `zen-browser-bin` from `[cachyos]` repository, fallback to AUR packages (`ayugram-desktop-bin`, `zen-browser-bin`) is required.
   - If target hardware is configured with Secure Boot enabled without enrolled CachyOS keys, standard GRUB signed binaries would be required.
