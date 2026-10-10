# Project: Arch Linux / CachyOS Installer Automation & QEMU Verification

## Architecture
- **Target OS**: Arch Linux / CachyOS (x86_64, Pentium 2020M Ivy Bridge / Generic x86_64 compatible).
- **Core Components**:
  - `install-arch.sh` / `install.sh`: Modular shell installer supporting interactive mode and headless automated mode (`AUTORUN=1`).
  - `dotfiles`: Configuration directory for Niri, Hyprland, Waybar, Vibepanel, SDDM, SwayNC, Awww, Foot, Kitty.
  - `tests/qemu_test_runner.sh`: End-to-end automated QEMU UEFI test harness using OVMF and local Live ISO.
- **Data Flow**:
  1. Host/Live ISO boots -> launches installer (`AUTORUN=1 TARGET_DISK=/dev/vda`).
  2. Partitioning (GPT: 512M ESP FAT32, rest XFS root) -> formatting -> mounting.
  3. Network verification -> write static DNS (`1.1.1.1`, `8.8.8.8`) to `/mnt/etc/resolv.conf`.
  4. Pacstrap core & CachyOS Bore kernel -> Chroot setup with passwordless sudoers for unprivileged build.
  5. CachyOS repository bootstrap -> pacman package sync (Intel Ivy Bridge drivers, Niri, Hyprland, SDDM, Waybar, Vibepanel, Zen Browser, AyuGram).
  6. UEFI GRUB installation with `--removable` creating `/boot/efi/EFI/BOOT/BOOTX64.EFI`.
  7. Services enabled (`NetworkManager`, `bluetooth`, `sddm`, `udisks2`) -> poweroff / reboot.
  8. QEMU UEFI verification boots from installed disk -> executes acceptance test assertions.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Bore Kernel & CachyOS Settings | Exclusively install `linux-cachyos-bore`, `linux-cachyos-bore-headers`, `cachyos-settings`, `scx-scheds` (no duplicate `linux`) | M1 | ORIGINAL_REQUEST R1 |
| 2 | Intel Ivy Bridge Graphics | Install `mesa`, `xf86-video-intel`, `vulkan-intel`, `intel-media-driver`, `intel-ucode`; remove AMD hardcoding | M1 | ORIGINAL_REQUEST R1 |
| 3 | Wayland & Environment Packages | Install `niri`, `xwayland-satellite`, `hyprland`, `sddm`, `weston`, `quickshell`, `vibepanel-git`/`vibepanel-bin`, `swaync`, `awww`, `waybar` | M1 | ORIGINAL_REQUEST R1 |
| 4 | Network & Audio Stack | Install and enable `bluez`, `bluez-utils`, `networkmanager`, `pipewire`, `wireplumber`, `pavucontrol` | M1 | ORIGINAL_REQUEST R1 |
| 5 | Tools & AUR Binary Packages | Install `foot`, `kitty`, `nemo`, `udisks2`, `udiskie`, `ntfs-3g`, `dosfstools`, `exfatprogs`, `zen-browser-bin`, `ayugram-desktop-bin`/`ayugram-desktop` | M1 | ORIGINAL_REQUEST R1 |
| 6 | Chroot Resolv.conf Validation | Ensure `/mnt/etc/resolv.conf` contains valid nameservers (`1.1.1.1`, `8.8.8.8`) before network calls | M1 | ORIGINAL_REQUEST R2 |
| 7 | Unprivileged Sudoers for yay | Configure passwordless sudo for user `chezok`/`nobody` for non-interactive `makepkg` and `yay` builds | M1 | ORIGINAL_REQUEST R2 |
| 8 | UEFI GRUB with `--removable` | Execute `grub-install` with `--removable` creating `/boot/efi/EFI/BOOT/BOOTX64.EFI` for Ivy Bridge / UEFI fallback | M1 | ORIGINAL_REQUEST R3 |
| 9 | Dual NVRAM & Fallback EFI | Ensure both `/boot/efi/EFI/BOOT/BOOTX64.EFI` and `/boot/efi/EFI/GRUB/grubx64.efi` exist | M1 | ORIGINAL_REQUEST R3 |
| 10 | Headless Installer Automation | Add non-interactive execution support via `AUTORUN=1`, `TARGET_DISK`, `ROOT_PASS`, `USER_PASS` | M1 | ORIGINAL_REQUEST R4 |
| 11 | QEMU VM Provisioning & KVM Setup | Build automated 2-stage VM test stand with QEMU, KVM, OVMF firmware, and local Arch ISO | M2 | ORIGINAL_REQUEST R4 |
| 12 | End-to-End UEFI Boot & Acceptance Assertions | Verify direct UEFI boot, BOOTX64.EFI presence, CachyOS bore kernel, and active services in QEMU VM | M2 | ORIGINAL_REQUEST R4 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | M1: Installer Implementation (R1, R2, R3 & Headless Automation) | Sync user packages, Ivy Bridge drivers, CachyOS bore kernel, fix dotfiles, static DNS in resolv.conf, passwordless sudoers, `grub-install --removable`, headless `AUTORUN=1` | none | DONE |
| 2 | M2: QEMU VM Test Stand & E2E Verification (R4) | Automated QEMU OVMF test harness, Stage 1 unattended install, Stage 2 UEFI boot & acceptance verification | M1 | IN_PROGRESS |

## Interface Contracts
### Live ISO / Host ↔ Installer Script (`install-arch.sh`)
- Input Environment Variables:
  - `AUTORUN=1`: Enables non-interactive unattended installation.
  - `TARGET_DISK`: Target disk path (e.g. `/dev/vda`).
  - `ROOT_PASS`: Root user password.
  - `USER_PASS`: Regular user password.
  - `CONFIRM=YES`: Skips destructive prompt.
- Exit code: 0 on success, non-zero on failure.

### Chroot Environment Contract
- Filesystem: `/mnt` mounted with root (XFS) and `/mnt/boot/efi` (FAT32).
- Network: `/mnt/etc/resolv.conf` populated with `nameserver 1.1.1.1\nnameserver 8.8.8.8`.
- Sudoers: `/mnt/etc/sudoers.d/99-installer-nopasswd` granting passwordless sudo for user `chezok`.
- Bootloader: `/boot/efi/EFI/BOOT/BOOTX64.EFI` installed and bootable.

## Code Layout
- `install-arch.sh` / `install.sh`: Core installer scripts in repository root.
- `.config/`: User dotfiles (Niri, Hyprland, Waybar, Vibepanel, SwayNC, SDDM, Foot, Kitty).
- `tests/qemu_test_runner.sh`: Automated QEMU VM harness script.
- `tests/vm_acceptance_check.sh`: In-guest acceptance criteria verification script.
