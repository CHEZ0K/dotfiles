# Handoff Report — Survey of Installation Scripts and Dotfiles

## 1. Observation

### 1.1 Repository Structure and Files Inspected
The workspace `/home/chezok/dotfiles` contains the following key components:
- `/home/chezok/dotfiles/install.sh` and `/home/chezok/dotfiles/install-arch.sh`: 1,479 lines each, byte-for-byte identical (`diff -u` produced 0 lines). Contains 4 main phases: `phase_install` (Arch ISO), `phase_chroot` (chroot configuration), `phase_deploy` (post-reboot dotfile deploy), and `phase_github` (maintenance).
- `/home/chezok/dotfiles/verify.sh`: 106 lines. Verifies syntax (`bash -n`), verifies presence of 32 key files/directories, checks polkit rules and sddm patterns in `install.sh`, and reports git status. Currently passes all checks except reporting untracked `.agents/` and `ORIGINAL_REQUEST.md`.
- `/home/chezok/dotfiles/packages/pacman.txt`: 91 explicitly installed packages (`pacman -Qe`).
- `/home/chezok/dotfiles/packages/aur.txt`: 9 foreign packages (`pacman -Qm`): `antigravity-cli`, `lavat`, `linux-wallpaperengine-git`, `pipes.sh`, `python-pywal`, `sptlrx-bin`, `unimatrix-git`, `vibepanel-git`, `waylyrics`.
- `/home/chezok/dotfiles/dotfiles/`: 33 config directories including `niri`, `hypr`, `vibepanel`, `waybar`, `foot`, `kitty`, `cava`, `matugen`, `swaync`, `rofi`, `gtk-3.0`, `gtk-4.0`, `environment.d`, `scripts`, `systemd`, `zen-css`.
- `/home/chezok/dotfiles/themes/`: SDDM themes (`silent`, `konata-cat`), GRUB theme (`asuka`), cursors (`Furina`, `default`), icons (`Tela-circle-wal`), GTK themes (`Mint-Y-Dark`, `Mint-Y-Dark-Red`).

---

### 1.2 Current Installation Workflow Mapping

#### Phase 1: Arch ISO Installation (`phase_install()`, lines 54–225)
1. **Interactive Disk Selection & Prompts**:
   - Lines 76–111: Prompts interactively with `read -rp` for `TARGET_DISK_RAW`, requires typing `YES` in `CONFIRM`, and prompts twice for `ROOT_PASS` and `USER_PASS`.
   - Line 87–93: Resolves partitions as `${TARGET_DISK}p1` / `${TARGET_DISK}p2` (NVMe) or `${TARGET_DISK}1` / `${TARGET_DISK}2` (SATA/VirtIO).
2. **Partitioning**:
   - Lines 120–127: Clears signatures using `wipefs -af "$TARGET_DISK"` and `sgdisk --zap-all "$TARGET_DISK"`. Creates partition 1: +1G, type `ef00` (EFI); partition 2: remainder, type `8300` (ROOT). Calls `partprobe`.
3. **Formatting & Mounting**:
   - Lines 134–147: Runs `mkfs.fat -F32 -n EFI "$EFI_PART"` and `mkfs.xfs -f -L ROOT "$ROOT_PART"`. Mounts root to `/mnt`, creates `/mnt/boot/efi`, and mounts EFI partition to `/mnt/boot/efi`.
4. **Mirrors & Pacstrap**:
   - Lines 153–179: Configures pacman mirrorlist using `reflector` or 4 static mirrors. Executes:
     ```bash
     pacstrap -K /mnt \
         base base-devel \
         linux linux-headers linux-firmware \
         grub efibootmgr xfsprogs \
         networkmanager sudo git curl nano vim
     ```
5. **Fstab & Chroot Handoff**:
   - Lines 185–213: Runs `genfstab -U /mnt >> /mnt/etc/fstab`. Copies installer to `/mnt/install-arch.sh`, writes `/mnt/install-vars.env`, and invokes:
     ```bash
     arch-chroot /mnt /bin/bash /install-arch.sh --chroot
     ```
   - Notice: No check or population of `/mnt/etc/resolv.conf` occurs prior to `arch-chroot`.

#### Phase 2: Chroot System Configuration (`phase_chroot()`, lines 230–530)
1. **CachyOS Repositories Bootstrap**:
   - Lines 243–249: Detects CPU `x86-64-v3` support via `/lib/ld-linux-x86-64.so.2 --help`.
   - Lines 254–272: Uses `curl` to fetch `cachyos-keyring` and `cachyos-mirrorlist` packages from `https://mirror.cachyos.org/repo/x86_64/cachyos`. Extracts them directly using `tar -xf` to `/usr/share/pacman/keyrings/` and `/etc/pacman.d/`. Runs `pacman-key --init` and `pacman-key --populate archlinux cachyos`.
   - Lines 274–304: Prepends `[cachyos-v3]`, `[cachyos-core-v3]`, `[cachyos-extra-v3]`, and `[cachyos]` (stripping v3 if unsupported) to `/etc/pacman.conf`. Runs `pacman -Sy --noconfirm`.
2. **System Base Configuration**:
   - Lines 313–341: Sets timezone `/usr/share/zoneinfo/Europe/Moscow`, configures locales `en_US.UTF-8` and `ru_RU.UTF-8` in `/etc/locale.gen`, generates locales, sets `LANG` and `KEYMAP=us`, configures `/etc/hostname` and `/etc/hosts`.
3. **User Creation and Sudo Setup**:
   - Lines 347–359: Sets root password, creates user `chezok` in groups `wheel,audio,video,storage,optical,network,power`. Writes sudoers:
     ```bash
     mkdir -p /etc/sudoers.d
     echo "${USERNAME} ALL=(ALL:ALL) ALL" > "/etc/sudoers.d/${USERNAME}"
     chmod 440 "/etc/sudoers.d/${USERNAME}"
     sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
     grep -q "^${USERNAME} " /etc/sudoers 2>/dev/null || echo "${USERNAME} ALL=(ALL:ALL) ALL" >> /etc/sudoers
     ```
     Notice: `${USERNAME} ALL=(ALL:ALL) ALL` requires password authentication!
4. **Initramfs & CachyOS Kernel**:
   - Lines 366–384: Updates `/etc/mkinitcpio.conf` HOOKS for XFS, runs `mkinitcpio -P`. Installs CachyOS packages:
     ```bash
     pacman -S --noconfirm --needed \
         linux-cachyos-bore linux-cachyos-bore-headers \
         cachyos-settings scx-scheds \
         linux-firmware
     ```
5. **GPU Driver Detection (`detect_and_install_gpu()`, lines 536–590)**:
   - Evaluates `lspci` for Intel, AMD, NVIDIA:
     - Intel: `mesa libva-intel-driver vulkan-intel vulkan-icd-loader xf86-video-intel`
     - AMD: `mesa vulkan-radeon libva-mesa-driver mesa-vdpau vulkan-icd-loader xf86-video-amdgpu`
     - NVIDIA: `mesa vulkan-icd-loader` (nouveau) or `nvidia nvidia-utils vulkan-icd-loader`
     - Generic fallback: `mesa vulkan-icd-loader`
6. **Package Installation (`install_pacman_packages()`, lines 592–631)**:
   - Installs hardcoded package batches via `pacman -S --noconfirm --needed`.
   - Packages included: `bluez`, `bluez-utils`, `openssh`, `wayland`, `niri`, `sddm`, `xwayland-satellite`, `wl-clipboard`, `cliphist`, `pipewire`, `pipewire-pulse`, `wireplumber`, `pavucontrol`, `btop`, `htop`, `fastfetch`, `neofetch`, `aria2`, `playerctl`, `brightnessctl`, `power-profiles-daemon`, `libnotify`, `matugen`, `foot`, fonts, `nemo`, `udisks2`, `udiskie`, `ntfs-3g`, `dosfstools`, `exfatprogs`, `awww`, `swaync`, `firefox`, `mpv`, `cava`, `quickshell`, `kconfig`, `rofi`, etc.
   - Omitted from function: `hyprland`, `waybar`, `weston`, `kitty`, `jq`.
7. **GRUB Bootloader Installation (lines 403–418)**:
   - Exact command at line 403:
     ```bash
     grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck
     ```
     Notice: `--removable` flag is NOT present.
   - Writes `/etc/default/grub` and runs `grub-mkconfig -o /boot/grub/grub.cfg`.
8. **System Services & Polkit Rules (lines 423–452)**:
   - Enables `NetworkManager`, `bluetooth`, `sddm`, `sshd`, `power-profiles-daemon`, `udisks2`, `scx`.
   - Generates `/etc/polkit-1/rules.d/50-networkmanager.rules` and `/etc/polkit-1/rules.d/50-udisks2.rules`.
9. **SDDM Wayland Configuration (lines 457–471)**:
   - Writes `/etc/sddm.conf.d/default.conf` specifying `Current=silent`, `CursorTheme=Furina`, `DisplayServer=wayland`, `CompositorCommand=weston --shell=kiosk`.
10. **Yay & AUR Package Installation (lines 476–486, 633–665)**:
    - Runs:
      ```bash
      su - "${USERNAME}" -c "
          cd /tmp
          git clone https://aur.archlinux.org/yay.git
          cd yay
          makepkg -si --noconfirm
      " || warn "yay не установлен — проверьте подключение к сети"
      ```
    - Runs `install_aur_packages()`: installs `zen-browser-bin`, `ayugram-desktop-bin`, `vibepanel-git`, `python-pywal`, `linux-wallpaperengine-git`, `sptlrx-bin`, `waylyrics`, `unimatrix-git`, `lavat`, `tty-clock`, `pipes.sh`.
11. **In-Chroot Dotfiles Deployment (lines 489–520)**:
    - Clones `https://github.com/CHEZ0K/dotfiles.git` to `/home/${USERNAME}/dotfiles`.
    - Deploys configs via `deploy_dotfiles`, executes `configure_display_resolution`, `deploy_sddm_theme`, `deploy_grub_theme`, `deploy_zen_css`, `deploy_xwayland_satellite`.
    - Generates pywal palette and links systemd user sockets (`pipewire.socket`, `pipewire-pulse.socket`, `foot-server.socket`, `udiskie.service`).
    - Fixes ownership: `chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}`.
    - Removes `/install-vars.env` and `/install-arch.sh`.

#### Phase 3: Post-Boot Deployment (`phase_deploy()`, lines 670–733)
- Intended for execution after first boot as `chezok` (`bash ~/install-arch.sh --deploy`).
- Pulls repo from github, enables user sockets, repeats dotfiles, sddm, zen-css, and pywal deployment. Redundant if Phase 2 in-chroot deployment succeeded.

---

### 1.3 Verbatim Evidence of Critical Gaps

1. **Gap in R1 (Package Synchronization)**:
   - In `packages/pacman.txt`, lines 26 & 77:
     ```
     26: hyprland 0.56.2-3.1
     77: waybar 0.15.0-3.1
     ```
   - In `install.sh`, lines 598 & 613:
     ```bash
     598: "wayland niri sddm xwayland-satellite wl-clipboard cliphist"
     613: "awww swaync"
     ```
     Neither `hyprland` nor `waybar` is included in `install_pacman_packages()`.
   - In `install.sh`, line 469:
     ```bash
     469: CompositorCommand=weston --shell=kiosk
     ```
     `weston` is required by SDDM Wayland greeter, present in `packages/pacman.txt` (line 80), but missing from `install_pacman_packages()`.
   - In `cachyos` pacman repo query:
     ```
     Repository : cachyos
     Name       : ayugram-desktop
     Version    : 7.0.9-5

     Repository : cachyos
     Name       : zen-browser-bin
     Version    : 1.22.1b-1

     Repository : cachyos
     Name       : yay
     Version    : 13.0.1-1
     ```
     `ayugram-desktop`, `zen-browser-bin`, and `yay` exist as precompiled binaries directly in the `cachyos` pacman repository, but `install.sh` places them in `aur_groups` via `yay` (lines 641, 476–480).
   - In `dotfiles/niri/config.kdl` lines 46–49 and `dotfiles/environment.d/10-performance.conf` lines 6–7:
     `LIBVA_DRIVER_NAME="radeonsi"` and `VDPAU_DRIVER="radeonsi"` are hardcoded, conflicting with Intel Ivy Bridge VA-API.
   - Dual kernel installation: `pacstrap` installs `linux linux-headers`, and `phase_chroot` installs `linux-cachyos-bore linux-cachyos-bore-headers`.

2. **Gap in R2 (Chroot DNS & Sudoers for Yay)**:
   - In `install.sh` line 213: `arch-chroot /mnt /bin/bash /install-arch.sh --chroot` is called with no prior verification or setup of `/mnt/etc/resolv.conf`.
   - In `phase_chroot()` line 255: `curl -fsSL "${cachy_url}/cachyos-keyring-20240331-1-any.pkg.tar.zst"` executes immediately. If host `/etc/resolv.conf` is a systemd-resolved stub (`127.0.0.53`) or empty, resolution fails with `curl: (6) Could not resolve host: mirror.cachyos.org`.
   - In `install.sh` line 355:
     ```bash
     echo "${USERNAME} ALL=(ALL:ALL) ALL" > "/etc/sudoers.d/${USERNAME}"
     ```
     In line 480: `makepkg -si --noconfirm` is run as user `chezok` via `su - "${USERNAME}" -c ...`.
     `makepkg -si` invokes `sudo pacman -U`. Because `NOPASSWD` is not specified, `sudo` requests a password from non-interactive stdin, causing `makepkg` to abort. Consequently, `yay` is never installed, and all subsequent AUR installations are skipped.

3. **Gap in R3 (UEFI GRUB Removable Flag)**:
   - In `install.sh` line 403:
     ```bash
     grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck
     ```
     Flag `--removable` is missing. As a result, `/boot/efi/EFI/BOOT/BOOTX64.EFI` is not created, causing UEFI boot failure on Ivy Bridge laptops and certain virtual machines where NVRAM boot variables are not persisted.
   - `intel-ucode` is omitted from pacstrap and pacman package installation.

4. **Gap in R4 (VM Testing & Automation)**:
   - Lines 76, 100, 105, 106, 109, 110 of `install.sh` enforce interactive prompts (`read -rp`, `read -rsp`) with no support for unattended flags or pre-set environment variables (`TARGET_DISK`, `ROOT_PASS`, `USER_PASS`, `CONFIRM=YES`).
   - Host check: `qemu-system-x86_64` is not currently installed on the host (though available via `extra/qemu-system-x86` and `extra/edk2-ovmf`; `/dev/kvm` has `crw-rw-rw-` permissions).
   - In-chroot dotfile deployment (line 492) executes `su - "${USERNAME}" -c "git clone '${DOTFILES_REPO}' '${DOTFILES_DIR}'"`. In a local VM test environment, this requires remote GitHub access and bypasses local modifications.
   - In `dotfiles/niri/config.kdl` line 170:
     ```
     spawn-at-startup "/home/chezok/.local/bin/vibepanel"
     ```
     `vibepanel-git` installs to `/usr/bin/vibepanel`, and no file exists in `dotfiles/scripts/vibepanel`. On a fresh installation, this binary path will not exist unless symlinked or referenced as `vibepanel`.

---

## 2. Logic Chain

1. **Package Discrepancies (R1)**:
   - *Observation*: Requirement R1 explicitly demands `hyprland`, `waybar`, `quickshell`, `vibepanel-git`, `swaync`, `awww`, `niri`, `sddm`. `packages/pacman.txt` includes `hyprland 0.56.2-3.1` and `waybar 0.15.0-3.1`.
   - *Logic*: Lines 592–624 of `install.sh` define a hardcoded list of package groups that excludes `hyprland` and `waybar`. Thus, running the current `install.sh` produces a system missing Hyprland and Waybar, violating R1.
   - *Observation*: `cachyos` repo provides `ayugram-desktop`, `zen-browser-bin`, and `yay` as precompiled binaries.
   - *Logic*: Placing `zen-browser-bin` and `ayugram-desktop-bin` in AUR groups (lines 641, 662) subjects them to AUR build dependencies, network throttling, or failure if yay is absent. They should be installed directly via `pacman -S` once the CachyOS repository is enabled.
   - *Observation*: `weston` is in `packages/pacman.txt` (line 80) and specified as `CompositorCommand=weston --shell=kiosk` in `/etc/sddm.conf.d/default.conf` (line 469).
   - *Logic*: Because `weston` is not included in `install_pacman_packages()`, SDDM greeter fails to start in Wayland mode.
   - *Observation*: `dotfiles/niri/config.kdl` and `dotfiles/environment.d/10-performance.conf` declare `LIBVA_DRIVER_NAME=radeonsi`.
   - *Logic*: The user's target system is an Intel Ivy Bridge (Pentium 2020M) laptop. Forcing AMD `radeonsi` driver names prevents Intel VA-API (`i965_drv_video.so`) from loading.

2. **Chroot Network Resolution and Sudoers (R2)**:
   - *Observation*: In Arch live environments, `/etc/resolv.conf` can point to systemd-resolved stubs or become empty upon pacstrap. `phase_install()` does not configure `/mnt/etc/resolv.conf`.
   - *Logic*: Inside `phase_chroot()`, the first network command `curl -fsSL "${cachy_url}/cachyos-keyring-20240331-1-any.pkg.tar.zst"` fails if DNS cannot resolve `mirror.cachyos.org`. Ensuring `/mnt/etc/resolv.conf` contains `nameserver 1.1.1.1` and `nameserver 8.8.8.8` before chroot entry guarantees DNS resolution.
   - *Observation*: User `chezok` is given `ALL=(ALL:ALL) ALL` in `/etc/sudoers.d/chezok` (line 355). `makepkg -si --noconfirm` is run via `su - chezok -c` (line 476).
   - *Logic*: `makepkg -si` invokes `sudo pacman -U`. Sudo prompts for a password on stdin. In a script execution context without an interactive terminal, sudo fails. Consequently, yay compilation fails, line 481 outputs a warning, and line 635 skips all AUR packages. Granting `chezok ALL=(ALL:ALL) NOPASSWD: ALL` in `/etc/sudoers.d/chezok` solves this issue.

3. **GRUB Bootloader for UEFI (R3)**:
   - *Observation*: Line 403 runs `grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck` without `--removable`.
   - *Logic*: Without `--removable`, GRUB writes only to `/boot/efi/EFI/GRUB/grubx64.efi` and attempts to set NVRAM via efibootmgr. On Intel Ivy Bridge laptops (Pentium 2020M era BIOS) and virtual test images, UEFI firmware often ignores NVRAM and defaults to `/EFI/BOOT/BOOTX64.EFI`. Adding `--removable` forces `grub-install` to write to `/boot/efi/EFI/BOOT/BOOTX64.EFI`, satisfying R3 and Acceptance Criteria.

4. **Testing and Automation in QEMU (R4)**:
   - *Observation*: Lines 76–111 in `install.sh` use un-guarded `read` commands.
   - *Logic*: Running `install.sh` inside an automated VM test harness halts waiting for terminal input. Supporting non-interactive parameters or environment variable overrides enables headless end-to-end VM testing.
   - *Observation*: `qemu-system-x86_64` is absent from host PATH, while `/dev/kvm` is accessible.
   - *Logic*: To satisfy R4, `qemu-system-x86` and `edk2-ovmf` must be installed on the host before launching the VM test stand.

---

## 3. Caveats

1. **Host Hardware vs Target Machine**:
   - The current development environment runs on an AMD Ryzen 5 3500U laptop with Radeon Vega Mobile graphics (`radeonsi`).
   - The target configuration specified in R1 and R3 is an Intel Ivy Bridge system (Pentium 2020M with Intel HD Graphics).
   - Hardware-specific configurations (such as GPU driver auto-detection and environment variables) must support both dynamic auto-detection and graceful fallback for Intel Ivy Bridge and QEMU virtual devices (`virtio-gpu` / `bochs-drm`).
2. **AUR Package Compilation Times**:
   - Compiling `linux-wallpaperengine-git` in a QEMU virtual machine or on low-end hardware is resource-intensive and prone to timeout. Consideration should be given to handling heavy AUR packages cleanly during testing.
3. **Repository Sync vs Local Dotfiles**:
   - In `phase_chroot()`, the installer currently clones from `https://github.com/CHEZ0K/dotfiles.git`. During local test runs or VM verification, any unpushed local changes will not be reflected unless local dotfiles are synced into the target filesystem.

---

## 4. Conclusion

The existing `install.sh` / `install-arch.sh` provides a solid architectural foundation (GPT partitioning, XFS root, CachyOS repository bootstrapping, systemd service enablement, and comprehensive dotfiles deployment). However, it currently fails all four core requirements in `ORIGINAL_REQUEST.md`:

1. **R1 Failure**: Missing packages (`hyprland`, `waybar`, `weston`, `kitty`, `jq`); redundant dual kernel installation (`linux` + `linux-cachyos-bore`); suboptimal placement of precompiled CachyOS binary packages (`ayugram-desktop`, `zen-browser-bin`, `yay`) into AUR build steps; and hardcoded AMD environment variables that break Intel Ivy Bridge VA-API.
2. **R2 Failure**: Absence of DNS validation/population in `/mnt/etc/resolv.conf`, leading to `Could not resolve host` errors; and missing `NOPASSWD` in `/etc/sudoers.d/chezok`, which blocks non-interactive `makepkg -si` and prevents `yay` and all AUR packages from installing.
3. **R3 Failure**: Missing `--removable` flag on `grub-install`, failing to generate `/boot/efi/EFI/BOOT/BOOTX64.EFI`; and missing `intel-ucode`.
4. **R4 Failure**: 6 interactive `read` prompts blocking automated unattended execution; missing QEMU/OVMF packages on host; remote git clone dependency during chroot deployment; and hardcoded `/home/chezok/.local/bin/vibepanel` path in `config.kdl`.

Addressing these specific gaps will allow the installer to run reliably, unattended, and pass UEFI verification in QEMU.

---

## 5. Verification Method

To independently verify the observations and conclusions in this report:

1. **Verify Shell Syntax and File Presences**:
   ```bash
   cd /home/chezok/dotfiles
   bash -n install.sh
   ./verify.sh
   ```
2. **Verify Missing Packages in `install.sh`**:
   ```bash
   # Check that hyprland, waybar, weston are not in install_pacman_packages:
   grep -E "hyprland|waybar|weston" install.sh
   # Confirm they exist in packages/pacman.txt:
   grep -E "hyprland|waybar|weston" packages/pacman.txt
   ```
3. **Verify CachyOS Binary Availability**:
   ```bash
   pacman -Si ayugram-desktop zen-browser-bin yay
   ```
4. **Verify Sudoers and GRUB Flags in `install.sh`**:
   ```bash
   # Confirm missing NOPASSWD:
   grep -n "sudoers.d" install.sh -A 3
   # Confirm missing --removable flag:
   grep -n "grub-install" install.sh
   ```
5. **Verify Hardcoded AMD Variables**:
   ```bash
   grep -n "radeonsi" dotfiles/niri/config.kdl dotfiles/environment.d/10-performance.conf
   ```
6. **Verify QEMU and KVM Status on Host**:
   ```bash
   which qemu-system-x86_64 || echo "QEMU not installed"
   ls -la /dev/kvm
   ```

*Invalidation Conditions*:
- If `grub-install` already contained `--removable`, R3 gap would be invalidated.
- If `install_pacman_packages()` already installed `hyprland` and `waybar`, R1 package gap would be invalidated.
- If `/etc/sudoers.d/chezok` already contained `NOPASSWD`, R2 sudo gap would be invalidated.
All observations were verified directly against source files in `/home/chezok/dotfiles`.
