# DISPATCH: Milestone 1 Explorer 1 (Package Sync & Config Details)

- Working Directory: /home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_1
- ORIGINAL_REQUEST path: /home/chezok/dotfiles/.agents/ORIGINAL_REQUEST.md
- PROJECT.md path: /home/chezok/dotfiles/.agents/PROJECT.md
- Scope: Formulate exact code edits for `install-arch.sh` and dotfiles for Requirement R1.
- Inputs to inspect:
  - `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_survey_1/handoff.md`
  - `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_survey_2/handoff.md`
  - `/home/chezok/dotfiles/install-arch.sh` (package lists, kernel, drivers)
  - `/home/chezok/dotfiles/.config/niri/config.kdl` and performance configs
- Tasks:
  1. Specify exact lines and package additions in `install_pacman_packages()`:
     - `linux-cachyos-bore`, `linux-cachyos-bore-headers`, `cachyos-settings`, `scx-scheds`.
     - Intel Ivy Bridge: `mesa`, `xf86-video-intel`, `vulkan-intel`, `intel-media-driver`, `intel-ucode`.
     - Environment: `niri`, `xwayland-satellite`, `hyprland`, `sddm`, `weston`, `quickshell`, `vibepanel-bin`/`vibepanel-git`, `swaync`, `awww`, `waybar`.
     - Remove redundant Arch generic `linux` & `linux-headers`.
     - Remove AMD hardcoded env vars (`radeonsi`) in `config.kdl` and performance configs.
  2. Document exact diff/specification in `handoff.md` in your directory.
  3. Send completion message to parent.

## 2026-10-01T00:09:43Z
You are Milestone 1 Explorer 1. Your working directory is `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_1`.
You MUST read `/home/chezok/dotfiles/.agents/ORIGINAL_REQUEST.md`, `/home/chezok/dotfiles/.agents/PROJECT.md`, and your dispatch instructions at `/home/chezok/dotfiles/.agents/teamwork_preview_explorer_m1_1/DISPATCH.md` before starting work.
Formulate the exact edits required for `install-arch.sh` package lists (kernel, Intel Ivy Bridge drivers, Wayland/SDDM/Niri/Hyprland packages, AUR prebuilts) and dotfiles config cleanups (removing hardcoded AMD vars).
Document your findings and exact code plan in `handoff.md` in your directory.
Send a completion message to parent when done.
