// =============================================================================
// File Name      : fft_stage.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-09-27
// Version        : 1.0
// Description    : Parameterized Radix-2 DIF Single-Path Delay Feedback (R2SDF) Stage.
//                  Integrates MUX A (delay feedback), delay line (depth D),
//                  butterfly processing element, twiddle factor unit (full multiplier,
//                  W4 swap-and-negate MUX for penultimate stage IS_W4_STAGE, or wire pass for final stage),
//                  MUX B (output steering), and synchronous inter-stage pipeline register.
//                  Supports parameterized internal multiplier pipelining (MULT_PIPE_STAGES).
// =============================================================================

import fft_pkg::*;

module fft_stage #(
    parameter int N                = 32,
    parameter int DELAY_DEPTH      = 16,
    parameter int TW_ADDR_WIDTH    = (N <= 4) ? 1 : $clog2(N/2),
    parameter int HAS_MULTIPLIER   = 1,
    parameter int IS_W4_STAGE      = 0,
    parameter int MULT_PIPE_STAGES = 0
)(
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     en,
    input  logic                     sel,           // 0: Load/Flush (Phase 0), 1: Butterfly (Phase 1)
    input  logic [TW_ADDR_WIDTH-1:0] tw_addr = '0,  // Twiddle ROM address (unused in final stage)
    input  wire complex_t            stage_in,
    output complex_t                 stage_out
);

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================
    complex_t                     mux_a_out;
    complex_t                     delay_out;
    complex_t                     bf_sum;
    complex_t                     bf_diff;
    complex_t                     tw_out;
    complex_t                     bf_sum_aligned;
    logic                         sel_b_aligned;
    complex_t                     stage_comb;
    complex_t                     tw_val;
    logic                         is_unity;
    logic                         is_neg_j;
    logic signed [DATA_WIDTH-1:0] neg_xr;

    // =========================================================================
    // 1. MUX A: Delay Line Input Steering
    //    sel = 0: Load incoming samples into delay line
    //    sel = 1: Feedback butterfly difference into delay line
    // =========================================================================
    assign mux_a_out = (sel) ? bf_diff : stage_in;

    // =========================================================================
    // 2. Delay Feedback Line (Depth = DELAY_DEPTH)
    // =========================================================================
    delay_feedback_line #(
        .DEPTH(DELAY_DEPTH)
    ) u_delay_line (
        .clk   (clk),
        .rst_n (rst_n),
        .en    (en),
        .din   (mux_a_out),
        .dout  (delay_out)
    );

    // =========================================================================
    // 3. Radix-2 DIF Butterfly PE
    //    Pairs sample A (emerging from delay) with sample B (stage_in)
    // =========================================================================
    butterfly_radix2 u_butterfly (
        .a    (delay_out),
        .b    (stage_in),
        .sum  (bf_sum),
        .diff (bf_diff)
    );

    // =========================================================================
    // 4. Twiddle Factor Section (Full Multiplier, W4 Swap-Negate, or Wire Pass-Through)
    // =========================================================================
    generate
        if (HAS_MULTIPLIER == 1) begin : gen_full_mult
            assign neg_xr = '0;

            twiddle_rom #(
                .N          (N),
                .ADDR_WIDTH (TW_ADDR_WIDTH)
            ) u_tw_rom (
                .addr     (tw_addr),
                .twiddle  (tw_val),
                .is_unity (is_unity),
                .is_neg_j (is_neg_j)
            );

            complex_multiplier #(
                .MULT_PIPE_STAGES (MULT_PIPE_STAGES)
            ) u_cmult (
                .clk      (clk),
                .rst_n    (rst_n),
                .en       (en),
                .x        (delay_out),
                .w        (tw_val),
                .is_unity (is_unity),
                .is_neg_j (is_neg_j),
                .y        (tw_out)
            );
        end else if (IS_W4_STAGE) begin : gen_w4_stage
            // Penultimate Stage (D=2): W4^0 = 1, W4^1 = -j
            // tw_addr[0] == 0: Y = X
            // tw_addr[0] == 1: Y = (u + jv)*(-j) = v - ju
            assign tw_val   = '{re: '0, im: '0};
            assign is_unity = 1'b0;
            assign is_neg_j = 1'b0;
            assign neg_xr   = (delay_out.re == MIN_NEG) ? MAX_POS : -delay_out.re;

            assign tw_out.re = (tw_addr[0] == 1'b0) ? delay_out.re : delay_out.im;
            assign tw_out.im = (tw_addr[0] == 1'b0) ? delay_out.im : neg_xr;
        end else begin : gen_wire_stage
            // Final Stage (D=1): W2^0 = 1 (Direct wire pass-through, 0 gates)
            assign tw_val   = '{re: '0, im: '0};
            assign is_unity = 1'b0;
            assign is_neg_j = 1'b0;
            assign neg_xr   = '0;
            assign tw_out   = delay_out;
        end
    endgenerate

    // =========================================================================
    // 5. Multiplier Latency Synchronization
    //    Aligns butterfly sum and MUX B select with tw_out pipeline latency
    // =========================================================================
    generate
        if (HAS_MULTIPLIER && (MULT_PIPE_STAGES > 0)) begin : gen_mult_sync
            complex_t bf_sum_pipe [0:MULT_PIPE_STAGES-1];
            logic [MULT_PIPE_STAGES-1:0] sel_b_pipe;

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    sel_b_pipe <= '0;
                    for (int i = 0; i < MULT_PIPE_STAGES; i++) begin
                        bf_sum_pipe[i].re <= '0;
                        bf_sum_pipe[i].im <= '0;
                    end
                end else if (en) begin
                    sel_b_pipe[0]  <= sel;
                    bf_sum_pipe[0] <= bf_sum;
                    for (int i = 1; i < MULT_PIPE_STAGES; i++) begin
                        sel_b_pipe[i]  <= sel_b_pipe[i-1];
                        bf_sum_pipe[i] <= bf_sum_pipe[i-1];
                    end
                end
            end

            assign sel_b_aligned  = sel_b_pipe[MULT_PIPE_STAGES-1];
            assign bf_sum_aligned = bf_sum_pipe[MULT_PIPE_STAGES-1];
        end else begin : gen_no_mult_sync
            assign sel_b_aligned  = sel;
            assign bf_sum_aligned = bf_sum;
        end
    endgenerate

    // =========================================================================
    // 6. MUX B & Inter-Stage Synchronous Pipeline Register
    //    sel_b_aligned = 0: Flushed difference output (after twiddle)
    //    sel_b_aligned = 1: Direct butterfly sum output
    // =========================================================================
    assign stage_comb = (sel_b_aligned) ? bf_sum_aligned : tw_out;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage_out.re <= '0;
            stage_out.im <= '0;
        end else if (en) begin
            stage_out <= stage_comb;
        end
    end

endmodule : fft_stage
