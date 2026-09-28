// =============================================================================
// File Name      : fft32_top.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-09-27
// Version        : 1.0
// Description    : Top-level ASIC core for 32-Point Radix-2 Decimation-in-Frequency (DIF)
//                  Single-Path Delay Feedback (R2SDF) FFT.
//                  Key Characteristics:
//                    - Arithmetic: 16-bit Signed Fixed-Point Q1.15
//                    - Scaling   : Divide-by-2 per stage (total 1/32 scaling, 0 bit growth)
//                    - Throughput: 1 complex sample / clock continuous streaming (100% duty)
//                    - Latency   : Exactly 31 clock cycles from first sample to valid_out
//                    - Resources : 5 Butterfly PEs, only 3 Complex Multipliers, 31 Delay Regs
//                    - Output    : Bit-reversed frequency bins (hardware standard DIF)
// =============================================================================

import fft32_pkg::*;

module fft32_top (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    valid_in,
    input  logic signed [15:0]      in_data_re,
    input  logic signed [15:0]      in_data_im,
    output logic                    valid_out,
    output logic signed [15:0]      out_data_re,
    output logic signed [15:0]      out_data_im
);

    // Pack Top Input into complex_t
    complex_t core_in;
    assign core_in.re = (valid_in) ? in_data_re : 16'sh0000;
    assign core_in.im = (valid_in) ? in_data_im : 16'sh0000;

    // Controller Interconnects
    logic       core_en;
    logic       stage1_sel;
    logic [3:0] stage1_tw_addr;
    logic       stage2_sel;
    logic [3:0] stage2_tw_addr;
    logic       stage3_sel;
    logic [3:0] stage3_tw_addr;
    logic       stage4_sel;
    logic [3:0] stage4_tw_addr;
    logic       stage5_sel;

    // Inter-Stage Data Signals
    complex_t stage1_out;
    complex_t stage2_out;
    complex_t stage3_out;
    complex_t stage4_out;
    complex_t stage5_out;

    // =====================================================================
    // Central Controller
    // =====================================================================
    fft_controller u_controller (
        .clk            (clk),
        .rst_n          (rst_n),
        .valid_in       (valid_in),
        .stage1_sel     (stage1_sel),
        .stage1_tw_addr (stage1_tw_addr),
        .stage2_sel     (stage2_sel),
        .stage2_tw_addr (stage2_tw_addr),
        .stage3_sel     (stage3_sel),
        .stage3_tw_addr (stage3_tw_addr),
        .stage4_sel     (stage4_sel),
        .stage4_tw_addr (stage4_tw_addr),
        .stage5_sel     (stage5_sel),
        .core_en        (core_en),
        .valid_out      (valid_out)
    );

    // =====================================================================
    // Stage 1 (Delay Depth = 16, Full Complex Multiplier)
    // =====================================================================
    fft_stage #(
        .DELAY_DEPTH    (16),
        .HAS_MULTIPLIER (1),
        .IS_STAGE4      (0)
    ) u_stage1 (
        .clk       (clk),
        .rst_n     (rst_n),
        .en        (core_en),
        .sel       (stage1_sel),
        .tw_addr   (stage1_tw_addr),
        .stage_in  (core_in),
        .stage_out (stage1_out)
    );

    // =====================================================================
    // Stage 2 (Delay Depth = 8, Full Complex Multiplier)
    // =====================================================================
    fft_stage #(
        .DELAY_DEPTH    (8),
        .HAS_MULTIPLIER (1),
        .IS_STAGE4      (0)
    ) u_stage2 (
        .clk       (clk),
        .rst_n     (rst_n),
        .en        (core_en),
        .sel       (stage2_sel),
        .tw_addr   (stage2_tw_addr),
        .stage_in  (stage1_out),
        .stage_out (stage2_out)
    );

    // =====================================================================
    // Stage 3 (Delay Depth = 4, Full Complex Multiplier)
    // =====================================================================
    fft_stage #(
        .DELAY_DEPTH    (4),
        .HAS_MULTIPLIER (1),
        .IS_STAGE4      (0)
    ) u_stage3 (
        .clk       (clk),
        .rst_n     (rst_n),
        .en        (core_en),
        .sel       (stage3_sel),
        .tw_addr   (stage3_tw_addr),
        .stage_in  (stage2_out),
        .stage_out (stage3_out)
    );

    // =====================================================================
    // Stage 4 (Delay Depth = 2, Trivial Swap & Negate Multiplexer)
    // =====================================================================
    fft_stage #(
        .DELAY_DEPTH    (2),
        .HAS_MULTIPLIER (0),
        .IS_STAGE4      (1)
    ) u_stage4 (
        .clk       (clk),
        .rst_n     (rst_n),
        .en        (core_en),
        .sel       (stage4_sel),
        .tw_addr   (stage4_tw_addr),
        .stage_in  (stage3_out),
        .stage_out (stage4_out)
    );

    // =====================================================================
    // Stage 5 (Delay Depth = 1, Direct Wire Pass-Through, No Multiplier/ROM)
    // =====================================================================
    fft_stage #(
        .DELAY_DEPTH    (1),
        .HAS_MULTIPLIER (0),
        .IS_STAGE4      (0)
    ) u_stage5 (
        .clk       (clk),
        .rst_n     (rst_n),
        .en        (core_en),
        .sel       (stage5_sel),
        .tw_addr   (4'd0),
        .stage_in  (stage4_out),
        .stage_out (stage5_out)
    );

    // Unpack Top Output from complex_t
    assign out_data_re = stage5_out.re;
    assign out_data_im = stage5_out.im;

endmodule : fft32_top
