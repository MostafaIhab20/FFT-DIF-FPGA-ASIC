# FFT-DIF-FPGA-ASIC: Parameterized Radix-2 DIF Pipelined FFT Core

A high-performance, area-optimized, **fully parameterized Fast Fourier Transform (FFT)** hardware IP core supporting arbitrary power-of-2 point sizes ($N \in \{8, 16, 32, 64, 128, 512, 1024, \dots\}$), verified over **$N=32$** and **$N=64$**, and targeted for both **RTL-to-GDS (ASIC)** and **FPGA (Vivado DSP48)** implementation flows.

---

## 1. Architectural Highlights

* **Algorithm**: Radix-2 Decimation-in-Frequency (DIF).
* **Architecture**: Single-Path Delay Feedback (R2SDF) continuous streaming pipeline.
* **Fully Parameterized**: Top-level core `fft_top #(parameter int N = 32)` dynamically constructs $S = \log_2(N)$ stages via clean SystemVerilog `generate for` loops.
* **Hardware Allocation for Arbitrary $N$**:
  * **$S = \log_2(N)$ Butterfly Processing Elements** (1 butterfly PE per stage).
  * **Only $S - 2$ Complex Multipliers** (the penultimate stage uses a zero-multiplier swap/negate mux; the final stage is direct wire pass-through).
  * **$N - 1$ Complex Delay Registers** ($\sum_{s=0}^{S-1} 2^{S-1-s} = N - 1$).
* **Throughput**: **1 complex sample per clock cycle** sustained continuous streaming (100% duty cycle).
* **Pipeline Latency**: Exactly **$N - 1$ clock cycles** from the first valid input sample to `valid_out` assertion.
* **Data Format**: **16-bit signed fixed-point (Q1.15)** for both real and imaginary channels.
* **Scaling Strategy**: Stage-by-stage divide-by-2 scaling (`>>> 1` with Round-Half-Up and saturation clamps), yielding an exact overall scale factor of $(1/2)^S = 1/N$ (computes the normalized forward DFT with zero bit growth).
* **Output Ordering**: Frequency bins stream out in standard hardware bit-reversed order ($k_{\text{natural}} = \text{bitrev}_S(k_{\text{stream}})$).

For a detailed block-level breakdown of the RTL modules and pipeline data paths, see **[`DESIGN/RTL/README.md`](file:///c:/MY_PROJETS/RTL2GDS_FFT32/FFT-DIF-FPGA-ASIC/DESIGN/RTL/README.md)**.

---

## 2. Core Interface & Pinout

The core uses a streamlined, continuous streaming interface without extraneous framing signals:

```
                  ┌─────────────────────────────────────────┐
                  │          fft_top #(parameter N)         │
      clk ───────▶│                                         │──────▶ valid_out
    rst_n ───────▶│                                         │
                  │                                         │
 valid_in ───────▶│                                         │
in_data_re [15:0]▶│                                         │──────▶ out_data_re [15:0]
in_data_im [15:0]▶│                                         │──────▶ out_data_im [15:0]
                  └─────────────────────────────────────────┘
```

### Signal Descriptions:

| Port | Direction | Width | Description |
| :--- | :---: | :---: | :--- |
| `clk` | Input | 1 | Master system clock. |
| `rst_n` | Input | 1 | Active-low synchronous / asynchronous reset. |
| `valid_in` | Input | 1 | Asserted high when incoming complex sample is valid. |
| `in_data_re` | Input | 16 | Real part of input sample ($Q1.15$ signed format). |
| `in_data_im` | Input | 16 | Imaginary part of input sample ($Q1.15$ signed format). |
| `valid_out` | Output | 1 | Asserted high when output complex frequency bin is valid. |
| `out_data_re` | Output | 16 | Real part of output frequency bin ($Q1.15$ signed format). |
| `out_data_im` | Output | 16 | Imaginary part of output frequency bin ($Q1.15$ signed format). |

### Top-Level Module:
* **`fft_top.sv`**: Fully parameterized core `fft_top #(parameter int N = 32)`. Direct streaming interface supporting arbitrary power-of-2 point sizes.

---

## 3. Parameterized Hardware Scaling

For any arbitrary power-of-2 FFT point size $N = 2^S$:

| Configuration | Stages ($S$) | Delay Registers ($N-1$) | Complex Multipliers ($S-2$) | Multiplier Stages | Penultimate Stage ($W_4$) | Final Stage ($W_2$) | Latency |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **$N = 16$** | 4 | 15 | **2** | Stages 0, 1 | Stage 2 ($D=2$) | Stage 3 ($D=1$) | 15 cycles |
| **$N = 32$** | 5 | 31 | **3** | Stages 0, 1, 2 | Stage 3 ($D=2$) | Stage 4 ($D=1$) | 31 cycles |
| **$N = 64$** | 6 | 63 | **4** | Stages 0, 1, 2, 3 | Stage 4 ($D=2$) | Stage 5 ($D=1$) | 63 cycles |
| **$N = 128$** | 7 | 127 | **5** | Stages 0..4 | Stage 5 ($D=2$) | Stage 6 ($D=1$) | 127 cycles |
| **$N = 512$** | 9 | 511 | **7** | Stages 0..6 | Stage 7 ($D=2$) | Stage 8 ($D=1$) | 511 cycles |
| **$N = 1024$**| 10| 1023| **8** | Stages 0..7 | Stage 8 ($D=2$) | Stage 9 ($D=1$) | 1023 cycles|

---

## 4. How to Generate Twiddles & Test Vectors

### 4.1 Generate Twiddle Factor ROM (`scripts/generate_twiddles.py`)
Generates a standalone, synthesizable SystemVerilog module (`DESIGN/RTL/twiddle_rom.sv`) with combinational `case` statements for the exact specified $N$. No external `.mem` files, zero dead code:

```bash
# Generate twiddle ROM for 32-point FFT:
python scripts/generate_twiddles.py -N 32

# Generate twiddle ROM for 64-point FFT:
python scripts/generate_twiddles.py -N 64

# Generate twiddle ROM for arbitrary N (e.g. 512):
python scripts/generate_twiddles.py -N 512
```

### 4.2 Generate Bit-Accurate Test Vectors in MATLAB (`model/generate_test_vectors.m`)
MATLAB serves as the single source of truth (SSOT) for the algorithmic golden model and test vector generation. It generates 100 continuous frames of stimulus and bit-exact golden references across 8 comprehensive signal scenarios (pure tones, multi-tone, impulses, square waves, DC/ramps, full-scale dynamic range, low-amplitude quantization floor, and Gaussian noise):

Inside MATLAB console:
```matlab
cd model

% Generate test vectors for N = 32 (100 frames = 3,200 samples):
generate_test_vectors(100, 32);

% Generate test vectors for N = 64 (100 frames = 6,400 samples):
generate_test_vectors(100, 64);

% Generate for arbitrary N (e.g. N = 512):
generate_test_vectors(100, 512);
```

Or from terminal / CLI batch mode:
```bash
matlab -batch "cd model; generate_test_vectors(100, 32);"
```

---

## 5. How to Run Simulation (Single TB, Single Script)

The repository provides a single, unified, parameterized testbench (**`DESIGN/TB/fft_TB.sv`**) and a single master simulation script (**`Questa_SIM/run.do`**).

### Quickstart inside QuestaSim:

1. Launch QuestaSim / ModelSim.
2. In the QuestaSim console, run:

```tcl
# Navigate to simulation directory:
cd Questa_SIM

# To test 32-point FFT (default):
do run.do 32

# To test 64-point FFT:
do run.do 64

# To test any N-point FFT:
do run.do <N>
```

### Batch Mode Command-Line Execution:

From a system terminal (PowerShell, Bash, or Command Prompt):

```bash
# 1. Generate Twiddle ROM for target N:
python scripts/generate_twiddles.py -N 32

# 2. Run QuestaSim in batch mode:
cd Questa_SIM
vsim -c -do "do run.do 32"
```

```bash
# To switch to 64-point:
python scripts/generate_twiddles.py -N 64
cd Questa_SIM
vsim -c -do "do run.do 64"
```

---

## 6. Verification Results Summary

Both $N=32$ and $N=64$ configurations were simulated and verified in QuestaSim 2021.1:

| Metric | 32-Point Run (`do run.do 32`) | 64-Point Run (`do run.do 64`) | Status |
| :--- | :---: | :---: | :---: |
| **Tested Frames** | 100 frames | 100 frames | **PASS** |
| **Total Samples** | 3,200 complex samples | 6,400 complex samples | **PASS** |
| **Pipeline Latency** | **31 clock cycles** (Expected: 31) | **63 clock cycles** (Expected: 63) | **PASS** |
| **Max Abs Diff (Re)** | **0 LSB** | **0 LSB** | **PASS (100% Bit-Accurate)** |
| **Max Abs Diff (Im)** | **0 LSB** | **0 LSB** | **PASS (100% Bit-Accurate)** |
| **Compilation Warnings** | **0 Warnings** | **0 Warnings** | **PASS** |
| **Errors** | **0 Errors** | **0 Errors** | **PASS** |
| **Final Verdict** | **ALL 100 FRAMES PASSED** | **ALL 100 FRAMES PASSED** | **PASS** |

---

## 7. Dual-Target Architecture (ASIC vs. FPGA)

The codebase supports seamless targeting of both **ASIC (RTL-to-GDS)** and **FPGA (Vivado)** flows via the `TARGET_FPGA` configuration flag in `fft_pkg.sv`:

| Target Flow | Multiplier Implementation | Adder/Subtractor Implementation | How to Select |
| :--- | :--- | :--- | :--- |
| **ASIC (`TARGET_FPGA = 0`)** *(Default)* | Custom **Radix-4 Modified Booth Multipliers** with two-level 4:2 compressor trees and Brent-Kung final adders. | Parameterized **Brent-Kung Parallel-Prefix Adders** (`adder_subtractor_bk.sv`) with bounded fan-out ($\le 2$). | Default mode (no compile flags needed). |
| **FPGA (`TARGET_FPGA = 1`)** | Inferred **Hard DSP48 Slices** via `(* use_dsp = "yes" *)` with zero LUT waste. | Inferred **Hard Vertical Carry Chains** (`CARRY4` / `CARRY8`) for minimal slice utilization. | Compile with `+define+TARGET_FPGA` or `-verilog_define TARGET_FPGA`. |
