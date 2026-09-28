// =============================================================================
// File Name      : fft_controller.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-09-27
// Version        : 1.0
// Description    : Central timing and synchronization controller for the R2SDF pipeline.
//                  Includes:
//                    - 5-bit sample counter (cnt[4:0])
//                    - Synchronous stage steering decoders (stage1_sel .. stage5_sel)
//                    - Twiddle ROM address generators (stage1_tw_addr .. stage4_tw_addr)
//                    - 31-cycle pipeline latency shift register for valid_out
//                    - Automatic flush controller (flush_cnt) to empty in-flight samples
// =============================================================================

import fft32_pkg::*;

module fft_controller (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       valid_in,
    output logic       stage1_sel,
    output logic [3:0] stage1_tw_addr,
    output logic       stage2_sel,
    output logic [3:0] stage2_tw_addr,
    output logic       stage3_sel,
    output logic [3:0] stage3_tw_addr,
    output logic       stage4_sel,
    output logic [3:0] stage4_tw_addr,
    output logic       stage5_sel,
    output logic       core_en,
    output logic       valid_out
);

    // 5-bit Binary Counter & Flush Counter
    logic [4:0] cnt;
    logic [5:0] flush_cnt;
    logic       flushing;

    assign flushing = (flush_cnt != 6'd0);
    assign core_en  = valid_in || flushing;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt       <= '0;
            flush_cnt <= '0;
        end else begin
            if (valid_in) begin
                cnt <= cnt + 1'b1;
                if (cnt == 5'd31) begin
                    flush_cnt <= 6'd31;
                end
            end else if (flushing) begin
                if (flush_cnt == 6'd1) begin
                    cnt       <= '0;
                    flush_cnt <= '0;
                end else begin
                    cnt       <= cnt + 1'b1;
                    flush_cnt <= flush_cnt - 1'b1;
                end
            end
        end
    end

    // Stage 1 (D=16): Controlled by cnt[4], Twiddle Address cnt[3:0] (k=0..15)
    assign stage1_sel     = cnt[4];
    assign stage1_tw_addr = cnt[3:0];

    // Stage 2 (D=8): Controlled by cnt[3], Twiddle Address {cnt[2:0], 1'b0} (k=0,2..14)
    assign stage2_sel     = cnt[3];
    assign stage2_tw_addr = {cnt[2:0], 1'b0};

    // Stage 3 (D=4): Controlled by cnt[2], Twiddle Address {cnt[1:0], 2'b0} (k=0,4,8,12)
    assign stage3_sel     = cnt[2];
    assign stage3_tw_addr = {cnt[1:0], 2'b0};

    // Stage 4 (D=2): Controlled by cnt[1], Trivial Twiddle Bit cnt[0]
    assign stage4_sel     = cnt[1];
    assign stage4_tw_addr = {3'b000, cnt[0]};

    // Stage 5 (D=1): Controlled by cnt[0] (Multiplier-free direct wire pass-through)
    assign stage5_sel = cnt[0];

    // 31-Cycle Valid Pipeline Shift Register
    logic [PIPELINE_LAT-1:0] valid_pipe;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipe <= '0;
        end else if (core_en) begin
            valid_pipe <= {valid_pipe[PIPELINE_LAT-2:0], valid_in};
        end
    end

    assign valid_out = valid_pipe[PIPELINE_LAT-1];

endmodule : fft_controller
