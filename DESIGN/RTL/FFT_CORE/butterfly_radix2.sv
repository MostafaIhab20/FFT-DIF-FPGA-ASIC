// =============================================================================
// File Name      : butterfly_radix2.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-09-27
// Version        : 1.0
// Description    : Radix-2 Decimation-in-Frequency (DIF) Butterfly Processing Element.
//                  Computes:
//                    Sum  = (A + B + 1) >>> 1   (Stage scaling /2 with Round-Half-Up)
//                    Diff = (A - B + 1) >>> 1   (Stage scaling /2 with Round-Half-Up)
//                  Features 18-bit internal headroom, unbiased rounding, and
//                  corner-case saturation clamping to prevent word-width growth.
// =============================================================================

import fft_pkg::*;

module butterfly_radix2 (
    input  wire complex_t a,
    input  wire complex_t b,
    output complex_t      sum,
    output complex_t      diff
);

    // Internal 18-bit Signed Addition & Subtraction (Sign-extended by 2 bits)
    logic signed [DATA_WIDTH+1:0] sum_re_ext,  sum_im_ext;
    logic signed [DATA_WIDTH+1:0] diff_re_ext, diff_im_ext;

    // Round-Half-Up (+1 before arithmetic right shift)
    logic signed [DATA_WIDTH+1:0] sum_re_rnd,  sum_im_rnd;
    logic signed [DATA_WIDTH+1:0] diff_re_rnd, diff_im_rnd;

    // Shift Right by 1 (Divide by 2)
    logic signed [DATA_WIDTH-1:0] sum_re_shf,  sum_im_shf;
    logic signed [DATA_WIDTH-1:0] diff_re_shf, diff_im_shf;

    // 18-bit sign-extended inputs (natively signed)
    wire signed [DATA_WIDTH+1:0] a_re_18 = { {2{a.re[DATA_WIDTH-1]}}, a.re };
    wire signed [DATA_WIDTH+1:0] b_re_18 = { {2{b.re[DATA_WIDTH-1]}}, b.re };
    wire signed [DATA_WIDTH+1:0] a_im_18 = { {2{a.im[DATA_WIDTH-1]}}, a.im };
    wire signed [DATA_WIDTH+1:0] b_im_18 = { {2{b.im[DATA_WIDTH-1]}}, b.im };

    generate
        if (TARGET_FPGA) begin : gen_fpga_adder
            // FPGA: Inferred fast dedicated vertical carry chains (CARRY4 / CARRY8)
            assign sum_re_ext  = a_re_18 + b_re_18;
            assign sum_im_ext  = a_im_18 + b_im_18;
            assign diff_re_ext = a_re_18 - b_re_18;
            assign diff_im_ext = a_im_18 - b_im_18;
        end else begin : gen_asic_adder
            // ASIC: Dedicated Brent-Kung Parallel-Prefix Adders
            adder_subtractor_bk #(.WIDTH(DATA_WIDTH+2)) u_add_re (
                .a        (a_re_18),
                .b        (b_re_18),
                .sub      (1'b0),
                .sum      (sum_re_ext),
                .cout     (),
                .overflow ()
            );

            adder_subtractor_bk #(.WIDTH(DATA_WIDTH+2)) u_sub_re (
                .a        (a_re_18),
                .b        (b_re_18),
                .sub      (1'b1),
                .sum      (diff_re_ext),
                .cout     (),
                .overflow ()
            );

            adder_subtractor_bk #(.WIDTH(DATA_WIDTH+2)) u_add_im (
                .a        (a_im_18),
                .b        (b_im_18),
                .sub      (1'b0),
                .sum      (sum_im_ext),
                .cout     (),
                .overflow ()
            );

            adder_subtractor_bk #(.WIDTH(DATA_WIDTH+2)) u_sub_im (
                .a        (a_im_18),
                .b        (b_im_18),
                .sub      (1'b1),
                .sum      (diff_im_ext),
                .cout     (),
                .overflow ()
            );
        end
    endgenerate

    always_comb begin

        // Round-Half-Up (+1)
        sum_re_rnd  = sum_re_ext  + 18'sd1;
        sum_im_rnd  = sum_im_ext  + 18'sd1;
        diff_re_rnd = diff_re_ext + 18'sd1;
        diff_im_rnd = diff_im_ext + 18'sd1;

        // Shift by 1 (Divide by 2)
        sum_re_shf  = sum_re_rnd[DATA_WIDTH:1];
        sum_im_shf  = sum_im_rnd[DATA_WIDTH:1];
        diff_re_shf = diff_re_rnd[DATA_WIDTH:1];
        diff_im_shf = diff_im_rnd[DATA_WIDTH:1];

        // Sum never overflows [-32768, +32767]
        sum.re  = sum_re_shf;
        sum.im  = sum_im_shf;

        // Diff clamps only in the single corner case where A - B + 1 == 65536
        diff.re = (diff_re_rnd == 18'sd65536) ? MAX_POS : diff_re_shf;
        diff.im = (diff_im_rnd == 18'sd65536) ? MAX_POS : diff_im_shf;
    end

endmodule : butterfly_radix2
