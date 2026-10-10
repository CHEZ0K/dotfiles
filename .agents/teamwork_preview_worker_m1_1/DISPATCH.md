# DISPATCH: Milestone 1 Worker (Installer Core Implementation)

## 2026-10-01T00:18:44Z

- Working Directory: /home/chezok/dotfiles/.agents/teamwork_preview_worker_m1_1
- ORIGINAL_REQUEST path: /home/chezok/dotfiles/.agents/ORIGINAL_REQUEST.md
- PROJECT.md path: /home/chezok/dotfiles/.agents/PROJECT.md
- Scope: Implementation of Milestone 1 (R1, R2, R3 & Headless Automation) in `install-arch.sh`, `install.sh`, and dotfiles.

- Input Materials to read:
  1. `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_1/handoff.md` and `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_1/m1_packages_and_configs.patch`
  2. `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_2/handoff.md` and `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_2/r2_network_sudoers.patch`
  3. `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_3/handoff.md` and `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_3/grub_and_automation.patch` (and reference script `proposed_install-arch.sh`)

- File Ownership (Exclusive):
  - `/home/chezok/dotfiles/install-arch.sh`
  - `/home/chezok/dotfiles/install.sh`
  - `/home/chezok/dotfiles/dotfiles/niri/config.kdl`
  - `/home/chezok/dotfiles/dotfiles/environment.d/10-performance.conf`

- Tasks:
  1. Carefully integrate all modifications from M1 Explorers 1, 2, and 3:
     - [R1] Packages: Synchronize with host system. Pacstrap with `linux-cachyos-bore`, `linux-cachyos-bore-headers`, `cachyos-settings`, `scx-scheds`, `intel-ucode`. Intel Ivy Bridge drivers (`mesa`, `xf86-video-intel`, `vulkan-intel`, `intel-media-driver`, `libva-intel-driver`). Wayland/SDDM packages (`niri`, `xwayland-satellite`, `hyprland`, `sddm`, `weston`, `waybar`, `quickshell`, `vibepanel-bin`/`vibepanel-git`, `swaync`, `awww`). AUR / CachyOS prebuilts (`zen-browser-bin`, `ayugram-desktop`, `yay`). Remove AMD hardcoded env vars from `config.kdl` and `10-performance.conf`.
     - [R2] Network & Sudoers: Write valid DNS (`1.1.1.1`, `8.8.8.8`, mode 0644) to `/mnt/etc/resolv.conf` before entering chroot, add in-chroot DNS check. Create temporary passwordless sudo rule `/mnt/etc/sudoers.d/99-installer-nopasswd` (mode 0440) for unprivileged yay/makepkg without password. Remove conflicting sudoers appends.
     - [R3] UEFI GRUB: Update grub-install to include `--removable` creating `/boot/efi/EFI/BOOT/BOOTX64.EFI`. Ensure both `/boot/efi/EFI/BOOT/BOOTX64.EFI` and `/boot/efi/EFI/GRUB/grubx64.efi` are synchronized.
     - [R4 Headless Support] Implement `AUTORUN=1`, `TARGET_DISK`, `ROOT_PASS`, `USER_PASS`, `CONFIRM=YES` to allow unattended automated installation without blocking prompts.
  2. Keep `install.sh` synchronized with `install-arch.sh`.
  3. Validate all changes: run `bash -n install-arch.sh`, `bash -n install.sh`, check git diffs, ensure no syntax errors.
  4. Write comprehensive `handoff.md` in your directory documenting all changes and verification outputs.
  5. Notify Project Orchestrator upon completion.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.
