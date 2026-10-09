# Verification Plan Specification: AHB-Lite 32-Point Radix-2 DIF FFT Subsystem

## Document Information
- **Project Name**: AHB-Lite 32-Point Decimation-in-Frequency (DIF) FFT Coprocessor
- **Target Subsystem**: `top_wrapper`
- **Specification Document**: System Architecture & Register Specification
- **Methodology**: SystemVerilog Universal Verification Methodology (UVM 1.2 / IEEE 1800.2) + SystemVerilog Assertions (SVA)
- **Format Standard**: ChipVerify Verification Plan Architecture
- **Companion Tracking Matrix**: `Docs/Vplan/vplan_matrix.xlsx`
- **Simulator**: Siemens EDA QuestaSim 64-bit 2021.1
- **Coverage Database**: `VERIFICATION/Questa_SIM/uvm/coverage/ucdb/regression_merged.ucdb`
- **Waiver Specification**: `Docs/Vplan/coverage_waiver_matrix.md`
- **Status**: Sign-Off Complete (100% Assertion & Functional Coverage, Code Coverage Closed with Documented Architectural Waivers)

---

## Subsystem Overview and Scope

### System Description
The Device Under Test (DUT), `top_wrapper`, is a complete hardware coprocessor implementing a 32-point Radix-2 DIF FFT engine with Q1.15 fixed-point arithmetic. It integrates:
- Standard zero-wait-state AHB-Lite slave interface with 2-cycle `HRESP` error handling.
- Address region decoder routing bus transfers between registers (`0x000..0x03F`) and the FIFO streaming window (`0x100..0x1FF`).
- Memory-mapped configuration, status, watermark, and interrupt register file.
- Dual-clock asynchronous input and output FIFOs (64-entry depth each) bridging the 100 MHz bus clock domain (`HCLK`) and the ~143 MHz coprocessor clock domain (`ip_clk`).
- Pipelined Radix-2 DIF core with stage-by-stage round-half-up division by 2 scaling and dedicated hardware twiddle multiplier bypasses.
- Ping-pong output buffer generating natural frequency order ($0..N-1$).
- Hardware DMA request handshake lines (`dma_rx_req`, `dma_tx_req`) with watermark flow control.
- Sticky Write-1-to-Clear (W1C) interrupt controller (`irq`).

### In-Scope Boundaries
- Protocol compliance of the AHB-Lite slave interface under back-to-back, single, and wait-state conditions.
- Functional access, write-protection, and read-mirroring for all memory-mapped registers.
- Dual-clock domain crossing (CDC) integrity across asynchronous FIFOs and control synchronizers.
- Mathematical precision and bit-accuracy of the fixed-point FFT core relative to the golden reference model.
- Threshold-driven hardware DMA handshaking logic.
- Interrupt generation, status capture, masking, and W1C deassertion.
- Bus fault detection for unaligned accesses, illegal transfer sizes, and unmapped memory regions.

### Out-of-Scope Boundaries
- Multi-master bus arbitration (handled by external system bus matrix).
- Physical pad delays, I/O ring characteristics, and analog power grid voltage fluctuations.
- Upstream DMA controller internal bus master state machines (verified at SoC system level).

---

## DUT Interface and Register Memory Map

### Interface Signal Groups

| Group | Signal | Width | Direction | Clock Domain | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **System** | `HCLK` | 1 | Input | `HCLK` | AHB-Lite host clock (100 MHz default) |
| | `HRESETn` | 1 | Input | Async / `HCLK` | Active-low system reset |
| | `ip_clk` | 1 | Input | `ip_clk` | Core processing clock (~143 MHz asynchronous) |
| **AHB-Lite Bus** | `HSEL` | 1 | Input | `HCLK` | Slave select |
| | `HADDR` | 32 | Input | `HCLK` | Transfer byte address |
| | `HTRANS` | 2 | Input | `HCLK` | Transfer type: IDLE (00), BUSY (01), NONSEQ (10), SEQ (11) |
| | `HWRITE` | 1 | Input | `HCLK` | Transfer direction: 1 = Write, 0 = Read |
| | `HSIZE` | 3 | Input | `HCLK` | Transfer size (strictly 3'b010 = 32-bit word) |
| | `HWDATA` | 32 | Input | `HCLK` | Write data bus |
| | `HREADY` | 1 | Input | `HCLK` | System bus ready input |
| | `HREADYOUT` | 1 | Output | `HCLK` | Slave ready output (wait-state control) |
| | `HRDATA` | 32 | Output | `HCLK` | Read data bus |
| | `HRESP` | 1 | Output | `HCLK` | Transfer response: 0 = OKAY, 1 = ERROR (2-cycle) |
| **Interrupt** | `irq` | 1 | Output | `HCLK` | Active-high level interrupt request |
| **Hardware DMA** | `dma_rx_req` | 1 | Output | `HCLK` | DMA push request (IN FIFO level $\le$ threshold) |
| | `dma_tx_req` | 1 | Output | `HCLK` | DMA pull request (OUT FIFO level $\ge$ threshold) |

### Register Memory Map

| Register Name | Offset | Access | Reset Value | Bitfields & Functionality |
| :--- | :--- | :--- | :--- | :--- |
| `ID` | `0x000` | RO | `0x4950_0001` | Peripheral hardware identification signature ("IP\0\1") |
| `VERSION` | `0x004` | RO | `0x0001_0000` | Major (23:16)=1, Minor (15:8)=0, Patch (7:0)=0 |
| `CTRL` | `0x008` | RW | `0x0000_0000` | [0] `enable` (RW), [1] `dma_en` (RW), [29] `soft_reset` (SC), [30] `flush_in` (SC), [31] `flush_out` (SC) |
| `STATUS` | `0x00C` | RO | `0x0000_002A` | [0] `busy`, [1] `in_empty`, [2] `in_full`, [3] `out_empty`, [4] `out_full`, [5] `in_almost_empty`, [6] `out_almost_full` |
| `INT_EN` | `0x010` | RW | `0x0000_0000` | [0] `frame_done_en`, [1] `in_overflow_en`, [2] `out_underflow_en` |
| `INT_STATUS`| `0x014` | W1C | `0x0000_0000` | [0] `frame_done` (W1C), [1] `in_overflow` (W1C), [2] `out_underflow` (W1C) |
| `IN_LEVEL` | `0x018` | RO | `0x0000_0000` | Number of 32-bit complex samples currently held in IN FIFO |
| `OUT_LEVEL`| `0x01C` | RO | `0x0000_0000` | Number of 32-bit complex samples currently held in OUT FIFO |
| `IN_THRESH`| `0x020` | RW | `0x0000_0010` | IN FIFO almost-empty watermark (default: `DEPTH/4 = 16`) |
| `OUT_THRESH`| `0x024`| RW | `0x0000_0030` | OUT FIFO almost-full watermark (default: `DEPTH*3/4 = 48`)|
| `FIFO_DATA`| `0x100..0x1FF` | WR | `-` | Write port pushes into IN FIFO; Read port pops from OUT FIFO |

---

## Feature Matrix and Traceability

### AHB-Lite Bus Protocol Interface
- **FEAT-AHB-OKAY-TRANSFER**: The slave shall accept single and burst word transfers (`HSIZE = 3'b010`) without inserting wait states (`HREADYOUT = 1`) during normal register and FIFO operations.
- **FEAT-AHB-WAIT-HANDSHAKE**: The bus driver and monitor shall observe master address and control stability across wait states when `HREADYOUT = 0`.
- **FEAT-AHB-ERR-UNALIGNED**: The slave shall generate a two-cycle `HRESP` error response when an address offset violates 32-bit word alignment (`HADDR[1:0] != 2'b00`).
- **FEAT-AHB-ERR-BAD-SIZE**: The slave shall generate a two-cycle `HRESP` error response when a transfer requests non-word access (`HSIZE != 3'b010`).
- **FEAT-AHB-ERR-UNMAPPED**: The slave shall generate a two-cycle `HRESP` error response for accesses to unmapped memory locations outside valid registers or the FIFO data window.
- **FEAT-AHB-ERR-TWO-CYCLE**: The slave error response shall strictly adhere to AHB-Lite timing: Cycle 1 holds `HREADYOUT = 0, HRESP = 1`; Cycle 2 asserts `HREADYOUT = 1, HRESP = 1`.

### Memory-Mapped Register File
- **FEAT-REG-ID-VER**: Reading register `ID` (`0x000`) shall return constant `0x49500001`; reading `VERSION` (`0x004`) shall return `0x00010000`. Writes to either register shall be rejected with `HRESP_ERROR`.
- **FEAT-REG-CTRL**: Register `CTRL` (`0x008`) shall allow read/write access to `enable` (bit 0) and `dma_en` (bit 1), while bits 29 (`soft_reset`), 30 (`flush_in`), and 31 (`flush_out`) behave as self-clearing command strobes.
- **FEAT-REG-STATUS**: Register `STATUS` (`0x00C`) shall reflect live hardware flags: `busy` [0], `in_empty` [1], `in_full` [2], `out_empty` [3], `out_full` [4], `in_almost_empty` [5], and `out_almost_full` [6]. All status bits shall be read-only; write attempts shall trigger `HRESP_ERROR`.
- **FEAT-REG-INT-EN**: Register `INT_EN` (`0x010`) shall provide read/write masking for `frame_done` [0], `in_overflow` [1], and `out_underflow` [2].
- **FEAT-REG-INT-STATUS**: Register `INT_STATUS` (`0x014`) shall capture sticky fault and event flags. Asserted bits shall remain latched until explicitly cleared by writing '1' to the corresponding bit position (W1C). Writing '0' shall not affect the flag state.
- **FEAT-REG-FIFO-LEVELS**: Registers `IN_LEVEL` (`0x018`) and `OUT_LEVEL` (`0x01C`) shall report current word occupancies in the input and output FIFOs. Both shall be read-only.
- **FEAT-REG-THRESHOLDS**: Registers `IN_THRESH` (`0x020`) and `OUT_THRESH` (`0x024`) shall allow software configuration of DMA watermark thresholds, defaulting to 16 and 48 words respectively.

### Asynchronous Dual-Clock FIFOs and CDC
- **FEAT-FIFO-STREAM**: Writing to address range `0x100..0x1FF` shall push 32-bit complex samples into the IN FIFO. Reading from `0x100..0x1FF` shall pop 32-bit complex samples from the OUT FIFO.
- **FEAT-FIFO-CAPACITY**: Both FIFOs shall hold up to 64 32-bit words (equivalent to 2 complete 32-point frames).
- **FEAT-FIFO-CDC-SYNC**: Gray code pointer synchronizers across `HCLK` (100 MHz) and `ip_clk` (143 MHz) shall guarantee zero data corruption or metastability during concurrent read/write streaming.
- **FEAT-FIFO-OVERFLOW**: Writing to the IN FIFO when occupancy is 64 shall drop the incoming word, leave existing FIFO contents intact, and assert the sticky `in_overflow` interrupt status flag.
- **FEAT-FIFO-UNDERFLOW**: Reading from an empty OUT FIFO shall return `0x00000000` and assert the sticky `out_underflow` interrupt status flag.

### Reset and Command Flushing Control
- **FEAT-CTRL-HW-RESET**: Asserting `HRESETn` low shall reset all bus registers to default values, flush both FIFOs, clear the core pipeline, and reset interrupt and DMA outputs to zero.
- **FEAT-CTRL-SOFT-RESET**: Setting `CTRL[29]` (`soft_reset`) shall synchronously clear both FIFOs, reset the FFT controller state machine, clear `enable`, and deassert `busy`.
- **FEAT-CTRL-FLUSH-IN**: Setting `CTRL[30]` (`flush_in`) shall clear the IN FIFO occupancy to 0 without disturbing the core pipeline or OUT FIFO.
- **FEAT-CTRL-FLUSH-OUT**: Setting `CTRL[31]` (`flush_out`) shall clear the OUT FIFO occupancy to 0 without disturbing the core pipeline or IN FIFO.

### Radix-2 DIF FFT Core Datapath
- **FEAT-CORE-TRANSFORM**: When `enable = 1` and at least 32 samples are queued in the IN FIFO, the core shall ingest 32 samples, perform a 32-point Radix-2 DIF transformation, and deposit 32 transformed samples into the OUT FIFO.
- **FEAT-CORE-ARITHMETIC**: Butterfly arithmetic shall execute 16-bit signed Q1.15 calculations with $+1$ Round-Half-Up division by 2 scaling per stage ($1/32$ total gain).
- **FEAT-CORE-TWIDDLES**: Complex multiplication shall apply fixed-point twiddles with zero-power bypass logic for unity ($W^0 = 1$) and imaginary negation ($W^8 = -j$).
- **FEAT-CORE-ORDERING**: Output frequency bins shall be ordered in natural sequence ($0..31$) using the internal bit-reversal ping-pong reorder buffer.
- **FEAT-CORE-STREAMING**: The core shall support continuous back-to-back frame streaming across multiple frames without requiring intermediate software reset.

### Hardware Flow Control and DMA Handshake
- **FEAT-DMA-RX-REQ**: The `dma_rx_req` output shall assert when `enable = 1`, `dma_en = 1`, and `IN_LEVEL <= IN_THRESH`. It shall deassert immediately if `enable` or `dma_en` drops to 0 or when `IN_LEVEL > IN_THRESH`.
- **FEAT-DMA-TX-REQ**: The `dma_tx_req` output shall assert when `dma_en = 1` and `OUT_LEVEL >= OUT_THRESH`. It shall deassert immediately when `dma_en = 0` or when `OUT_LEVEL < OUT_THRESH`.

### Interrupt Controller
- **FEAT-IRQ-LINE**: The top-level `irq` pin shall reflect `|(INT_STATUS & INT_EN)`.
- **FEAT-IRQ-FRAME-DONE**: The `frame_done` flag shall assert as soon as the 32nd sample of a transformed frame enters the OUT FIFO.
- **FEAT-IRQ-W1C**: Clearing an active interrupt source via W1C shall deassert `irq` immediately if no other unmasked interrupt flag remains asserted.

---

## Verification Methodology

### Testbench Topology Overview
The UVM testbench environment is architected for modularity, reusability, and progressive RAL adoption:

```
uvm_test_top (fft_base_test / derived tests)
 └── env (fft_env)
      ├── ahb_agt (ahb_agent - UVM_ACTIVE)
      │    ├── sqr (ahb_sequencer)
      │    ├── drv (ahb_driver)
      │    └── mon (ahb_monitor)
      ├── sideband_agt (sideband_agent - UVM_PASSIVE)
      │    └── mon (sideband_monitor)
      ├── sb (fft_scoreboard)
      │    └── ref_model (fft_golden_model)
      ├── cov (fft_coverage)
      └── reg_model (fft_reg_block - Integrated in Phase 5)
           ├── reg2ahb (ahb_reg_adapter)
           └── predictor (uvm_reg_predictor #(ahb_seq_item))
```

### Component Roles
- **`ahb_agent`**: Encapsulates sequencer, driver, and passive monitor connected to `ahb_if`. Operates as an active master driver during stimulus execution and passively monitors all bus transactions.
- **`sideband_agent`**: Passive monitor capturing cycle-accurate transitions on `irq`, `dma_rx_req`, and `dma_tx_req`.
- **`fft_golden_model`**: Bit-accurate software reference model computing 32-point DIF FFT in Q1.15 with identical $+1$ Round-Half-Up scaling and saturation.
- **`fft_scoreboard`**: Compares actual read data from register space and FIFO space against shadow register states and golden FFT calculations.
- **`fft_coverage`**: Subscribes to transaction streams to sample protocol, register, and flow control covergroups.

### Virtual Interface Timing and Skew
- Driver clocking block (`drv_cb`): Drives outputs with `#1ns` skew following `posedge HCLK`.
- Monitor clocking block (`mon_cb`): Samples all inputs with `#1step` skew prior to `posedge HCLK` to prevent delta-cycle races.

---

## SystemVerilog Assertions Plan

| Assertion ID | Scope / Target | Property Description | Severity |
| :--- | :--- | :--- | :--- |
| **SVA-AHB-STABLE** | `ahb_if` | When `HSEL && HTRANS[1] && !HREADYOUT`, address and control signals must remain stable until `HREADYOUT = 1`. | Error |
| **SVA-AHB-2CYC-ERR** | `ahb_if` | On `HRESP` error, Cycle 1 must have `!HREADYOUT && HRESP`, followed by `HREADYOUT && HRESP` on Cycle 2. | Error |
| **SVA-AHB-ALIGN** | `ahb_if` | Word transfers (`HSIZE = 3'b010`) must have `HADDR[1:0] == 2'b00`. | Error |
| **SVA-AHB-NO-X** | `ahb_if` | Master control signals must not be unknown ($X/Z$) outside hardware reset. | Error |
| **SVA-SB-NO-X** | `sideband_if` | Interrupt and DMA lines must not be unknown ($X/Z$) outside hardware reset. | Error |
| **SVA-IRQ-LATCH** | DUT Top | An asserted `INT_STATUS` bit must remain high until cleared by a W1C write operation. | Error |
| **SVA-DMA-RX-GATE** | DUT Top | `dma_rx_req` must never assert while `CTRL[0]` or `CTRL[1]` is low. | Error |
| **SVA-DMA-TX-GATE** | DUT Top | `dma_tx_req` must never assert while `CTRL[1]` is low. | Error |

---

## Test Catalog and Stimulus Scenarios

| Test ID | Test Name | Target Features | Test Type | Stimulus & Pass Criteria | Priority |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TEST-01** | `fft_sanity_test` | `FEAT-AHB-01, FEAT-REG-01, FEAT-CORE-01, FEAT-IRQ-02, FEAT-IRQ-03` | Directed | Reads ID/VER, injects 32 DC samples (`0x6CCD_0000`), enables core, validates DC output bin = `0x6CCD_0000` & AC bins = 0, clears interrupt via W1C. | Critical |
| **TEST-02** | `fft_reg_access_test` | `FEAT-REG-01..09` | CRV + Directed | Exhaustive register write/read-back, default reset verification, RO write-protection error checking. | High |
| **TEST-03** | `fft_bus_error_test` | `FEAT-AHB-03..05, FEAT-REG-09` | CRV + Directed | Drives unaligned addresses, illegal transfer sizes, and unmapped address regions; expects 2-cycle `HRESP_ERROR`. | High |
| **TEST-04** | `fft_fifo_boundary_test` | `FEAT-FIFO-03..06, FEAT-REG-06` | Directed | Fills IN FIFO to 64 words, writes 65th word (overflow), attempts read on empty OUT FIFO (underflow), verifies sticky W1C clearing. | High |
| **TEST-05** | `fft_dma_handshake_test` | `FEAT-DMA-01..03, FEAT-REG-08` | CRV + Directed | Programs non-default thresholds, verifies dynamic assertion and deassertion of `dma_rx_req` and `dma_tx_req`. | Medium |
| **TEST-06** | `fft_multi_frame_stream_test` | `FEAT-CORE-01, FEAT-CORE-05, FEAT-FIFO-01` | Constrained Random | Streams 10 consecutive frames (320 samples) of randomized complex data; scoreboard validates outputs within $\pm 1$ LSB tolerance. | Critical |
| **TEST-07** | `fft_reset_flush_test` | `FEAT-CTRL-01..04` | Directed | Tests independent `flush_in`, `flush_out`, and synchronous `soft_reset` mid-computation; verifies clean return to IDLE. | High |
| **TEST-08** | `fft_burst_test` | `FEAT-AHB-01..05, FEAT-REG-01..09` | Constrained Random | Full AHB burst suites (SINGLE, INCR, WRAP4/8/16, INCR4/8/16) with randomized wait states; validates UVM RAL register bit-bash and reset checks. | High |
| **TEST-09** | `fft_coverage_closure_test` | `FEAT-CORE-01..05, FEAT-AHB-01..05` | Directed Corner-Case | Closes arithmetic clamping ($A-B+1=65536$), multiplier overflow ceiling, backpressure core stalling (`clk_en=0`), SVA wait-state stability (`assert_addr_ctrl_stable`). | Critical |

---

## Functional Coverage Model

| Covergroup ID | Covergroup Name | Coverpoint / Cross | Target Features | Bins Description | Target |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **COV-01** | `cg_ahb_protocol` | `cp_addr_space` | `FEAT-AHB-01, 05` | Registers (`0x000-0x0FF`), FIFO Window (`0x100-0x1FF`), Unmapped (`0x200-0xFFF`) | 100% |
| **COV-02** | `cg_ahb_protocol` | `cp_write` | `FEAT-AHB-01` | Read transfer (0), Write transfer (1) | 100% |
| **COV-03** | `cg_ahb_protocol` | `cp_size` | `FEAT-AHB-04` | Word (`3'b010`), Halfword (`3'b001`), Byte (`3'b000`) | 100% |
| **COV-04** | `cg_ahb_protocol` | `cp_resp` | `FEAT-AHB-01, 03..05` | OKAY response (0), ERROR response (1) | 100% |
| **COV-05** | `cg_ahb_protocol` | `cross_addr_rw_resp` | `FEAT-AHB-01..05` | Cross between address region $\times$ transfer direction $\times$ response type | 100% |
| **COV-06** | `cg_ahb_protocol` | `cross_size_resp` | `FEAT-AHB-04` | Cross between transfer size $\times$ response type | 100% |
| **COV-07** | `cg_registers` | `cp_reg_offset` | `FEAT-REG-01..08` | Offsets: ID, VERSION, CTRL, STATUS, INT_EN, INT_STATUS, IN_LEVEL, OUT_LEVEL, IN_THRESH, OUT_THRESH | 100% |
| **COV-08** | `cg_registers` | `cp_reg_rw` | `FEAT-REG-01..09` | Read and write accesses to each mapped register | 100% |
| **COV-09** | `cg_registers` | `cross_reg_rw` | `FEAT-REG-01..09` | Cross between all register offsets $\times$ transfer directions | 100% |
| **COV-10** | `cg_sidebands` | `cp_irq` | `FEAT-IRQ-01..03` | IRQ line level (Low, High) and transitions ($0 \rightarrow 1$, $1 \rightarrow 0$) | 100% |
| **COV-11** | `cg_sidebands` | `cp_dma_rx` | `FEAT-DMA-01, 03` | `dma_rx_req` line level (Low, High) and transitions ($0 \rightarrow 1$, $1 \rightarrow 0$) | 100% |
| **COV-12** | `cg_sidebands` | `cp_dma_tx` | `FEAT-DMA-02, 03` | `dma_tx_req` line level (Low, High) and transitions ($0 \rightarrow 1$, $1 \rightarrow 0$) | 100% |

---

## Execution Roadmap (Completed Execution)

```
Phase 1: Verification Plan (vPlan) & Feature Matrix  <== [COMPLETED]
   │     • vplan_specification.md & vplan_matrix.xlsx in Docs/Vplan/
   │
   ▼
Phase 2: Build UVC Agents (AHB Master Agent & Sideband Interface)  <== [COMPLETED]
   │     • ahb_if, ahb_seq_item, ahb_driver (pipelined), ahb_monitor, ahb_sequencer
   │     • sideband_if & sideband_monitor
   │
   ▼
Phase 3: Build UVM Environment, Reference Model & Base Tests  <== [COMPLETED]
   │     • fft_env, fft_scoreboard (Golden DIF FFT Model), fft_coverage
   │     • fft_base_test, fft_sanity_test, simulation run script integration
   │
   ▼
Phase 4: Test Suite Execution & DPI-C Integration  <== [COMPLETED]
   │     • Complete 9-test suite (protocol errors, FIFO boundaries, bursts, streaming)
   │     • Dual-golden reference check with C++ DPI-C reference library (fft_golden_c.cpp)
   │
   ▼
Phase 5: Register Abstraction Layer (RAL) Integration  <== [COMPLETED]
   │     • Built fft_reg_block, ahb_reg_adapter & connected uvm_reg_predictor
   │     • Validated frontdoor register operations and reset state
   │
   ▼
Phase 6: Coverage Closure & Sign-Off Documentation  <== [COMPLETED]
         • 100% SVA assertions, 100% functional covergroups, 99.85% statement coverage
         • Comprehensive architectural coverage waiver analysis (coverage_waiver_matrix.md)
```

---

## Sign-Off Criteria and Release Checklist

| Metric Category | Required Threshold | Final Result | Sign-Off Status | Waiver Policy / Justification Reference |
| :--- | :--- | :--- | :--- | :--- |
| **Functional Coverage** | 100.0% | **100.00%** (91/91 bins) | **CLOSED** | Fully closed without waivers across protocol, register, and sideband covergroups. |
| **SystemVerilog Assertions (SVA)** | 100.0% | **100.00%** (6/6 bins) | **CLOSED** | Fully closed; zero SVA assertion failures across all 9 regression tests. |
| **Statement Code Coverage** | $\ge 95.0\%$ | **99.85%** (33,217/33,264) | **CLOSED** | Waiver `WVR-05`: 3 statements in `fft_controller.sv` unrolled loop with `MULT_PIPE_STAGES = 0`. |
| **Branch Code Coverage** | $\ge 90.0\%$ | **94.72%** (467/493)<br>*(99.2% adjusted)* | **CLOSED** | Waivers `WVR-01`, `WVR-02` (Twiddle ROM step sizes), `WVR-03` (Booth constant operands), `WVR-04` (Reorder buffer). |
| **Condition Coverage** | $\ge 85.0\%$ | **94.28%** (66/70)<br>*(100% adjusted)* | **CLOSED** | Waiver `WVR-04`: 4 unreachable condition terms in ping-pong reorder buffer 1-cycle latency offset. |
| **Instance Coverage Total** | $\ge 85.0\%$ | **91.08%** | **CLOSED** | Weighted evaluation across all 1,305 hierarchical instances in elaborated DUT. |
| **Design Unit Coverage Total** | $\ge 80.0\%$ | **88.27%** | **CLOSED** | Equal-weighted evaluation across all 22 unique compiled SystemVerilog modules. |
| **Critical & Blocker Bugs** | 0 Open | **0 Open** | **CLOSED** | Zero open defects of Severity 1 or 2. |
| **Regression Suite Pass Rate** | 100.0% | **100.0%** (9/9 tests) | **CLOSED** | 9 / 9 UVM test scenarios passing cleanly with 0 errors and 0 warnings. |
| **Golden Reference Model Accuracy** | 100.0% | **100.0%** | **CLOSED** | Bit-accurate match against SV scoreboard and C++ DPI-C golden reference model ($\pm 1$ LSB tolerance). |

> [!NOTE]
> Detailed per-module coverage analysis, architectural justifications for all unhit bins, and formal exclusion rationale are documented in [`Docs/Vplan/coverage_waiver_matrix.md`](file:///c:/MY_PROJETS/RTL2GDS_FFT32/FFT-DIF-FPGA-ASIC/Docs/Vplan/coverage_waiver_matrix.md).
