// =============================================================================
// File Name      : fft_top.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-09-28
// Version        : 1.1
// Description    : Parameterized Top-level Core for N-Point Radix-2 Decimation-in-Frequency (DIF)
//                  Single-Path Delay Feedback (R2SDF) FFT.
//                  Supports arbitrary power-of-2 N (e.g., 8, 16, 32, 64, 128, ...).
//                  Key Characteristics:
//                    - Arithmetic: 16-bit Signed Fixed-Point Q1.15
//                    - Scaling   : Divide-by-2 per stage (total 1/N scaling, 0 bit growth)
//                    - Throughput: 1 complex sample / clock continuous streaming (100% duty)
//                    - Latency   : Exactly N - 1 clock cycles from first sample to valid_out
//                    - Resources : log2(N) Butterfly PEs, log2(N)-2 Complex Multipliers, N-1 Delay Regs
//                    - Output    : Bit-reversed frequency bins (hardware standard DIF)
// =============================================================================

import fft_pkg::*;

module fft_top #(
    parameter int N = 32
)(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    valid_in,
    input  logic signed [15:0]      in_data_re,
    input  logic signed [15:0]      in_data_im,
    output logic                    valid_out,
    output logic signed [15:0]      out_data_re,
    output logic signed [15:0]      out_data_im
);

    localparam int NUM_STAGES    = $clog2(N);
    localparam int TW_ADDR_WIDTH = (N <= 4) ? 1 : (NUM_STAGES - 1);

    // Pack Top Input into complex_t
    complex_t core_in;
    assign core_in.re = (valid_in) ? in_data_re : 16'sh0000;
    assign core_in.im = (valid_in) ? in_data_im : 16'sh0000;

    // Controller Interconnects
    logic                                            core_en;
    logic [NUM_STAGES-1:0]                           stage_sel;
    logic [NUM_STAGES-1:0][TW_ADDR_WIDTH-1:0]        stage_tw_addr;

    // Inter-Stage Data Signals
    complex_t stage_data [0:NUM_STAGES];
    assign stage_data[0] = core_in;

    // =====================================================================
    // Central Timing & Synchronization Controller
    // =====================================================================
    fft_controller #(
        .N (N)
    ) u_controller (
        .clk           (clk),
        .rst_n         (rst_n),
        .valid_in      (valid_in),
        .stage_sel     (stage_sel),
        .stage_tw_addr (stage_tw_addr),
        .core_en       (core_en),
        .valid_out     (valid_out)
    );

    // =====================================================================
    // Parameterized Pipeline Stages (Single-Path Delay Feedback)
    // =====================================================================
    generate
        for (genvar s = 0; s < NUM_STAGES; s++) begin : gen_stages
            localparam int DELAY_DEPTH   = N / (2**(s + 1));
            localparam int HAS_MULT      = (s < NUM_STAGES - 2) ? 1 : 0;
            localparam int IS_TRIVIAL    = (s == NUM_STAGES - 2) ? 1 : 0;

            fft_stage #(
                .N                (N),
                .DELAY_DEPTH      (DELAY_DEPTH),
                .TW_ADDR_WIDTH    (TW_ADDR_WIDTH),
                .HAS_MULTIPLIER   (HAS_MULT),
                .IS_STAGE_TRIVIAL (IS_TRIVIAL)
            ) u_stage (
                .clk       (clk),
                .rst_n     (rst_n),
                .en        (core_en),
                .sel       (stage_sel[s]),
                .tw_addr   (stage_tw_addr[s]),
                .stage_in  (stage_data[s]),
                .stage_out (stage_data[s+1])
            );
        end
    endgenerate

    // Unpack Top Output from complex_t
    assign out_data_re = stage_data[NUM_STAGES].re;
    assign out_data_im = stage_data[NUM_STAGES].im;

endmodule : fft_top
