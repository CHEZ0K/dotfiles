# E2E Test Infra: Arch Linux / CachyOS Installer & QEMU Verification

## Test Philosophy
- Opaque-box, requirement-driven.
- Automated end-to-end VM execution in QEMU with KVM acceleration and UEFI OVMF firmware.
- Methodology: Category-Partition + Boundary Value Analysis + Pairwise Combinations + Real-World Workload Testing.

## Feature Inventory
| # | Feature | Source | Tier 1 | Tier 2 | Tier 3 |
|---|---------|--------|:------:|:------:|:------:|
| 1 | Kernel & CachyOS Settings (`linux-cachyos-bore`, `cachyos-settings`) | ORIGINAL_REQUEST R1 | 5 | 5 | ✓ |
| 2 | Intel Ivy Bridge Graphics (`mesa`, `xf86-video-intel`, `vulkan-intel`) | ORIGINAL_REQUEST R1 | 5 | 5 | ✓ |
| 3 | Wayland & Environment (`niri`, `hyprland`, `sddm`, `waybar`, `vibepanel`) | ORIGINAL_REQUEST R1 | 5 | 5 | ✓ |
| 4 | Network & Audio Stack (`NetworkManager`, `pipewire`, `wireplumber`, `bluez`) | ORIGINAL_REQUEST R1 | 5 | 5 | ✓ |
| 5 | Tools & AUR Binaries (`zen-browser-bin`, `ayugram-desktop-bin`, `foot`, `nemo`) | ORIGINAL_REQUEST R1 | 5 | 5 | ✓ |
| 6 | Chroot Resolv.conf DNS resolution (`1.1.1.1`, `8.8.8.8`) | ORIGINAL_REQUEST R2 | 5 | 5 | ✓ |
| 7 | Passwordless Sudoers for Unprivileged yay/makepkg | ORIGINAL_REQUEST R2 | 5 | 5 | ✓ |
| 8 | UEFI GRUB with `--removable` (`/boot/efi/EFI/BOOT/BOOTX64.EFI`) | ORIGINAL_REQUEST R3 | 5 | 5 | ✓ |
| 9 | Dual NVRAM & Fallback Boot Entries | ORIGINAL_REQUEST R3 | 5 | 5 | ✓ |
| 10 | Headless Unattended Automation (`AUTORUN=1`) | ORIGINAL_REQUEST R4 | 5 | 5 | ✓ |
| 11 | QEMU VM Provisioning & KVM Acceleration | ORIGINAL_REQUEST R4 | 5 | 5 | ✓ |
| 12 | End-to-End UEFI Boot & Acceptance Assertions | ORIGINAL_REQUEST R4 | 5 | 5 | ✓ |

## Test Architecture
- **Test Harness**: `tests/qemu_test_runner.sh`
- **Firmware**: OVMF x64 UEFI (`/usr/share/edk2/x64/OVMF_CODE.4m.fd` and `OVMF_VARS.4m.fd`).
- **Base Live Media**: `/home/chezok/backup_iso/archlinux-2026.09.01-x86_64.iso` (1.5G).
- **Target Disk**: 25G `qcow2` virtual disk image with GPT partition table (ESP FAT32 + XFS root).
- **Network**: SLIRP user-mode networking with DNS forwarding.
- **Pass/Fail Semantics**:
  - Installer Phase: Exit code 0, no unhandled bash errors, no `Could not resolve host`, no sudo password blocks.
  - Boot Phase: Exit code 0 from in-guest assertion script testing kernel, bootloader files, and systemd services.

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised | Complexity |
|---|----------|--------------------|------------|
| 1 | Automated Headless QEMU VM Installation | F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11 | High |
| 2 | Direct UEFI Boot from Target Virtual Disk | F1, F8, F9, F11, F12 | High |
| 3 | Systemd Core Services Startup & State Check | F1, F4, F12 | Medium |
| 4 | Unprivileged User Environment & Desktop Launch | F3, F5, F7, F12 | Medium |
| 5 | Intel Ivy Bridge VA-API / Mesa Driver Conformance | F2, F12 | Medium |

## Coverage Thresholds
- Tier 1: ≥5 per feature
- Tier 2: ≥5 per feature (where boundaries exist)
- Tier 3: Pairwise coverage of major feature interactions
- Tier 4: ≥5 realistic application scenarios
