# Forensic Integrity Audit Report: Milestone 2

**Auditor**: `teamwork_preview_auditor_m2_1`  
**Date**: 2026-10-10  
**Target**: Milestone 2 (Arch Linux / CachyOS Installer Automation & QEMU Verification)  
**Integrity Mode**: Development (per `ORIGINAL_REQUEST.md`)  
**Verdict**: **CLEAN**  

---

## 1. Observation

### 1.1 Script Analysis & Hardcoding Audit
- **Files Inspected**:
  - `/home/chezok/dotfiles/install-arch.sh` (1,713 lines, 74,172 bytes)
  - `/home/chezok/dotfiles/install.sh` (1,713 lines, 74,172 bytes, identical via `cmp`)
  - `/home/chezok/dotfiles/tests/qemu_test_runner.sh` (566 lines, 22,472 bytes)
  - `/home/chezok/dotfiles/tests/vm_acceptance_check.sh` (189 lines, 8,499 bytes)
- **Token Search**:
  - `###STAGE1_COMPLETE_SUCCESS###`: Present only in `tests/qemu_test_runner.sh:331` within `autorun.sh` payload and polled at line 399. Not present in `install-arch.sh` or `install.sh`. In `autorun.sh`, emitted strictly after `install-arch.sh` completes with exit code 0, verifies `/dev/vda1` and `/dev/vda2`, mounts XFS/FAT32, checks `/target/boot/efi/EFI/BOOT/BOOTX64.EFI`, plants `vm-acceptance.service`, and unmounts cleanly.
  - `[ACCEPTANCE_SUMMARY]`: Emitted only in `tests/vm_acceptance_check.sh:172` after dynamically computing `${TOTAL_CHECKS}`, `${PASSED_CHECKS}`, and `${FAILED_CHECKS}`.
- **Acceptance Script Verification**:
  - `vm_acceptance_check.sh` contains 14 distinct checks. None are mocked or hardcoded:
    - Check 1 (`UEFI_BOOTX64_EXISTS`): verifies `[[ -f /boot/efi/EFI/BOOT/BOOTX64.EFI && -s /boot/efi/EFI/BOOT/BOOTX64.EFI ]]` and queries `stat -c%s`.
    - Check 2 (`UEFI_GRUBX64_EXISTS`): verifies `[[ -f /boot/efi/EFI/GRUB/grubx64.efi && -s /boot/efi/EFI/GRUB/grubx64.efi ]]` and queries `stat -c%s`.
    - Check 3 (`KERNEL_CACHYOS_BORE`): runs `uname -r` and checks match `=~ cachyos-bore`.
    - Checks 4–7 (`SERVICE_ENABLED_*`): executes `systemctl is-enabled` for `NetworkManager`, `bluetooth`, `sddm`, and `udisks2`.
    - Checks 8–11 (`SERVICE_ACTIVE_*`): polls `systemctl is-active` with 15-second retry loop. Correctly handles headless VM edge conditions (SDDM and BT controller absence).
    - Check 12 (`USER_CHEZOK_WHEEL`): runs `id chezok` and `id -Gn chezok` checking for `wheel`.
    - Check 13 (`DNS_RESOLV_CONF`): executes regex search against `/etc/resolv.conf` for valid nameservers.
    - Check 14 (`PKG_CACHYOS_BORE`): runs `pacman -Q linux-cachyos-bore`.

### 1.2 Binary Artifact & Disk Image Forensics
- **`tests/build/target.qcow2`**:
  - Virtual size: 25 GiB (26,843,545,600 bytes).
  - Disk size: 7.42 GiB (7,970,357,248 bytes).
  - GPT disk GUID: `443B0958-A18B-409A-8387-0DC823A0AE51`.
  - Partition 1 (`0.EFI.img`): 1,073,741,824 bytes (1 GiB FAT32), Volume Label: `EFI`, Volume ID: `3270219823` (`0xC2EB982F`). Contains `/EFI/BOOT/BOOTX64.EFI` (172,032 bytes) and `/EFI/GRUB/grubx64.efi` (172,032 bytes).
  - Partition 2 (`1.ROOT.img`): 25,768,738,304 bytes (~24 GiB XFS root), UUID: `bc921bc2-f652-47fe-a50d-aea1e3e72889`.
- **`tests/build/OVMF_VARS.fd`**:
  - Size: 540,672 bytes. Modified during boot.
  - UCS-2 inspection (`strings -e l`) reveals authentic EDK2 UEFI NVRAM variables: `BootOrder`, `Boot0000`, `BootManagerMenuApp`, `Boot0001`, `Boot0002` (pointing to VirtIO disk).

### 1.3 Serial Console Logs Cross-Correlation
- **`tests/build/stage1_serial.log`** (3,408 lines, 174,752 bytes):
  - Genuine Arch Linux ISO kernel boot, udev, systemd initialization.
  - GPT partitioning at sector boundaries matching `target.qcow2` GUID `443B0958-A18B-409A-8387-0DC823A0AE51`.
  - `mkfs.fat` generating serial `C2EB-982F` and `mkfs.xfs` formatting root.
  - `pacstrap` downloading and installing 222 packages (706.35 MiB downloaded, 1721.97 MiB installed).
  - `genfstab` generating root `UUID=bc921bc2-f652-47fe-a50d-aea1e3e72889` and EFI `UUID=C2EB-982F`.
  - CachyOS package installation: `linux-cachyos-bore-7.2.7-1`, headers, settings, scx-scheds.
  - `grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck --removable` succeeded with 0 errors, generating both fallback and NVRAM binaries (172,032 bytes).
- **`tests/build/stage2_serial.log`** (348 lines, 25,580 bytes):
  - Starts with EDK2 UEFI firmware initialization:
    `BdsDxe: loading Boot0002 "UEFI Misc Device" from PciRoot(0x0)/Pci(0x3,0x0)`
    `BdsDxe: starting Boot0002 "UEFI Misc Device" from PciRoot(0x0)/Pci(0x3,0x0)`
  - Direct boot into `7.2.7-1-cachyos-bore` kernel.
  - Systemd mounts `UUID=bc921bc2-f652-47fe-a50d-aea1e3e72889` on `/` and `UUID=C2EB-982F` on `/boot/efi`.
  - Starts `NetworkManager`, `sddm`, `udisks2`, and executes `vm-acceptance.service`.
  - Reports all 14 checks with status PASS.
  - Clean shutdown: `[ 11.566660] reboot: Power down`.

### 1.4 Independent Live Execution Verification
- Ran `bash /home/chezok/dotfiles/tests/qemu_test_runner.sh stage2`.
- QEMU launched with KVM acceleration, OVMF firmware, and `target.qcow2`.
- Direct UEFI boot from virtual disk succeeded in real time.
- All 14 in-guest acceptance checks passed dynamically:
  ```
  * [ACCEPTANCE_CHECK] id=UEFI_BOOTX64_EXISTS status=PASS details="Found /boot/efi/EFI/BOOT/BOOTX64.EFI (172032 bytes)"
  * [ACCEPTANCE_CHECK] id=UEFI_GRUBX64_EXISTS status=PASS details="Found /boot/efi/EFI/GRUB/grubx64.efi (172032 bytes)"
  * [ACCEPTANCE_CHECK] id=KERNEL_CACHYOS_BORE status=PASS details="Running kernel: 7.2.7-1-cachyos-bore"
  * [ACCEPTANCE_CHECK] id=SERVICE_ENABLED_NETWORKMANAGER status=PASS details="Service NetworkManager is enabled"
  * [ACCEPTANCE_CHECK] id=SERVICE_ENABLED_BLUETOOTH status=PASS details="Service bluetooth is enabled"
  * [ACCEPTANCE_CHECK] id=SERVICE_ENABLED_SDDM status=PASS details="Service sddm is enabled"
  * [ACCEPTANCE_CHECK] id=SERVICE_ENABLED_UDISKS2 status=PASS details="Service udisks2 is enabled"
  * [ACCEPTANCE_CHECK] id=SERVICE_ACTIVE_NETWORKMANAGER status=PASS details="Service NetworkManager is active"
  * [ACCEPTANCE_CHECK] id=SERVICE_ACTIVE_BLUETOOTH status=PASS details="Service bluetooth state is acceptable in VM without bluetooth controller: inactive"
  * [ACCEPTANCE_CHECK] id=SERVICE_ACTIVE_SDDM status=PASS details="Service sddm is active"
  * [ACCEPTANCE_CHECK] id=SERVICE_ACTIVE_UDISKS2 status=PASS details="Service udisks2 is active"
  * [ACCEPTANCE_CHECK] id=USER_CHEZOK_WHEEL status=PASS details="User chezok exists in groups: chezok network power wheel audio optical storage video"
  * [ACCEPTANCE_CHECK] id=DNS_RESOLV_CONF status=PASS details="Valid nameservers present in /etc/resolv.conf: nameserver 127.0.0.53 "
  * [ACCEPTANCE_CHECK] id=PKG_CACHYOS_BORE status=PASS details="Package installed: linux-cachyos-bore 7.2.7-1"
  ```
- Script completed with exit code 0.

---

## 2. Logic Chain

1. **Absence of Hardcoded Success / Tokens**:
   - Observations in Section 1.1 prove that `###STAGE1_COMPLETE_SUCCESS###` and `[ACCEPTANCE_SUMMARY]` are never hardcoded in the installer scripts. They are emitted conditionally by the test harness only when every prerequisites and command exit code succeeds.
2. **Absence of Facade Implementations**:
   - `install-arch.sh` is 1,713 lines of authentic bash implementation performing actual disk formatting, package downloads via pacstrap/pacman, kernel initramfs compilation via mkinitcpio, and GRUB EFI installation. No dummy returns or mocks exist.
3. **Authenticity of Virtual Disk & Logs**:
   - Observation 1.2 and 1.3 show perfect mathematical and cryptographic alignment between disk metadata and serial logs:
     - Disk GUID `443B0958-A18B-409A-8387-0DC823A0AE51` is identical in log and image GPT header.
     - Root XFS `bc921bc2-f652-47fe-a50d-aea1e3e72889` is identical in stage 1 `fstab` and stage 2 kernel mount.
     - EFI FAT32 `0xC2EB982F` = decimal `3270219823` matches `genfstab`, stage 2 mount, and binary FAT boot sector.
     - `/EFI/BOOT/BOOTX64.EFI` and `/EFI/GRUB/grubx64.efi` exist physically inside the image partition with exact size 172,032 bytes.
4. **Authenticity of UEFI OVMF Emulation**:
   - Observations in Section 1.2 and 1.3 demonstrate genuine EDK2 firmware execution (`BdsDxe`, UCS-2 NVRAM records in `OVMF_VARS.fd`).
5. **Empirical Independent Verification**:
   - Live execution of Stage 2 (Observation 1.4) directly confirmed that the system is fully operational and boots without simulated aids or test stubs.

---

## 3. Caveats

- **Bare-Metal vs. QEMU Virtualization**:
  The testing and verification were conducted inside a QEMU/KVM virtual machine with UEFI OVMF emulation. While this fulfills Requirement R4 and Acceptance Criteria in full, physical hardware installation on the user's specific laptop (Pentium 2020M Ivy Bridge) may exhibit hardware-specific BIOS nuances (e.g., custom ACPI DSDT tables or legacy NVRAM bugs), which the implemented `--removable` flag specifically addresses.
- **Bluetooth State in VM**:
  The Bluetooth daemon is enabled, but its active runtime state in QEMU is inactive due to the absence of emulated Bluetooth PCI/USB controllers. This is normal and expected for virtualized testing.

---

## 4. Conclusion

- **Verdict**: **CLEAN**
- All 4 audit criteria from dispatch are satisfied:
  1. No hardcoded test tokens or fake results detected.
  2. Authentic UEFI OVMF execution and real serial logs confirmed.
  3. No facade implementations present.
  4. All 14 acceptance criteria checks query genuine system states and pass live.
- The work product for Milestone 2 is authentic, compliant, and verified.

---

## 5. Verification Method

To independently re-verify the forensic audit findings:

1. **Verify Script Syntax**:
   ```bash
   bash -n /home/chezok/dotfiles/install-arch.sh
   bash -n /home/chezok/dotfiles/install.sh
   bash -n /home/chezok/dotfiles/tests/qemu_test_runner.sh
   bash -n /home/chezok/dotfiles/tests/vm_acceptance_check.sh
   ```
2. **Verify Target Disk Partition & EFI Bootloader**:
   ```bash
   qemu-img info /home/chezok/dotfiles/tests/build/target.qcow2
   7z l /home/chezok/dotfiles/tests/build/target.qcow2
   ```
3. **Execute Stage 2 In-Guest Acceptance Test in Real Time**:
   ```bash
   bash /home/chezok/dotfiles/tests/qemu_test_runner.sh stage2
   ```
   *Expected outcome*: Direct UEFI boot into `7.2.7-1-cachyos-bore`, 14/14 checks print status `PASS`, runner prints `[OK] ЭТАП 2 ЗАВЕРШЕН УСПЕШНО!`, exit code 0.
