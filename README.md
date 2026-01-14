# Lightweight ASCON Cryptography Accelerator

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Vivado](https://img.shields.io/badge/Vivado-2024.2-blue)](https://www.xilinx.com/products/design-tools/vivado.html)
[![Verification](https://img.shields.io/badge/Simulation-PASSED-green)]()

> 🏆 **Second Prize - UIT IC Design Competition 2025**

A highly optimized RTL implementation of the ASCON authenticated encryption cipher, designed for integration into RISC-V 32-bit SoCs for IoT applications.

---

## 📊 Performance

| Metric | Value |
|--------|-------|
| **Throughput (Ascon-128a)** | 1,116 Mbps |
| **Throughput (Ascon-128)** | 426 Mbps |
| **Efficiency** | 0.83 Mbps/LUT |
| **LUTs** | 1,968 |
| **Registers** | 1,496 |
| **Max Frequency** | 200 MHz |
| **Target FPGA** | Xilinx Virtex-7 |

### Comparison with Literature

| Metric | This Work | Alharbi et al. | Khan et al. | Tran et al. |
|--------|-----------|----------------|-------------|-------------|
| Throughput (128a) | **1,116 Mbps** | 914 Mbps | 721.5 Mbps | 13,312 Mbps |
| Efficiency | **0.83 Mbps/LUT** | 0.56 Mbps/LUT | 0.26 Mbps/LUT | 2.03 Mbps/LUT |
| LUTs | 1,968 | 1,632 | 2,708 | 6,536 |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         ascon_top                                │
│  ┌─────────────┐   ┌──────────────────────┐   ┌──────────────┐  │
│  │  FIFOs &    │   │  ascon_core_optimized │   │   FIFOs &    │  │
│  │  Assemblers │──▶│   (Unified I/O)      │──▶│   Splitters  │  │
│  └─────────────┘   └──────────────────────┘   └──────────────┘  │
│                              │                                   │
│                    ┌─────────┴─────────┐                        │
│                    │ ascon_permutation │                        │
│                    │  (Iterative 1R/C) │                        │
│                    └───────────────────┘                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
ASCON/
├── rtl/                          # RTL Source Files
│   ├── ascon_core_optimized.v    # Optimized ASCON core (Unified I/O)
│   ├── ascon_top.v               # Top module with adapter logic
│   ├── ascon_permutation.v       # Iterative permutation (S-box, Linear)
│   ├── count_line_control.v      # Block counting logic
│   ├── data_assembler_.v         # 32→128-bit assembler
│   ├── data_assembler_160.v      # 32→160-bit assembler (for key)
│   ├── fifo_in.v                 # Input FIFO buffer
│   ├── fifo_split_128to32.v      # 128→32-bit output splitter
│   └── soc/                      # SoC Integration Files
│       ├── ascon_wb.v            # Wishbone B4 slave wrapper
│       ├── cpu2wb.v              # CPU-to-Wishbone bridge
│       ├── wb_interconnect.v     # Multi-slave bus arbiter
│       └── mcu.v                 # MCU reference design
├── tb/                           # Testbenches
│   ├── tb_ascon_optimized.v      # Main verification testbench
│   ├── tb_ascon_top.v            # Legacy testbench
│   └── ...                       # Component testbenches
├── constraints/
│   └── vc707.xdc                 # Virtex-7 constraints
└── docs/
    ├── Final_Ascon_Report.md     # Technical report
    └── RVX_Integration_Report.md # RISC-V integration guide
```

---

## 🔧 Supported Variants

| Variant | Key Size | Rate | Rounds (a/b) | IV |
|---------|----------|------|--------------|-----|
| **Ascon-128** | 128-bit | 64-bit | 12/6 | `0x80400c0600000000` |
| **Ascon-128a** | 128-bit | 128-bit | 12/8 | `0x80800c0800000000` |
| **Ascon-80pq** | 160-bit | 64-bit | 12/6 | `0x00000000a0400c06` |

---

## 🚀 Quick Start

### Prerequisites

- Xilinx Vivado 2020.2+ or Vivado 2024.2
- Git

### Clone Repository

```bash
git clone https://github.com/HuuHoc2508/Lightweight-ASCON-Cryptography-Accelerator-Source-only-.git
cd Lightweight-ASCON-Cryptography-Accelerator-Source-only-
```

### Run Simulation

```bash
cd ASCON
xvlog --sv rtl/*.v tb/tb_ascon_optimized.v
xelab tb_ascon_optimized -s sim_ascon
xsim sim_ascon -R
```

**Expected Output:**
```
======================================================
         ASCON-128 OPTIMIZED CORE TEST SUITE          
======================================================
[TEST 1] ASCON-128 Encryption Mode
         e_tag = 85be3484f05b2a2b1420df4eb1b3df90
[TEST 1] PASS - Tag matches expected value!
[TEST 2] ASCON-128 Decryption Mode
[TEST 2] PASS - Decryption finished without errors!
[TEST 3] ASCON-128a Encryption Mode
[TEST 3] PASS - ASCON-128a encryption finished!
======================================================
  PASSED: 3  |  FAILED: 0
  RESULT: ALL TESTS PASSED!
======================================================
```

---

## 🔌 RISC-V Integration

The accelerator includes a Wishbone B4 slave interface (`ascon_wb.v`) for easy integration with RISC-V cores.

### Memory Map

| Address | Register | Access | Description |
|---------|----------|--------|-------------|
| `0x00` | SETUP | W | `[0]=mode`, `[2:1]=variant` |
| `0x04` | STATUS | R/W | Write: Start, Read: done |
| `0x08` | KEY | W | 32-bit key words |
| `0x0C` | NONCE | W | 32-bit nonce words |
| `0x10` | TAG | R/W | Tag input/output |
| `0x14` | AD | W | Associated data |
| `0x18` | PT | R/W | Plaintext in / Ciphertext out |
| `0x1C` | CT | R/W | Ciphertext in / Plaintext out |

### Example C Code

```c
#define ASCON_BASE 0x80040000

#define ASCON_SETUP  (*(volatile uint32_t*)(ASCON_BASE + 0x00))
#define ASCON_STATUS (*(volatile uint32_t*)(ASCON_BASE + 0x04))
#define ASCON_KEY    (*(volatile uint32_t*)(ASCON_BASE + 0x08))
#define ASCON_NONCE  (*(volatile uint32_t*)(ASCON_BASE + 0x0C))
#define ASCON_PT     (*(volatile uint32_t*)(ASCON_BASE + 0x18))

void ascon_encrypt(uint32_t *key, uint32_t *nonce, uint32_t *pt) {
    ASCON_SETUP = 0x00; // Ascon-128, Encrypt mode
    
    for (int i = 0; i < 5; i++) ASCON_KEY = key[i];
    for (int i = 0; i < 4; i++) ASCON_NONCE = nonce[i];
    for (int i = 0; i < 4; i++) ASCON_PT = pt[i];
    
    ASCON_STATUS = 1; // Start
    while (!(ASCON_STATUS & 1)); // Wait for done
}
```

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👥 Authors

- **Luong Trung Duong** - RTL Design & Optimization
- **ASIC LAB - UIT** - System Integration

## 🙏 Acknowledgments

- ASCON Algorithm: [https://ascon.iaik.tugraz.at/](https://ascon.iaik.tugraz.at/)
- RISC-V Steel: [https://github.com/riscv-steel](https://github.com/riscv-steel)
