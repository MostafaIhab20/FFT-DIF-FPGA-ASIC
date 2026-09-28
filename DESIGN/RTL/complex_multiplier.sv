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
// =============================================================================

import fft32_pkg::*;

module complex_multiplier #(
    parameter int MULT_PIPE_STAGES = 0
)(
    input  logic          clk = 1'b0,
    input  logic          rst_n = 1'b1,
    input  logic          en = 1'b1,
    input  wire complex_t x,
    input  wire complex_t w,
    input  logic          is_unity, // Bypass for W = 1
    input  logic          is_neg_j, // Bypass for W = -j
    output complex_t      y
);

    // Four 16x16 Signed Multiplications -> 32-bit Q2.30 Products
    logic signed [2*DATA_WIDTH-1:0] m1, m2, m3, m4;

    // 33-bit Subtraction & Addition (Sign-extended)
    logic signed [2*DATA_WIDTH:0] prod_r, prod_i;

    generate
        if (TARGET_FPGA) begin : gen_fpga_dsp
            // FPGA: Inferred Hard DSP48 Slices and Dedicated Carry Chains
            (* use_dsp = "yes" *) wire signed [2*DATA_WIDTH-1:0] m1_dsp = x.re * w.re;
            (* use_dsp = "yes" *) wire signed [2*DATA_WIDTH-1:0] m2_dsp = x.im * w.im;
            (* use_dsp = "yes" *) wire signed [2*DATA_WIDTH-1:0] m3_dsp = x.re * w.im;
            (* use_dsp = "yes" *) wire signed [2*DATA_WIDTH-1:0] m4_dsp = x.im * w.re;

            assign m1 = m1_dsp;
            assign m2 = m2_dsp;
            assign m3 = m3_dsp;
            assign m4 = m4_dsp;

            // Inferred hard carry chains for 33-bit accumulation
            assign prod_r = {m1[2*DATA_WIDTH-1], m1} - {m2[2*DATA_WIDTH-1], m2};
            assign prod_i = {m3[2*DATA_WIDTH-1], m3} + {m4[2*DATA_WIDTH-1], m4};

        end else begin : gen_asic_booth
            // ASIC: Dedicated 16x16 Radix-4 Modified Booth Multipliers (4:2 Compressor Tree)
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

    // Round-Half-Up (+2^14 before arithmetic right shift by 15)
    logic signed [2*DATA_WIDTH:0] rnd_r, rnd_i;

    // Shift Right by 15 (Extract bits [30:15])
    logic signed [DATA_WIDTH-1:0] shf_r, shf_i;

    // Saturation Detection
    logic ovf_r, ovf_i;
    logic signed [DATA_WIDTH-1:0] mult_out_r, mult_out_i;
    logic signed [DATA_WIDTH-1:0] neg_xr;

    always_comb begin

        // Round-Half-Up
        rnd_r = prod_r + 33'sh00004000;
        rnd_i = prod_i + 33'sh00004000;

        // Shift by 15
        shf_r = rnd_r[2*DATA_WIDTH-2 : DATA_WIDTH-1];
        shf_i = rnd_i[2*DATA_WIDTH-2 : DATA_WIDTH-1];

        // Saturation check on Q2.30 -> Q1.15
        ovf_r = (rnd_r[2*DATA_WIDTH] != rnd_r[2*DATA_WIDTH-1]) || (rnd_r[2*DATA_WIDTH-1] != rnd_r[2*DATA_WIDTH-2]);
        ovf_i = (rnd_i[2*DATA_WIDTH] != rnd_i[2*DATA_WIDTH-1]) || (rnd_i[2*DATA_WIDTH-1] != rnd_i[2*DATA_WIDTH-2]);

        mult_out_r = ovf_r ? (rnd_r[2*DATA_WIDTH] ? MIN_NEG : MAX_POS) : shf_r;
        mult_out_i = ovf_i ? (rnd_i[2*DATA_WIDTH] ? MIN_NEG : MAX_POS) : shf_i;

        // Negation with saturation for -j bypass: (-(-32768) -> +32767)
        neg_xr = (x.re == MIN_NEG) ? MAX_POS : -x.re;

        // Output Multiplexing
        if (is_unity) begin
            y.re = x.re;
            y.im = x.im;
        end else if (is_neg_j) begin
            y.re = x.im;
            y.im = neg_xr;
        end else begin
            y.re = mult_out_r;
            y.im = mult_out_i;
        end
    end

endmodule : complex_multiplier
