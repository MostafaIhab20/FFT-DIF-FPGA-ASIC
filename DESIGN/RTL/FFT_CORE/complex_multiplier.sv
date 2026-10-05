// =============================================================================
// File Name      : complex_multiplier.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-09-27
// Version        : 1.0
// Description    : 16-bit Signed Q1.15 Complex Multiplier. Computes Y = X * W:
//                    Y_re = (X_re * W_re - X_im * W_im + 2^14) >>> 15
//                    Y_im = (X_re * W_im + X_im * W_re + 2^14) >>> 15
//                  Includes zero-power hardware bypasses for W = 1 and W = -j
//                  to completely eliminate dynamic switching activity when trivial.
//                  Supports parameterized pipeline depth (MULT_PIPE_STAGES).
// =============================================================================

import fft_pkg::*;

module complex_multiplier #(
    parameter int MULT_PIPE_STAGES = 0
)(
    input  logic          clk,
    input  logic          rst_n,
    input  logic          en,
    input  wire complex_t x,
    input  wire complex_t w,
    input  logic          is_unity, // Bypass for W = 1
    input  logic          is_neg_j, // Bypass for W = -j
    output complex_t      y
);

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================
    // 32-bit Q2.30 Real Multiplier Partial Products
    logic signed [2*DATA_WIDTH-1:0] m1, m2, m3, m4;
    logic signed [2*DATA_WIDTH-1:0] m1_dsp, m2_dsp, m3_dsp, m4_dsp;

    // 33-bit Real and Imaginary Pre-Rounding Sums
    logic signed [2*DATA_WIDTH:0]   prod_r, prod_i;

    // 33-bit Post-Rounding Vectors (+2^14 Round-Half-Up)
    logic signed [2*DATA_WIDTH:0]   rnd_r, rnd_i;

    // 16-bit Shifted Vectors (Arithmetic Right Shift by 15)
    logic signed [DATA_WIDTH-1:0]   shf_r, shf_i;

    // Overflow / Saturation Flags
    logic                           ovf_r, ovf_i;
    logic signed [DATA_WIDTH-1:0]   mult_out_r, mult_out_i;
    logic signed [DATA_WIDTH-1:0]   neg_xr;

    // Zero-Power Bypass Alignment Signals
    complex_t                       x_aligned;
    logic                           is_unity_aligned;
    logic                           is_neg_j_aligned;

    // =========================================================================
    // Dual-Target Multiplier Core (FPGA DSP48 vs. ASIC Booth)
    // =========================================================================
    generate
        if (TARGET_FPGA) begin : gen_fpga_dsp
            // FPGA: Inferred Hard DSP48 Slices and Dedicated Carry Chains
            (* use_dsp = "yes" *) assign m1_dsp = x.re * w.re;
            (* use_dsp = "yes" *) assign m2_dsp = x.im * w.im;
            (* use_dsp = "yes" *) assign m3_dsp = x.re * w.im;
            (* use_dsp = "yes" *) assign m4_dsp = x.im * w.re;

            if (MULT_PIPE_STAGES > 0) begin : gen_dsp_pipe
                logic signed [2*DATA_WIDTH-1:0] m1_pipe [0:MULT_PIPE_STAGES-1];
                logic signed [2*DATA_WIDTH-1:0] m2_pipe [0:MULT_PIPE_STAGES-1];
                logic signed [2*DATA_WIDTH-1:0] m3_pipe [0:MULT_PIPE_STAGES-1];
                logic signed [2*DATA_WIDTH-1:0] m4_pipe [0:MULT_PIPE_STAGES-1];

                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        for (int i = 0; i < MULT_PIPE_STAGES; i++) begin
                            m1_pipe[i] <= '0;
                            m2_pipe[i] <= '0;
                            m3_pipe[i] <= '0;
                            m4_pipe[i] <= '0;
                        end
                    end else if (en) begin
                        m1_pipe[0] <= m1_dsp;
                        m2_pipe[0] <= m2_dsp;
                        m3_pipe[0] <= m3_dsp;
                        m4_pipe[0] <= m4_dsp;
                        for (int i = 1; i < MULT_PIPE_STAGES; i++) begin
                            m1_pipe[i] <= m1_pipe[i-1];
                            m2_pipe[i] <= m2_pipe[i-1];
                            m3_pipe[i] <= m3_pipe[i-1];
                            m4_pipe[i] <= m4_pipe[i-1];
                        end
                    end
                end

                assign m1 = m1_pipe[MULT_PIPE_STAGES-1];
                assign m2 = m2_pipe[MULT_PIPE_STAGES-1];
                assign m3 = m3_pipe[MULT_PIPE_STAGES-1];
                assign m4 = m4_pipe[MULT_PIPE_STAGES-1];
            end else begin : gen_dsp_comb
                assign m1 = m1_dsp;
                assign m2 = m2_dsp;
                assign m3 = m3_dsp;
                assign m4 = m4_dsp;
            end

            // Inferred hard carry chains for 33-bit accumulation
            assign prod_r = {m1[2*DATA_WIDTH-1], m1} - {m2[2*DATA_WIDTH-1], m2};
            assign prod_i = {m3[2*DATA_WIDTH-1], m3} + {m4[2*DATA_WIDTH-1], m4};

        end else begin : gen_asic_booth
            // ASIC: Dedicated 16x16 Radix-4 Modified Booth Multipliers (4:2 Compressor Tree)
            assign m1_dsp = '0;
            assign m2_dsp = '0;
            assign m3_dsp = '0;
            assign m4_dsp = '0;

            booth_radix4_multiplier #(.PIPELINE_STAGES(MULT_PIPE_STAGES)) u_mult1 (
                .clk   (clk),
                .rst_n (rst_n),
                .en    (en),
                .a     (x.re),
                .b     (w.re),
                .p     (m1)
            );

            booth_radix4_multiplier #(.PIPELINE_STAGES(MULT_PIPE_STAGES)) u_mult2 (
                .clk   (clk),
                .rst_n (rst_n),
                .en    (en),
                .a     (x.im),
                .b     (w.im),
                .p     (m2)
            );

            booth_radix4_multiplier #(.PIPELINE_STAGES(MULT_PIPE_STAGES)) u_mult3 (
                .clk   (clk),
                .rst_n (rst_n),
                .en    (en),
                .a     (x.re),
                .b     (w.im),
                .p     (m3)
            );

            booth_radix4_multiplier #(.PIPELINE_STAGES(MULT_PIPE_STAGES)) u_mult4 (
                .clk   (clk),
                .rst_n (rst_n),
                .en    (en),
                .a     (x.im),
                .b     (w.re),
                .p     (m4)
            );

            // Dedicated Brent-Kung Adders / Subtractors for Accumulation
            adder_subtractor_bk #(.WIDTH(2*DATA_WIDTH+1)) u_sub_prod_r (
                .a        ({m1[2*DATA_WIDTH-1], m1}),
                .b        ({m2[2*DATA_WIDTH-1], m2}),
                .sub      (1'b1), // Subtraction: m1 - m2
                .sum      (prod_r),
                .cout     (),
                .overflow ()
            );

            adder_subtractor_bk #(.WIDTH(2*DATA_WIDTH+1)) u_add_prod_i (
                .a        ({m3[2*DATA_WIDTH-1], m3}),
                .b        ({m4[2*DATA_WIDTH-1], m4}),
                .sub      (1'b0), // Addition: m3 + m4
                .sum      (prod_i),
                .cout     (),
                .overflow ()
            );
        end
    endgenerate

    // =========================================================================
    // Zero-Power Bypass Pipeline Alignment
    //    Aligns trivial bypass paths with multiplier pipeline stages
    // =========================================================================
    generate
        if (MULT_PIPE_STAGES > 0) begin : gen_bypass_pipe
            complex_t x_pipe [0:MULT_PIPE_STAGES-1];
            logic [MULT_PIPE_STAGES-1:0] is_unity_pipe;
            logic [MULT_PIPE_STAGES-1:0] is_neg_j_pipe;

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    is_unity_pipe <= '0;
                    is_neg_j_pipe <= '0;
                    for (int i = 0; i < MULT_PIPE_STAGES; i++) begin
                        x_pipe[i].re <= '0;
                        x_pipe[i].im <= '0;
                    end
                end else if (en) begin
                    x_pipe[0]        <= x;
                    is_unity_pipe[0] <= is_unity;
                    is_neg_j_pipe[0] <= is_neg_j;
                    for (int i = 1; i < MULT_PIPE_STAGES; i++) begin
                        x_pipe[i]        <= x_pipe[i-1];
                        is_unity_pipe[i] <= is_unity_pipe[i-1];
                        is_neg_j_pipe[i] <= is_neg_j_pipe[i-1];
                    end
                end
            end

            assign x_aligned        = x_pipe[MULT_PIPE_STAGES-1];
            assign is_unity_aligned = is_unity_pipe[MULT_PIPE_STAGES-1];
            assign is_neg_j_aligned = is_neg_j_pipe[MULT_PIPE_STAGES-1];
        end else begin : gen_bypass_direct
            assign x_aligned        = x;
            assign is_unity_aligned = is_unity;
            assign is_neg_j_aligned = is_neg_j;
        end
    endgenerate

    // =========================================================================
    // Fixed-Point Formatting, Saturation, and Bypass Multiplexing
    // =========================================================================
    always_comb begin
        // Round-Half-Up (+2^14)
        rnd_r = prod_r + 33'sh00004000;
        rnd_i = prod_i + 33'sh00004000;

        // Arithmetic shift right by 15 (Extract bits [30:15])
        shf_r = rnd_r[2*DATA_WIDTH-2 : DATA_WIDTH-1];
        shf_i = rnd_i[2*DATA_WIDTH-2 : DATA_WIDTH-1];

        // Saturation check on Q2.30 -> Q1.15
        ovf_r = (rnd_r[2*DATA_WIDTH] != rnd_r[2*DATA_WIDTH-1]) || (rnd_r[2*DATA_WIDTH-1] != rnd_r[2*DATA_WIDTH-2]);
        ovf_i = (rnd_i[2*DATA_WIDTH] != rnd_i[2*DATA_WIDTH-1]) || (rnd_i[2*DATA_WIDTH-1] != rnd_i[2*DATA_WIDTH-2]);

        mult_out_r = ovf_r ? (rnd_r[2*DATA_WIDTH] ? MIN_NEG : MAX_POS) : shf_r;
        mult_out_i = ovf_i ? (rnd_i[2*DATA_WIDTH] ? MIN_NEG : MAX_POS) : shf_i;

        // Negation with saturation for -j bypass: (-(-32768) -> +32767)
        neg_xr = (x_aligned.re == MIN_NEG) ? MAX_POS : -x_aligned.re;

        // Output Multiplexing
        if (is_unity_aligned) begin
            y.re = x_aligned.re;
            y.im = x_aligned.im;
        end else if (is_neg_j_aligned) begin
            y.re = x_aligned.im;
            y.im = neg_xr;
        end else begin
            y.re = mult_out_r;
            y.im = mult_out_i;
        end
    end

endmodule : complex_multiplier
