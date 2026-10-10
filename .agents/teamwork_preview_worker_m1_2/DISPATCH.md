## 2026-10-09T20:42:07Z
You are a Worker subagent for Milestone 1 of the project "Arch Linux / CachyOS Installer Automation & QEMU Verification".

Your working directory is: `/home/chezok/dotfiles/.agents/teamwork_preview_worker_m1_2`
Project root: `/home/chezok/dotfiles`
Parent Orchestrator conversation ID: `c94b6af5-cc1d-4250-8e25-84cccbff40a6`

### MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

### Authoritative Requirements & Inputs:
Read these files before starting:
1. `/home/chezok/dotfiles/.agents/ORIGINAL_REQUEST.md` (CRITICAL: Read this first!)
2. `/home/chezok/dotfiles/.agents/PROJECT.md`
3. Explorer analysis and patches:
   - `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_1/m1_packages_and_configs.patch`
   - `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_2/r2_network_sudoers.patch`
   - `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_3/grub_and_automation.patch`
   - `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_3/proposed_install-arch.sh`
   - `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_3/handoff.md`

### Scope and Exclusive File Ownership:
You own and may edit:
- `/home/chezok/dotfiles/install-arch.sh`
- `/home/chezok/dotfiles/install.sh`
- User configs if needed (ensure compatibility with Intel GPU, Niri, Hyprland, etc.):
  * Note user constraints:
    - SDDM stays as-is (do NOT remove or replace SDDM).
    - udiskie tray is already disabled (`--no-tray`) and duplicate removed - preserve this.
    - Niri already has window rule with `xray false` for Vibepanel - preserve this.

### Tasks:
1. Update `install-arch.sh` with the verified improvements:
   - R1: Package synchronization:
     * Kernel: `linux-cachyos-bore`, `linux-cachyos-bore-headers`, `cachyos-settings`, `scx-scheds` (remove vanilla `linux` duplicate).
     * Graphics: Intel Ivy Bridge (`mesa`, `xf86-video-intel`, `vulkan-intel`, `intel-media-driver`, `intel-ucode`). Remove AMD-specific variables.
     * Wayland/Desktops: `niri`, `xwayland-satellite`, `hyprland`, `sddm`, `quickshell`, `vibepanel-git` (or binary/fallback), `swaync`, `awww`, `waybar`.
     * Network/Audio: `bluez`, `bluez-utils`, `networkmanager`, `pipewire`, `wireplumber`, `pavucontrol`.
     * Apps & Tools: `zen-browser-bin`, `ayugram-desktop-bin`, `foot`, `nemo`, `udisks2`, `udiskie`, `ntfs-3g`, `dosfstools`, `exfatprogs`.
   - R2: Chroot network and unprivileged build:
     * Populate `/mnt/etc/resolv.conf` with DNS `1.1.1.1` and `8.8.8.8` prior to chroot network operations.
     * Configure temporary passwordless sudoers (`/etc/sudoers.d/99-installer-nopasswd`) for unprivileged yay / makepkg building, and cleanly remove or secure it after.
   - R3: UEFI GRUB bootloader:
     * Run `grub-install` with `--target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck --removable`.
     * Ensure both `/boot/efi/EFI/BOOT/BOOTX64.EFI` and `/boot/efi/EFI/GRUB/grubx64.efi` exist.
   - R4: Headless automation:
     * Support non-interactive mode via `AUTORUN=1`, `TARGET_DISK`, `ROOT_PASS`, `USER_PASS`, `CONFIRM=YES`.
2. Synchronize `install.sh` so it is identical to `install-arch.sh` (`cmp install.sh install-arch.sh` succeeds).
3. Run verification:
   - `bash -n install-arch.sh`
   - `bash -n install.sh`
   - `./verify.sh`
   - Test headless variable parsing and logic validation.
4. Document all changes and verification in `/home/chezok/dotfiles/.agents/teamwork_preview_worker_m1_2/handoff.md`.
5. Send completion message back to Parent Orchestrator (`c94b6af5-cc1d-4250-8e25-84cccbff40a6`) via `send_message`.
