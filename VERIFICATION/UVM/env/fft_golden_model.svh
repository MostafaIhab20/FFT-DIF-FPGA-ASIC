// =============================================================================
// File Name      : fft_golden_model.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Bit-accurate SystemVerilog reference model for 32-point DIF FFT.
//                  Computes Q1.15 fixed-point Radix-2 DIF FFT with exact stage-by-stage
//                  round-half-up scaling and hardware twiddle bypasses.
// =============================================================================

`ifndef FFT_GOLDEN_MODEL_SVH
`define FFT_GOLDEN_MODEL_SVH

class fft_golden_model extends uvm_object;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(fft_golden_model)

    // ==================================================
    // Constants & Twiddle Tables
    // ==================================================
    localparam int N = 32;
    localparam int STAGES = 5;

    // Twiddle Factor Table for N=32 (Q1.15 format)
    static const logic signed [15:0] TW_RE[16] = '{
        16'sh7FFF, 16'sh7D8A, 16'sh7642, 16'sh6A6E,
        16'sh5A82, 16'sh471D, 16'sh30FC, 16'sh18F9,
        16'sh0000, 16'shE707, 16'shCF04, 16'shB8E3,
        16'shA57E, 16'sh9592, 16'sh89BE, 16'sh8276
    };

    static const logic signed [15:0] TW_IM[16] = '{
        16'sh0000, 16'shE707, 16'shCF04, 16'shB8E3,
        16'shA57E, 16'sh9592, 16'sh89BE, 16'sh8276,
        16'sh8000, 16'sh8276, 16'sh89BE, 16'sh9592,
        16'shA57E, 16'shB8E3, 16'shCF04, 16'shE707
    };

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_golden_model");
        super.new(name);
    endfunction

    // ==================================================
    // Mathematical & Helper Functions
    // ==================================================
    // 5-bit reversal helper function
    static function automatic logic [4:0] bit_reverse_5(logic [4:0] in);
        return {in[0], in[1], in[2], in[3], in[4]};
    endfunction

    // Signed saturation clamp to 16-bit Q1.15 range [-32768, 32767]
    static function automatic logic signed [15:0] sat_clip(logic signed [32:0] val);
        if (val > 32'sd32767)
            return 16'sh7FFF;
        else if (val < -32'sd32768)
            return 16'sh8000;
        else
            return val[15:0];
    endfunction

    // ==================================================
    // Reference Model Computation Engine
    // ==================================================
    // Compute 32-point DIF FFT matching hardware pipeline
    static function void compute_fft_32(
        input  logic [31:0] in_samples[32],
        output logic [31:0] out_samples[32],
        input  bit          natural_order = 1'b1
    );
        logic signed [15:0] data_re[32];
        logic signed [15:0] data_im[32];

        for (int i = 0; i < 32; i++) begin
            data_re[i] = signed'(in_samples[i][31:16]);
            data_im[i] = signed'(in_samples[i][15:0]);
        end

        // 5-Stage Decimation-in-Frequency algorithmic pipeline
        for (int s = 1; s <= STAGES; s++) begin
            int len     = N / (1 << s);
            int stride  = 2 * len;
            int tw_step = N / stride;

            for (int start = 0; start < N; start += stride) begin
                for (int k = 0; k < len; k++) begin
                    int idx_a = start + k;
                    int idx_b = start + k + len;

                    logic signed [15:0] ar = data_re[idx_a];
                    logic signed [15:0] ai = data_im[idx_a];
                    logic signed [15:0] br = data_re[idx_b];
                    logic signed [15:0] bi = data_im[idx_b];

                    // Butterfly Add & Subtract with Round-Half-Up division by 2
                    logic signed [32:0] sum_re  = (signed'(ar) + signed'(br) + 33'sd1) >>> 1;
                    logic signed [32:0] sum_im  = (signed'(ai) + signed'(bi) + 33'sd1) >>> 1;
                    logic signed [32:0] diff_re = (signed'(ar) - signed'(br) + 33'sd1) >>> 1;
                    logic signed [32:0] diff_im = (signed'(ai) - signed'(bi) + 33'sd1) >>> 1;

                    logic signed [15:0] d_re = sat_clip(diff_re);
                    logic signed [15:0] d_im = sat_clip(diff_im);

                    // Twiddle complex multiplication
                    int tw_k = k * tw_step;
                    logic signed [15:0] prod_re;
                    logic signed [15:0] prod_im;

                    if (tw_k == 0) begin
                        prod_re = d_re;
                        prod_im = d_im;
                    end else if (tw_k == 8) begin
                        prod_re = d_im;
                        prod_im = sat_clip(-signed'(d_re));
                    end else begin
                        logic signed [15:0] wr = TW_RE[tw_k];
                        logic signed [15:0] wi = TW_IM[tw_k];

                        logic signed [31:0] m1 = signed'(d_re) * signed'(wr);
                        logic signed [31:0] m2 = signed'(d_im) * signed'(wi);
                        logic signed [31:0] m3 = signed'(d_re) * signed'(wi);
                        logic signed [31:0] m4 = signed'(d_im) * signed'(wr);

                        logic signed [32:0] pr = signed'(m1) - signed'(m2);
                        logic signed [32:0] pi = signed'(m3) + signed'(m4);

                        // Round-Half-Up (+2^14 before shift by 15)
                        logic signed [32:0] rnd_r = (pr + 33'sd16384) >>> 15;
                        logic signed [32:0] rnd_i = (pi + 33'sd16384) >>> 15;

                        prod_re = sat_clip(rnd_r);
                        prod_im = sat_clip(rnd_i);
                    end

                    data_re[idx_a] = sat_clip(sum_re);
                    data_im[idx_a] = sat_clip(sum_im);
                    data_re[idx_b] = prod_re;
                    data_im[idx_b] = prod_im;
                end
            end
        end

        // Output reordering
        if (natural_order) begin
            for (int i = 0; i < 32; i++) begin
                logic [4:0] rev_idx = bit_reverse_5(i[4:0]);
                out_samples[rev_idx] = {data_re[i], data_im[i]};
            end
        end else begin
            for (int i = 0; i < 32; i++) begin
                out_samples[i] = {data_re[i], data_im[i]};
            end
        end
    endfunction

endclass : fft_golden_model

`endif // FFT_GOLDEN_MODEL_SVH
