# Handoff Report: Survey Explorer 3 (QEMU Test Stand & UEFI/OVMF Bootloader)

## Executive Summary
This report delivers the technical survey and architectural design for:
1. Host QEMU availability, OVMF firmware paths, and KVM acceleration status.
2. Root cause analysis and remediation for UEFI GRUB visibility (R3: `--removable` and `/EFI/BOOT/BOOTX64.EFI`).
3. Concrete automated testing architecture for full end-to-end VM installation and acceptance verification (R4).

---

## 1. Observation

### 1.1 QEMU Binaries & Package Availability
- Running `which qemu-system-x86_64 qemu-img` exited with return code 127:
  ```text
  which: no qemu-system-x86_64 in (/home/chezok/.gemini/antigravity-cli/bin:/home/chezok/.local/bin:...)
  which: no qemu-img in (/home/chezok/.gemini/antigravity-cli/bin:/home/chezok/.local/bin:...)
  bash: line 1: qemu-system-x86_64: command not found
  bash: line 1: qemu-img: command not found
  ```
- Package query `pacman -Qs qemu` returned no installed QEMU packages on the host.
- Upstream Arch `extra` repository packages:
  - `extra/qemu-system-x86` (version 11.1.1-2, 6.50 MiB download, 54.97 MiB installed): Provides `/usr/bin/qemu-system-x86_64` and `/usr/bin/qemu-system-i386`. Directly depends on `edk2-ovmf`, `qemu-system-x86-firmware`, `seabios`, `libslirp`, `liburing`, `capstone`, `fuse3`, `libaio`.
  - `extra/qemu-img` (version 11.1.1-2, 2.21 MiB download, 10.74 MiB installed): Provides `/usr/bin/qemu-img`.
  - `pacman -Sp edk2-ovmf qemu-system-x86 qemu-img` resolves clean URLs from Arch/CachyOS mirrors.

### 1.2 OVMF Firmware Paths
- Running `find /usr -iname "*ovmf*" -o -iname "*edk2*"` on the host system revealed no installed OVMF firmware images (only a CachyOS kernel config header `/usr/lib/modules/7.2.4-3-cachyos-bore/build/include/config/OVMF_DEBUG_LOG`).
- Verification against the official Arch Linux package `edk2-ovmf 202608-1` (package file database inspected via `https://archlinux.org/packages/extra/any/edk2-ovmf/files/`):
  - Primary 64-bit UEFI firmware executable: `/usr/share/edk2/x64/OVMF_CODE.4m.fd` (read-only code).
  - Primary 64-bit UEFI NVRAM variable template: `/usr/share/edk2/x64/OVMF_VARS.4m.fd` (copied to writable per-VM file).
  - Combined monolithic 4MB image: `/usr/share/edk2/x64/OVMF.4m.fd`.
  - Secure Boot firmware: `/usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd`.
  - Legacy directory symlinks installed by package: `/usr/share/ovmf` -> `edk2/x64`, `/usr/share/edk2-ovmf` -> `edk2/x64`, `/usr/share/OVMF` -> `edk2/x64`.
  - QEMU firmware descriptors: `/usr/share/qemu/firmware/60-edk2-ovmf-x86_64-4m.json`.

### 1.3 KVM Hardware Acceleration & Permissions
- Virtualization check (`lscpu`):
  - CPU: `AMD Ryzen 5 3500U with Radeon Vega Mobile Gfx` (4 cores, 8 threads).
  - Virtualization flag: `AMD-V` (`svm` present in CPU flags).
  - Kernel module `kvm_amd` is active in the running kernel (`linux-cachyos-bore 7.2.4-3`).
- Device node permissions (`ls -la /dev/kvm`):
  ```text
  crw-rw-rw- 1 root kvm 10, 232 Sep 30 21:52 /dev/kvm
  ```
  The device node mode is `0666` (`crw-rw-rw-`).
- Direct non-root permission test:
  Running `python3 -c "import os, fcntl; fd = os.open('/dev/kvm', os.O_RDWR); print('API version:', fcntl.ioctl(fd, 0xAE00, 0)); os.close(fd)"` succeeded as user `chezok`:
  `API version: 12`.
  KVM acceleration is fully functional for unprivileged non-root users.

### 1.4 Host Resources & Pre-existing Boot Media
- Host Memory (`free -h`): Total 5.7 GiB, Available 2.4 GiB, Free 634 MiB, Swap 5.7 GiB (0B used).
- Host Storage (`df -h`): 166 GiB available on `/dev/nvme0n1p2`.
- Pre-existing Arch Linux Live ISO located on host:
  ```text
  -rwxr-xr-x 1 chezok chezok 1.5G Sep 30 22:28 /home/chezok/backup_iso/archlinux-2026.09.01-x86_64.iso
  ```
  Inspection via `bsdtar -tf` confirmed valid official ISO containing:
  - Kernel: `arch/boot/x86_64/vmlinuz-linux`
  - Initramfs: `arch/boot/x86_64/initramfs-linux.img`
  - Root squashfs: `arch/x86_64/airootfs.sfs`
  - UEFI bootloaders: `EFI/BOOT/BOOTx64.EFI`, `loader/entries/01-archiso-linux.conf` (UUID: `2026-09-01-17-09-43-00`).

### 1.5 Current EFI State & Repository Script Analysis (R3)
- Host `/boot/efi` structure (`ls -laR /boot/efi`):
  - Partition: `/dev/nvme0n1p1` (511M FAT32, mounted at `/boot/efi`).
  - Contents: only `/boot/efi/EFI/arch/grubx64.efi` (163840 bytes).
  - Missing: `/boot/efi/EFI/BOOT/BOOTX64.EFI` does NOT exist.
- Repository scripts `install.sh` and `install-arch.sh`:
  - Verified identical (`cmp` exited 0, size 61050 bytes).
  - Line 403:
    ```bash
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck
    ```
    Notice: `--removable` flag is completely absent.
  - Interactive prompts blocking automation:
    - Line 76: `read -rp "Введите целевой диск..." TARGET_DISK_RAW`
    - Line 100: `read -rp "Подтвердите удаление данных (введите 'YES')..." CONFIRM`
    - Lines 105-106, 109-110: `read -rsp` for passwords.

---

## 2. Logic Chain

### 2.1 QEMU & KVM Feasibility for Non-Root Execution
1. Host user `chezok` cannot invoke `sudo` without entering a password (`sudo -n -l` exited with `sudo: a password is required`).
2. Virtual machine emulation via `qemu-system-x86_64` runs as a standard userspace process and opens `/dev/kvm`.
3. Because `/dev/kvm` is mode `0666` and user `chezok` successfully executed ioctl `0xAE00` against `/dev/kvm`, QEMU VM runs with near-native hardware virtualization speed (`-enable-kvm -cpu host`) without needing root or sudo privileges.
4. User-mode networking (SLIRP) (`-netdev user,id=net0`) runs without TUN/TAP or bridge privileges, providing guest internet access, built-in DHCP, DNS, and optional SSH port forwarding (`hostfwd=tcp:127.0.0.1:2222-:22`).
5. Therefore, running automated installation and testing inside a QEMU VM can be executed completely unprivileged by user `chezok` once `qemu-system-x86` and `edk2-ovmf` are present.

### 2.2 UEFI GRUB Visibility Root Cause & Fix (R3)
1. In `install-arch.sh:403`, GRUB is invoked with `--bootloader-id=GRUB` and without `--removable`.
2. This installs the binary exclusively to `/boot/efi/EFI/GRUB/grubx64.efi` and attempts to write an EFI NVRAM boot entry using `efibootmgr`.
3. On Intel Ivy Bridge systems (e.g. Pentium 2020M / HM70/HM76 chipsets) and many buggy OEM UEFI BIOSes:
   - NVRAM entries are frequently lost, not committed to flash, or ignored if non-standard.
   - The motherboard BIOS strictly falls back to querying the hard drive's ESP partition for the default UEFI specification fallback path: `\EFI\BOOT\BOOTX64.EFI`.
   - In QEMU OVMF with clean or non-persistent NVRAM, OVMF likewise prioritizes `\EFI\BOOT\BOOTX64.EFI`.
4. When `/boot/efi/EFI/BOOT/BOOTX64.EFI` is absent, the BIOS reports "No bootable device found" or fails to show the drive in the boot menu.
5. Invoking `grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck --removable`:
   - Instructs GRUB to install the EFI binary to `/boot/efi/EFI/BOOT/BOOTX64.EFI`.
   - To guarantee both standard NVRAM entries and fallback resilience, the installer should ensure both `/boot/efi/EFI/GRUB/grubx64.efi` and `/boot/efi/EFI/BOOT/BOOTX64.EFI` are populated:
     ```bash
     grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck --removable
     mkdir -p /boot/efi/EFI/GRUB
     cp /boot/efi/EFI/BOOT/BOOTX64.EFI /boot/efi/EFI/GRUB/grubx64.efi
     ```
   - This satisfies Acceptance Criteria: disk is recognized by any UEFI BIOS and boots `linux-cachyos-bore`.

### 2.3 Automated Test Harness Architecture (R4)
1. Direct partitioning/formatting on the host requires root/sudo privileges (`losetup`, `mkfs`, `mount`, `chroot`). Running inside a QEMU VM isolates all root operations to the guest, leaving the host untouched.
2. Resource budget:
   - Host has 2.4 GiB available RAM. VM configuration: `-m 2048M -smp 4` provides ample memory and 4 vCPUs without risking host OOM.
   - Storage: 25 GiB dynamic `qcow2` image (`qemu-img create -f qcow2 test-vm.qcow2 25G`) occupies only ~200 KB initially and ~5-7 GB upon installation completion.
3. Test media: Pre-existing `/home/chezok/backup_iso/archlinux-2026.09.01-x86_64.iso` eliminates multi-gigabyte ISO downloads over the network.
4. Test lifecycle in two automated stages:
   - **Stage 1 (Automated Installation)**:
     - Boot QEMU with OVMF, Live ISO, target `qcow2` disk, SLIRP networking, and shared repo directory via 9p (`-virtfs local,path=/home/chezok/dotfiles,mount_tag=dotfiles,security_model=none,readonly=on`).
     - Serial console (`-serial mon:stdio` / socket) executes automated unattended runner.
     - Live guest mounts 9p share, exports `AUTORUN=1 TARGET_DISK=/dev/vda ROOT_PASS=root USER_PASS=chezok`, and executes `install-arch.sh`.
     - Output is streamed and captured into `install.log`.
     - Guest cleanly powers off (`poweroff`).
   - **Stage 2 (Automated UEFI Boot & Acceptance Verification)**:
     - Boot QEMU with OVMF and target `qcow2` disk ONLY (`-cdrom` removed).
     - OVMF detects `/EFI/BOOT/BOOTX64.EFI`, launches GRUB.
     - GRUB loads `/boot/vmlinuz-linux-cachyos-bore` and mounts root partition.
     - Test assertion script executes inside guest or via serial console:
       1. `/boot/efi/EFI/BOOT/BOOTX64.EFI` exists.
       2. Kernel running is `*-cachyos-bore`.
       3. Services `NetworkManager`, `bluetooth`, `sddm`, `udisks2` are active/enabled.
       4. Verification exits with code 0 and VM powers off.

---

## 3. Caveats
1. **Host Package Installation Prerequisite**: `qemu-system-x86_64`, `qemu-img`, and `edk2-ovmf` are currently not installed in the host's `/usr/bin` and `/usr/share/edk2/`. They require a one-time package installation (`sudo pacman -S --needed qemu-system-x86 qemu-img edk2-ovmf`) or extraction of their official `.pkg.tar.zst` packages into a user-local directory.
2. **Serial Console Autologin in Archiso**: Arch Linux official ISO enables serial console login on `ttyS0`. To avoid manual keypresses on the boot menu, adding `-append "console=ttyS0,115200 archisobasedir=arch archisosearchuuid=2026-09-01-17-09-43-00 copytoram=n"` or utilizing a pre-seeded virtual configuration disk ensures immediate automated boot.
3. **Interactive Prompts in Current Installer**: `install-arch.sh` currently uses blocking `read` commands for target disk confirmation and passwords. Non-interactive environment variables (`AUTORUN=1`, `TARGET_DISK`, `ROOT_PASS`, `USER_PASS`) must be added to `install-arch.sh` to allow headless automation.

---

## 4. Conclusion
1. **OVMF Binaries**: Located in standard package `edk2-ovmf`. Firmware binary paths on Arch Linux / CachyOS are:
   - Code: `/usr/share/edk2/x64/OVMF_CODE.4m.fd`
   - Vars Template: `/usr/share/edk2/x64/OVMF_VARS.4m.fd`
   - Single Image: `/usr/share/edk2/x64/OVMF.4m.fd`
   - Symlinks: `/usr/share/edk2-ovmf/x64/` and `/usr/share/ovmf/x64/`
2. **KVM Acceleration**: Fully available, AMD-V enabled, `/dev/kvm` is mode `0666`, unprivileged execution confirmed with API version 12.
3. **R3 UEFI GRUB Implementation**:
   - `install-arch.sh` line 403 must be updated to include `--removable`.
   - Both `/boot/efi/EFI/BOOT/BOOTX64.EFI` (fallback) and `/boot/efi/EFI/GRUB/grubx64.efi` (NVRAM) must be generated.
4. **R4 Test Harness Architecture**:
   - Uses pre-existing `/home/chezok/backup_iso/archlinux-2026.09.01-x86_64.iso`.
   - Allocates 2048M RAM, 4 vCPUs, 25G qcow2 virtual disk.
   - Two-phase execution: (1) Unattended live installation via QEMU OVMF + 9p mount, (2) Direct UEFI disk boot verification of GRUB, CachyOS kernel, and systemd services.

---

## 5. Verification Method

### 5.1 Host Environment Verification
Run the following verification commands on the host:
```bash
# 1. Verify KVM availability and non-root access
ls -l /dev/kvm
python3 -c "import os, fcntl; fd = os.open('/dev/kvm', os.O_RDWR); print('KVM OK, fd:', fd); os.close(fd)"

# 2. Verify pre-existing Arch ISO
ls -lh /home/chezok/backup_iso/archlinux-2026.09.01-x86_64.iso

# 3. Check QEMU & OVMF package installation status
pacman -Q qemu-system-x86 qemu-img edk2-ovmf
```

### 5.2 R3 GRUB Code Verification
Inspect `/home/chezok/dotfiles/install-arch.sh`:
```bash
grep -n "grub-install" /home/chezok/dotfiles/install-arch.sh
# Expected updated line:
# grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck --removable
```

### 5.3 QEMU Automated VM Test Harness Execution Commands
Once `qemu-system-x86` and `edk2-ovmf` are installed:
```bash
# 1. Create temporary test workspace and qcow2 disk
mkdir -p /tmp/qemu-test
qemu-img create -f qcow2 /tmp/qemu-test/test-vm.qcow2 25G
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd /tmp/qemu-test/test-vars.fd

# 2. Stage 1: Run unattended installation in QEMU UEFI VM
qemu-system-x86_64 \
  -enable-kvm \
  -m 2048M \
  -smp 4 \
  -cpu host \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=/tmp/qemu-test/test-vars.fd \
  -drive if=virtio,format=qcow2,file=/tmp/qemu-test/test-vm.qcow2,cache=unsafe \
  -cdrom /home/chezok/backup_iso/archlinux-2026.09.01-x86_64.iso \
  -boot d \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -virtfs local,path=/home/chezok/dotfiles,mount_tag=dotfiles,security_model=none,readonly=on \
  -nographic \
  -serial mon:stdio

# 3. Stage 2: Boot installed system via UEFI OVMF (no CD-ROM)
qemu-system-x86_64 \
  -enable-kvm \
  -m 2048M \
  -smp 4 \
  -cpu host \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=/tmp/qemu-test/test-vars.fd \
  -drive if=virtio,format=qcow2,file=/tmp/qemu-test/test-vm.qcow2 \
  -boot c \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:2222-:22 \
  -device virtio-net-pci,netdev=net0 \
  -nographic \
  -serial mon:stdio
```

### 5.4 Acceptance Verification Checks inside Guest
Inside the booted guest system, assert:
```bash
# Verify BOOTX64.EFI presence
test -f /boot/efi/EFI/BOOT/BOOTX64.EFI && echo "BOOTX64.EFI OK"

# Verify kernel
uname -r | grep -q "cachyos-bore" && echo "Kernel OK"

# Verify services
systemctl is-active NetworkManager
systemctl is-active bluetooth
systemctl is-active sddm
systemctl is-active udisks2
```
All commands returning code 0 confirms acceptance criteria are fully met.
