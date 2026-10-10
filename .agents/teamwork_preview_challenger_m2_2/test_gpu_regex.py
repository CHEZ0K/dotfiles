#!/usr/bin/env python3
"""
Empirical test suite for GPU detection regexes in install-arch.sh / install.sh
"""
import subprocess
import unittest

def run_detection(vga_output):
    """
    Executes the exact bash detection snippet from install-arch.sh
    """
    cmd = """
    vga="$1"
    is_intel=0
    is_amd=0
    is_nvidia=0

    echo "$vga" | grep -qiE "Intel|8086" && is_intel=1 || true
    echo "$vga" | grep -qE "\\b(AMD|ATI|Radeon)\\b" && is_amd=1 || true
    echo "$vga" | grep -qE "\\b(NVIDIA)\\b" && is_nvidia=1 || true

    echo "INTEL=$is_intel AMD=$is_amd NVIDIA=$is_nvidia"
    """
    res = subprocess.run(["bash", "-c", cmd, "bash", vga_output], capture_output=True, text=True)
    out = res.stdout.strip()
    parts = dict(kv.split("=") for kv in out.split())
    return int(parts["INTEL"]), int(parts["AMD"]), int(parts["NVIDIA"])

class TestGpuDetection(unittest.TestCase):
    # 1. Intel Ivy Bridge and other Intel GPUs
    def test_intel_ivy_bridge_standard(self):
        vga = "00:02.0 VGA compatible controller: Intel Corporation 3rd Gen Core processor Graphics Controller (rev 09)"
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (1, 0, 0))

    def test_intel_pentium_2020m(self):
        vga = "00:02.0 VGA compatible controller: Intel Corporation 3rd Gen Core processor Graphics Controller (rev 09)\nSubsystem: Lenovo Device 3977"
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (1, 0, 0))

    def test_intel_pci_id_fallback(self):
        vga = "00:02.0 VGA compatible controller: Device 8086:0156 (rev 09)"
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (1, 0, 0))

    def test_intel_display_controller(self):
        vga = "00:02.0 Display controller: Intel Corporation HD Graphics 4000 (rev 09)"
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (1, 0, 0))

    def test_intel_arc(self):
        vga = "03:00.0 VGA compatible controller: Intel Corporation DG2 [Arc A770] (rev 08)"
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (1, 0, 0))

    # 2. QEMU and Virtual Machines (Must be Generic: 0, 0, 0)
    def test_qemu_standard_vga_pci_ids(self):
        vga = "00:01.0 VGA compatible controller: Device 1234:1111 (rev 02)"
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (0, 0, 0), "QEMU default VGA should not trigger Intel, AMD, or NVIDIA")

    def test_qemu_standard_vga_named(self):
        vga = "00:02.0 VGA compatible controller: Red Hat, Inc. QEMU Standard VGA"
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (0, 0, 0))

    def test_qemu_virtio_gpu(self):
        vga = "00:02.0 VGA compatible controller: Red Hat, Inc. Virtio GPU (rev 01)"
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (0, 0, 0))

    def test_qemu_qxl(self):
        vga = "00:02.0 VGA compatible controller: Red Hat, Inc. QXL paravirtual graphic card (rev 04)"
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (0, 0, 0))

    def test_qemu_cirrus(self):
        vga = "00:02.0 VGA compatible controller: Cirrus Logic GD 5446 (rev 00)"
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (0, 0, 0))

    def test_qemu_bochs(self):
        vga = "00:02.0 VGA compatible controller: Bochs VGA / VESA compatible graphics adapter (rev 00)"
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (0, 0, 0))

    def test_vmware_svga(self):
        vga = "00:0f.0 VGA compatible controller: VMware SVGA II Adapter"
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (0, 0, 0))

    def test_virtualbox_vga(self):
        vga = "00:02.0 VGA compatible controller: InnoTek Systemberatung GmbH VirtualBox Graphics Adapter"
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (0, 0, 0))

    # 3. AMD / ATI GPUs
    def test_amd_radeon_rx(self):
        vga = "01:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Navi 21 [Radeon RX 6800/6800 XT / 6900 XT] (rev c1)"
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (0, 1, 0))

    def test_amd_vega_mobile(self):
        vga = "04:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD] Picasso/Raven 2 [Radeon Vega Series / Radeon Vega Mobile Series] (rev c1)"
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (0, 1, 0))

    def test_ati_legacy(self):
        vga = "01:00.0 VGA compatible controller: ATI Technologies Inc RV770 [Radeon HD 4870]"
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (0, 1, 0))

    # 4. NVIDIA GPUs
    def test_nvidia_rtx(self):
        vga = "01:00.0 VGA compatible controller: NVIDIA Corporation GA106 [GeForce RTX 3060] (rev a1)"
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (0, 0, 1))

    def test_nvidia_3d_controller(self):
        vga = "01:00.0 3D controller: NVIDIA Corporation GP107M [GeForce GTX 1050 Mobile] (rev a1)"
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (0, 0, 1))

    # 5. Hybrid Dual GPU
    def test_intel_nvidia_optimus(self):
        vga = "00:02.0 VGA compatible controller: Intel Corporation 3rd Gen Core processor Graphics Controller (rev 09)\n01:00.0 3D controller: NVIDIA Corporation GF117M [GeForce 610M/710M/810M] (rev a1)"
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (1, 0, 1))

    # 6. Negative / Empty
    def test_empty_lspci(self):
        vga = ""
        i, a, n = run_detection(vga)
        self.assertEqual((i, a, n), (0, 0, 0))

if __name__ == "__main__":
    unittest.main()
