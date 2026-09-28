# 32-Point Radix-2 DIF Pipelined FFT (R2SDF)

A high-performance, area-optimized **32-point Fast Fourier Transform (FFT)** hardware IP core designed for **RTL-to-GDS** ASIC and FPGA implementation flows.

---

## 1. Architectural Highlights

* **Algorithm**: Radix-2 Decimation-in-Frequency (DIF).
* **Architecture**: Single-Path Delay Feedback (R2SDF) pipelined streaming.
* **Hardware Allocation**: **5 Stages with 5 Butterfly Processing Elements** (1 butterfly PE per stage).
* **Throughput**: **1 sample per clock cycle** sustained continuous throughput.
* **Latency**: Initial pipeline fill latency of **31 clock cycles** ($N - 1$).
* **Data Format**: **16-bit signed fixed-point (Q1.15)** for both real and imaginary components.
* **Scaling Strategy**: **Stage Scaling** (divide-by-2 per stage, `>>> 1`), yielding an overall scale factor of $1/32 = 1/N$ (computes the normalized forward DFT).
* **Output Ordering**: Streaming frequency bins in bit-reversed order ($k_{\text{natural}} = \text{bitrev}_5(k_{\text{stream}})$).

---

## 2. Core Interface & Pinout

The core uses a streamlined, continuous streaming interface without extraneous framing signals:

```
                  ┌─────────────────────────────────────────┐
                  │                fft32_top                │
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

### Timing & Handshaking:
* **Frame Size**: 32 complex samples per FFT frame ($x[0], x[1], \dots, x[31]$).
* **Latency**: Exactly **31 clock cycles** from the arrival of the first valid input sample ($x[0]$) until `valid_out` asserts and the first frequency bin emerges.
* **Back-to-Back Frames**: The core supports 100% duty-cycle streaming; frame $M+1$ can stream immediately after frame $M$ with zero dead cycles.

---

## 3. Why Radix-2 DIF over DIT?

In a pipelined streaming architecture, **Decimation-in-Frequency (DIF)** provides massive silicon savings over Decimation-in-Time (DIT):

1. **Zero Input Buffering**:
   * **DIF** operates on **natural input order** ($x[0], x[1], \dots, x[31]$). Incoming samples stream directly into Stage 1 with zero upfront reordering memory.
   * **DIT** requires bit-reversed inputs. Receiving natural streaming data with DIT requires an upfront 32-sample ping-pong buffer (**64 complex registers and 32 cycles of latency**).
2. **Shift-Before-Multiply Precision**:
   * In DIF, the butterfly addition and subtraction come *before* twiddle multiplication:
     $$\text{Sum} = A + B, \quad \text{Diff} = (A - B) \cdot W$$
   * Applying the stage scaling ($/2$) on $(A - B)$ *before* feeding the complex multiplier keeps multiplier inputs strictly 16-bit without word-width growth.
3. **Multiplier Noise Reduction**:
   * The sum path ($A + B$) bypasses the multiplier entirely, meaning 50% of intermediate values never suffer multiplier quantization noise.

---

## 4. Stage Breakdown & Multiplier Budget

Across the 5 stages, twiddle multiplications simplify progressively:

| Stage | Delay Depth ($D$) | Twiddle Factor ($W$) | Multiplier Hardware Required |
| :---: | :---: | :---: | :--- |
| **Stage 1** | 16 | $W_{32}^k \ (k=0 \dots 15)$ | **1 Complex Multiplier** ($16 \times 16$, bypass for $k=0, 8$) |
| **Stage 2** | 8 | $W_{16}^k \ (k=0 \dots 7)$ | **1 Complex Multiplier** ($16 \times 16$, bypass for $k=0, 4$) |
| **Stage 3** | 4 | $W_8^k \ (k=0 \dots 3)$ | **1 Complex Multiplier** ($16 \times 16$) |
| **Stage 4** | 2 | $W_4^k \in \{1, -j\}$ | **Zero Multipliers** (2:1 Swap & Negate MUX) |
| **Stage 5** | 1 | $W_2^0 = 1$ | **Zero Multipliers** (Direct wire pass-through) |

* **Total Butterfly Units**: 5
* **Total Complex Multipliers**: **Only 3** (Stages 4 & 5 are multiplier-free)
* **Total Delay Memory**: $16 + 8 + 4 + 2 + 1 = \mathbf{31}$ **complex words**

---

## 5. Fixed-Point Arithmetic ($Q1.15$)

### 5.1 Number Representation
Data and twiddle factors are represented in **$Q1.15$ format**:
* $1$ Sign bit + $15$ Fractional bits.
* Normalized range: $[-1.0, +1.0 - 2^{-15}] \equiv [-32768, +32767]$.
* Resolution: $\Delta = 2^{-15} \approx 3.05 \times 10^{-5}$ ($98\text{ dB}$ theoretical dynamic range).

### 5.2 Arithmetic Rules:
1. **Stage Scaling (Divide-by-2)**:
   * To prevent bit growth across stages, every butterfly divides its outputs by 2 using an arithmetic right-shift (`>>> 1`).
   * Over 5 stages, total scaling is $(1/2)^5 = 1/32$, perfectly matching the normalized forward DFT equation.
2. **Round-Half-Up Rounding**:
   * Discarding bits via simple truncation introduces a negative DC bias. We add $+1$ to the bit being discarded prior to shifting:
     $$\text{Val}_{\text{rounded}} = (\text{Sum} + 1) \gg 1$$
3. **Saturation Logic**:
   * Clamps the two's complement boundary condition $-1.0 - 1.0 = -2.0$ to `0x8000` ($-32768$), eliminating catastrophic sign wrap-around.

