# FFT-DIF-FPGA-ASIC: Parameterized Radix-2 DIF FFT Subsystem & UVM 1.2 Verification Suite

[![SystemVerilog](https://img.shields.io/badge/SystemVerilog-IEEE%201800--2017-blue.svg)](https://standards.ieee.org/)
[![UVM](https://img.shields.io/badge/UVM-1.2%20%2F%20IEEE%201800.2-green.svg)](https://accellera.org/)
[![Coverage](https://img.shields.io/badge/Functional%20Coverage-100%25-brightgreen.svg)]()
[![Assertions](https://img.shields.io/badge/SVA%20Assertions-100%25-brightgreen.svg)]()
[![Code Coverage](https://img.shields.io/badge/Statement%20Coverage-99.85%25-brightgreen.svg)]()
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A high-performance, area-optimized, **fully parameterized Fast Fourier Transform (FFT) Subsystem** and complete **UVM 1.2 Verification Environment**. The design features a continuous-streaming **Radix-2 Decimation-in-Frequency (DIF) Single-Path Delay Feedback (R2SDF)** architecture with an **AHB-Lite Bus Interface**, dual-clock asynchronous FIFOs, natural output ordering, and hardware flow control, targeted for both **ASIC (RTL-to-GDS)** and **FPGA (Xilinx DSP48)** implementation flows.

---

## 1. Architectural Highlights

### 1.1 Complete Hardware Subsystem (`top_wrapper`)
* **Host Interface**: Standard 32-bit zero-wait-state **AHB-Lite Slave** with 2-cycle `HRESP` error signaling.
* **Address Decoding**: Memory-mapped control and status registers (`0x000..0x03F`) and streaming FIFO window (`0x100..0x1FF`).
* **Clock Domain Crossing (CDC)**: Dual-clock domain architecture bridging the 100 MHz bus clock (`HCLK`) and ~143 MHz coprocessor core clock (`ip_clk`) via 64-depth asynchronous FIFOs with Gray code synchronization.
* **Natural Output Ordering**: Integrated ping-pong reorder buffer outputting natural frequency bins ($0..N-1$) without host CPU reordering overhead.
* **Hardware Flow Control**: Watermark-based DMA request lines (`dma_rx_req`, `dma_tx_req`) and sticky Write-1-to-Clear (W1C) interrupt generation (`irq`).

### 1.2 Pipelined FFT Core Datapath (`fft_top`)
* **Algorithm**: Radix-2 Decimation-in-Frequency (DIF).
* **Architecture**: Single-Path Delay Feedback (R2SDF) continuous streaming pipeline.
* **Throughput**: **1 complex sample per clock cycle** sustained streaming (100% duty cycle).
* **Pipeline Latency**: Exactly **$N - 1$ clock cycles** from first input sample to `valid_out`.
* **Hardware Allocation for Arbitrary $N$**:
  * **$S = \log_2(N)$ Butterfly Processing Elements** (1 butterfly PE per stage).
  * **Only $S - 2$ Complex Multipliers** (the penultimate stage uses a zero-multiplier swap/negate mux; final stage is direct wire pass-through).
  * **$N - 1$ Complex Delay Registers** ($\sum_{s=0}^{S-1} 2^{S-1-s} = N - 1$).
* **Arithmetic & Precision**: 16-bit signed fixed-point (**Q1.15**) for real and imaginary channels.
* **Zero Bit-Growth Scaling**: Stage-by-stage divide-by-2 scaling (`>>> 1` with $+1$ Round-Half-Up and saturation clamping), computing $X[k] = \frac{1}{N} \sum_{n=0}^{N-1} x[n] W_N^{nk}$.

---

## 2. Subsystem Interface & Memory Map

```
                          ┌────────────────────────────────────────────────────────┐
                          │            top_wrapper (AHB-Lite Subsystem)            │
                          │                                                        │
           HCLK ─────────▶│  ┌──────────────┐     ┌───────────┐     ┌───────────┐  │
        HRESETn ─────────▶│  │   AHB-Lite   │────▶│  IN FIFO  │────▶│  R2SDF    │  │
         ip_clk ─────────▶│  │   Slave &    │     │  (Async)  │     │  FFT Core │  │
                          │  │  Reg File    │◀────│  OUT FIFO │◀────│  (ip_clk) │  │
           HSEL ─────────▶│  └──────────────┘     │  (Async)  │     └───────────┘  │
          HADDR ─────────▶│         │             └───────────┘           │        │
         HTRANS ─────────▶│         ▼                                     ▼        │
         HWRITE ─────────▶│   ┌───────────┐                         ┌───────────┐  │
          HSIZE ─────────▶│   │ Interrupt │                         │ Reorder   │  │
         HWDATA ─────────▶│   │ & DMA Ctrl│                         │ Ping-Pong │  │
         HREADY ─────────▶│   └───────────┘                         └───────────┘  │
                          │         │                                              │
      HREADYOUT ◀─────────│         │                                              │
         HRDATA ◀─────────│         ▼                                              │
          HRESP ◀─────────│    irq, dma_rx_req, dma_tx_req                         │
                          └────────────────────────────────────────────────────────┘
```

### 2.1 Memory-Mapped Register File

| Register | Offset | Access | Reset Value | Description |
| :--- | :---: | :---: | :---: | :--- |
| **`ID`** | `0x000` | RO | `0x4950_0001` | Peripheral hardware signature (`"IP\0\1"`). |
| **`VERSION`** | `0x004` | RO | `0x0001_0000` | Subsystem version: Major=1, Minor=0, Patch=0. |
| **`CTRL`** | `0x008` | RW | `0x0000_0000` | [0] `enable`, [1] `dma_en`, [29] `soft_reset` (SC), [30] `flush_in` (SC), [31] `flush_out` (SC). |
| **`STATUS`** | `0x00C` | RO | `0x0000_002A` | [0] `busy`, [1] `in_empty`, [2] `in_full`, [3] `out_empty`, [4] `out_full`, [5] `in_almost_empty`, [6] `out_almost_full`. |
| **`INT_EN`** | `0x010` | RW | `0x0000_0000` | Mask bits: [0] `frame_done_en`, [1] `in_overflow_en`, [2] `out_underflow_en`. |
| **`INT_STATUS`**| `0x014` | W1C | `0x0000_0000` | Sticky flags: [0] `frame_done`, [1] `in_overflow`, [2] `out_underflow` (Write-1-to-Clear). |
| **`IN_LEVEL`** | `0x018` | RO | `0x0000_0000` | Current 32-bit sample occupancy of the IN FIFO ($0..64$). |
| **`OUT_LEVEL`**| `0x01C` | RO | `0x0000_0000` | Current 32-bit sample occupancy of the OUT FIFO ($0..64$). |
| **`IN_THRESH`**| `0x020` | RW | `0x0000_0010` | Watermark threshold for `dma_rx_req` assertion (default: 16). |
| **`OUT_THRESH`**| `0x024`| RW | `0x0000_0030` | Watermark threshold for `dma_tx_req` assertion (default: 48). |
| **`FIFO_DATA`**| `0x100..0x1FF` | WR | `-` | Write port pushes into IN FIFO; Read port pops from OUT FIFO. |

---

## 3. Parameterized Hardware Scaling

For any arbitrary power-of-2 FFT point size $N = 2^S$:

| Point Size ($N$) | Stages ($S$) | Delay Registers ($N-1$) | Complex Multipliers ($S-2$) | Penultimate Stage ($W_4$) | Final Stage ($W_2$) | Latency |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **$N = 16$** | 4 | 15 | **2** | Stage 2 ($D=2$) | Stage 3 ($D=1$) | 15 cycles |
| **$N = 32$** | 5 | 31 | **3** | Stage 3 ($D=2$) | Stage 4 ($D=1$) | 31 cycles |
| **$N = 64$** | 6 | 63 | **4** | Stage 4 ($D=2$) | Stage 5 ($D=1$) | 63 cycles |
| **$N = 128$** | 7 | 127 | **5** | Stage 5 ($D=2$) | Stage 6 ($D=1$) | 127 cycles |
| **$N = 512$** | 9 | 511 | **7** | Stage 7 ($D=2$) | Stage 8 ($D=1$) | 511 cycles |
| **$N = 1024$**| 10| 1023| **8** | Stage 8 ($D=2$) | Stage 9 ($D=1$) | 1023 cycles|

---

## 4. Dual-Target Microarchitecture (ASIC vs. FPGA)

The codebase supports seamless targeting of both **ASIC (RTL-to-GDS)** and **FPGA (Vivado)** flows via the `TARGET_FPGA` configuration flag in `fft_pkg.sv`:

| Feature | ASIC Target (`TARGET_FPGA = 0`) *(Default)* | FPGA Target (`TARGET_FPGA = 1`)* |
| :--- | :--- | :--- |
| **Multiplier Architecture** | Custom **Radix-4 Modified Booth Multipliers** with two-level 4:2 compressor trees and final Brent-Kung adders. | Inferred **Hard DSP48 Slices** via `(* use_dsp = "yes" *)` with zero LUT waste. |
| **Adder / Subtractor** | Parameterized **Brent-Kung Parallel-Prefix Adders** with bounded fan-out ($\le 2$). | Inferred **Hard Vertical Carry Chains** (`CARRY4` / `CARRY8`). |
| **How to Select** | Default mode (no compile flags required). | Compile with `+define+TARGET_FPGA` or `-verilog_define TARGET_FPGA`. |

---

## 5. Production-Grade UVM 1.2 Verification Suite

The subsystem is thoroughly verified using an IEEE 1800.2 **UVM 1.2** environment adhering to enterprise sign-off standards:

```
uvm_test_top (fft_base_test / derived tests)
 └── env (fft_env)
      ├── ahb_agent (ahb_agent - UVM_ACTIVE)
      │    ├── ahb_sqr (ahb_sequencer)
      │    ├── ahb_drv (ahb_driver - pipelined AHB master)
      │    └── ahb_mon (ahb_monitor - passive protocol monitor)
      ├── sideband_agent (sideband_agent - UVM_PASSIVE)
      │    ├── sb_mon (sideband_monitor - irq & dma edge tracker)
      │    └── sb_sqr (sideband_sequencer - reactive synchronization)
      ├── m_scoreboard (fft_scoreboard)
      │    └── DPI-C Foreign Import (fft_dpi_pkg::fft_radix2_dif_32)
      ├── m_coverage (fft_coverage - protocol, register, sideband covergroups)
      ├── m_reg_model (fft_reg_block - UVM RAL)
      │    ├── m_reg_adapter (ahb_reg_adapter)
      │    └── m_reg_predictor (uvm_reg_predictor #(ahb_seq_item))
      └── m_virtual_sequencer (fft_virtual_sequencer)
```

### 5.1 Verification Features
* **Virtual Sequencer & Sequences**: All stimulus is coordinated through virtual sequences (`fft_base_vseq` API), keeping tests clean and modular.
* **Reactive Sideband Synchronization**: Live sideband events (`irq`, `dma_rx_req`, `dma_tx_req`) are captured by `sideband_monitor` and queued into `sideband_sequencer` FIFOs, allowing tests to synchronize reactively without polling.
* **Direct C++ DPI-C Reference Model**: High-performance, pure DPI-C function import (`fft_dpi_pkg::fft_radix2_dif_32`) links the bit-accurate C++ golden model with zero simulation overhead.
* **UVM Register Abstraction Layer (RAL)**: Full register model with explicit prediction and automatic hardware reset checking (`fft_reg_reset_test`).
* **SVA Concurrent Assertions**: Bus protocol stability, two-cycle error handshaking, word alignment, and signal validity.

### 5.2 Test Catalog (9 Regression Tests)

| Test Name | Executed Virtual Sequence | Target Scenario |
| :--- | :--- | :--- |
| `fft_sanity_test` | `fft_single_frame_vseq` | Sanity DC verification, peripheral ID check, and IRQ clearance. |
| `fft_burst_test` | `fft_burst_transfer_vseq` | High-throughput AHB INCR burst streaming and FIFO level tracking. |
| `fft_reg_reset_test` | `uvm_reg_hw_reset_seq` | Standard UVM hardware reset test, RO protection, explicit prediction. |
| `fft_multi_frame_test` | `fft_multi_frame_vseq` | Multi-frame continuous randomized streaming with live DPI-C comparison. |
| `fft_bus_error_test` | `fft_bus_protocol_error_vseq` | 2-cycle `HRESP` error responses for unaligned, unmapped, and invalid sizes. |
| `fft_fifo_boundary_test` | `fft_fifo_boundary_overflow_vseq`| Full FIFO boundary (64 words), overflow drop, and empty underflow reads. |
| `fft_dma_handshake_test` | `fft_dma_handshake_vseq` | Dynamic watermark threshold adjustments and DMA request assertions. |
| `fft_reset_flush_test` | `fft_control_reset_flush_vseq` | Dynamic FIFO flush commands, synchronous soft reset, and recovery. |
| `fft_coverage_closure_test`| `fft_stress_vseq` | Arithmetic saturation clamping, multiplier ceiling, backpressure stalling. |

### 5.3 Sign-Off Coverage Results

| Metric | Target | Achieved Result | Status |
| :--- | :---: | :---: | :---: |
| **UVM Tests Passing** | 100% (9/9) | **100% (9/9 Passed)** | **CLOSED** |
| **UVM Errors / Fatals** | 0 | **0 Errors, 0 Fatals** | **CLOSED** |
| **Functional Covergroup Bins** | 100.0% | **100.00% (91/91 bins)** | **CLOSED** |
| **SystemVerilog Assertions (SVA)** | 100.0% | **100.00% (6/6 assertions)** | **CLOSED** |
| **Statement Code Coverage** | $\ge 95.0\%$ | **99.85% (33,217/33,264)** | **CLOSED** |
| **Branch Code Coverage** | $\ge 90.0\%$ | **94.72%** *(99.2% adjusted)* | **CLOSED** |
| **Condition Coverage** | $\ge 85.0\%$ | **94.28%** *(100.0% adjusted)* | **CLOSED** |

For detailed verification documentation, see **[`VERIFICATION/README.md`]**.
For the formal verification plan, see **[`Docs/Vplan/vplan_specification.md`]**.
For architectural code coverage waiver justifications, see **[`Docs/Vplan/coverage_waiver_matrix.md`]**.

---

## 6. How to Run Simulation

### 6.1 UVM Simulation & Regression (QuestaSim)

All UVM simulations are driven by the unified script **`VERIFICATION/Questa_SIM/uvm/run.do`**:

```tcl
cd VERIFICATION/Questa_SIM/uvm

# 1. Run sanity test:
do run.do

# 2. Run specific test:
do run.do fft_burst_test
do run.do fft_multi_frame_test
do run.do fft_reg_reset_test

# 3. Run complete 9-test regression and merge coverage:
do run.do regression
```

#### Command-Line Batch Execution:
```bash
cd VERIFICATION/Questa_SIM/uvm

# Run single test in batch mode:
vsim -c -do "do run.do fft_sanity_test; quit"

# Run full regression suite:
vsim -c -do "do run.do regression; quit"
```

### 6.2 Standalone Module Testbenches
Direct module-level testbenches (non-UVM) for individual submodules:

```tcl
cd VERIFICATION/Questa_SIM/tb

# Run top subsystem testbench:
do run.do top

# Run standalone FFT core testbench:
do run.do fft

# Run asynchronous FIFO testbench:
do run.do fifo

# Run AHB slave testbench:
do run.do slave
```

### 6.3 Twiddle Factor Generation Script
To generate synthesizable ROMs for arbitrary point sizes $N$:

```bash
# Generate twiddle ROM for N = 32:
python DESIGN/scripts/generate_twiddles.py -N 32

# Generate twiddle ROM for N = 64:
python DESIGN/scripts/generate_twiddles.py -N 64
```

---

## 7. Directory Structure

```
FFT-DIF-FPGA-ASIC/
├── README.md                      # Repository master overview
├── LICENSE                        # MIT License
├── .gitignore                     # Git ignore rules for simulation & synthesis runs
├── generate_drawio.py             # Draw.io schematic generation script
├── Docs/                          # Architecture documentation & verification plan
│   ├── fft_r2sdf_design.md        # R2SDF pipelined core design document
│   ├── fft_r2sdf_architecture.drawio
│   ├── Radix2_DIT_DIF_FFT.pptx
│   └── Vplan/                     # ChipVerify-standard Verification Plan
│       ├── vplan_specification.md # Verification plan specification
│       ├── coverage_waiver_matrix.md # Architectural coverage waiver justifications
│       └── vplan_matrix.xlsx      # Feature traceability matrix
├── DESIGN/                        # Hardware design sources & reference models
│   ├── model/                     # Reference models
│   │   ├── cpp/                   # Bit-accurate C++ DIF FFT model & Makefile
│   │   └── matlab/                # Algorithmic MATLAB models & test vector generator
│   ├── scripts/                   # Hardware generation scripts (generate_twiddles.py)
│   └── RTL/                       # Synthesizable SystemVerilog RTL
│       ├── top_wrapper.sv         # Top-level AHB-Lite subsystem
│       ├── ASYC_FIFO/             # Asynchronous dual-clock FIFOs
│       ├── CTRL/                  # Central subsystem control FSM
│       ├── FFT_CORE/              # Parameterized R2SDF FFT Core (fft_top.sv, stages, ROM)
│       ├── REG_FILE/              # Memory-mapped register file (fft_rf.sv)
│       └── SLAVE/                 # Zero-wait-state AHB-Lite slave interface
├── FPGA/                          # Vivado synthesis, implementation & constraints
│   ├── add_files.tcl
│   ├── run_script.tcl
│   └── constraints/               # XDC constraint files
└── VERIFICATION/                  # Master verification environment
    ├── README.md                  # Comprehensive verification guide
    ├── Questa_SIM/                # Simulation run scripts, filelists, and waveforms
    ├── TB/                        # Legacy direct module testbenches
    └── UVM/                       # IEEE 1800.2 UVM 1.2 Verification Suite
        ├── fft_top_uvm.sv         # UVM top-level testbench
        ├── agents/                # AHB & Sideband UVCs
        ├── dpi/                   # C++ DPI-C foreign function imports
        ├── reg/                   # UVM Register Abstraction Layer (RAL)
        ├── env/                   # Scoreboard, coverage, virtual sequencer, env
        ├── seqs/                  # 8 Virtual Sequences & scenario config
        └── tests/                 # 9 UVM Test implementations
```

---

## 8. References & Documentation Links
* **Master Verification Guide**: [`VERIFICATION/README.md`]
* **Verification Plan Specification**: [`Docs/Vplan/vplan_specification.md`]
* **Coverage Waiver Matrix**: [`Docs/Vplan/coverage_waiver_matrix.md`]
* **Pipelined Core Design Document**: [`Docs/fft_r2sdf_design.md`]