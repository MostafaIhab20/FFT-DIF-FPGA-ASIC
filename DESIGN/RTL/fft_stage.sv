// =============================================================================
// File Name      : fft_stage.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-09-27
// Version        : 1.0
// Description    : Parameterized Radix-2 DIF Single-Path Delay Feedback Stage.
//                  Integrates MUX A (delay feedback), delay line (depth D),
//                  butterfly processing element, twiddle factor unit (full multiplier,
//                  trivial swap-and-negate mux for stage 4, or wire pass for stage 5),
//                  and MUX B (output steering).
// Parameters     :
//   DELAY_DEPTH    : Delay line length (16, 8, 4, 2, or 1)
//   HAS_MULTIPLIER : 1 for Stages 1-3, 0 for Stages 4-5
//   IS_STAGE4      : 1 for Stage 4 (trivial swap & negate for W4^0=1, W4^1=-j)
//                    When both HAS_MULTIPLIER=0 and IS_STAGE4=0, acts as Stage 5
//                    (direct wire pass-through, zero multiplier gates).
// =============================================================================

import fft32_pkg::*;

module fft_stage #(
    parameter int DELAY_DEPTH    = 16,
    parameter int HAS_MULTIPLIER = 1,
    parameter int IS_STAGE4      = 0
)(
    input  logic          clk,
    input  logic          rst_n,
    input  logic          en,
    input  logic          sel,           // 0: Load/Flush (Phase 0), 1: Butterfly (Phase 1)
    input  logic [3:0]    tw_addr = '0,  // 4-bit Twiddle ROM address (unused in Stage 5)
    input  wire complex_t stage_in,
    output complex_t      stage_out
);

    // Internal Signals
    complex_t mux_a_out;
    complex_t delay_out;
    complex_t bf_sum;
    complex_t bf_diff;
    complex_t tw_out;

    // ---------------------------------------------------------------------
    // 1. MUX A: Delay Line Input Steering
    //    sel = 0: Load incoming samples into delay line
    //    sel = 1: Feedback butterfly difference into delay line
    // ---------------------------------------------------------------------
    assign mux_a_out = (sel) ? bf_diff : stage_in;

    // ---------------------------------------------------------------------
    // 2. Delay Feedback Line (Depth = DELAY_DEPTH)
    // ---------------------------------------------------------------------
    delay_feedback_line #(
        .DEPTH(DELAY_DEPTH)
    ) u_delay_line (
        .clk   (clk),
        .rst_n (rst_n),
        .en    (en),
        .din   (mux_a_out),
        .dout  (delay_out)
    );

    // ---------------------------------------------------------------------
    // 3. Radix-2 DIF Butterfly PE
    //    Pairs sample A (emerging from delay) with sample B (stage_in)
    // ---------------------------------------------------------------------
    butterfly_radix2 u_butterfly (
        .a    (delay_out),
        .b    (stage_in),
        .sum  (bf_sum),
        .diff (bf_diff)
    );

    // ---------------------------------------------------------------------
    // 4. Twiddle Factor Section (Multipliers vs Trivial Muxes)
    // ---------------------------------------------------------------------
    generate
        if (HAS_MULTIPLIER == 1) begin : gen_full_mult
            complex_t tw_val;
            logic     is_unity;
            logic     is_neg_j;

            twiddle_rom u_tw_rom (
                .addr     (tw_addr),
                .twiddle  (tw_val),
                .is_unity (is_unity),
                .is_neg_j (is_neg_j)
            );

            complex_multiplier u_cmult (
                .clk      (clk),
                .rst_n    (rst_n),
                .en       (en),
                .x        (delay_out),
                .w        (tw_val),
                .is_unity (is_unity),
                .is_neg_j (is_neg_j),
                .y        (tw_out)
            );
        end else if (IS_STAGE4 == 1) begin : gen_stage4_trivial
            // Stage 4: W4^0 = 1, W4^1 = -j
            // tw_addr[0] == 0: Y = X
            // tw_addr[0] == 1: Y = (u + jv)*(-j) = v - ju
            logic signed [DATA_WIDTH-1:0] neg_xr;
            assign neg_xr = (delay_out.re == MIN_NEG) ? MAX_POS : -delay_out.re;

            assign tw_out.re = (tw_addr[0] == 1'b0) ? delay_out.re : delay_out.im;
            assign tw_out.im = (tw_addr[0] == 1'b0) ? delay_out.im : neg_xr;
        end else begin : gen_stage5_wire
            // Stage 5: W2^0 = 1 (Direct wire pass-through, 0 gates)
            assign tw_out = delay_out;
        end
    endgenerate

    // ---------------------------------------------------------------------
    // 5. MUX B: Stage Output Steering
    //    sel = 0: Flushed difference output (after twiddle)
    //    sel = 1: Direct butterfly sum output
    // ---------------------------------------------------------------------
    assign stage_out = (sel) ? bf_sum : tw_out;

endmodule : fft_stage
