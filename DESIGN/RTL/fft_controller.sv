// =============================================================================
// File Name      : fft_controller.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-09-27
// Version        : 1.1
// Description    : Parameterized timing and synchronization controller for R2SDF pipeline.
//                  Includes:
//                    - Parameterized sample counter (cnt[NUM_STAGES-1:0])
//                    - Parameterized stage steering decoders (stage_sel[s] = cnt[S-1-s])
//                    - Twiddle ROM address generators (stage_tw_addr[s])
//                    - (N-1)-cycle pipeline latency shift register for valid_out
//                    - Automatic flush controller (flush_cnt) to empty in-flight samples
// =============================================================================

import fft_pkg::*;

module fft_controller #(
    parameter int N              = 32,
    localparam int NUM_STAGES    = $clog2(N),
    localparam int TW_ADDR_WIDTH = (N <= 4) ? 1 : (NUM_STAGES - 1),
    localparam int PIPELINE_LAT  = N - 1
)(
    input  logic                                     clk,
    input  logic                                     rst_n,
    input  logic                                     valid_in,
    output logic [NUM_STAGES-1:0]                    stage_sel,
    output logic [NUM_STAGES-1:0][TW_ADDR_WIDTH-1:0] stage_tw_addr,
    output logic                                     core_en,
    output logic                                     valid_out
);

    // Sample Counter & Flush Counter
    logic [NUM_STAGES-1:0] cnt;
    logic [NUM_STAGES:0]   flush_cnt;
    logic                  flushing;

    assign flushing = (flush_cnt != '0);
    assign core_en  = valid_in || flushing;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt       <= '0;
            flush_cnt <= '0;
        end else begin
            if (valid_in) begin
                cnt <= cnt + 1'b1;
                if (cnt == NUM_STAGES'(N - 1)) begin
                    flush_cnt <= (NUM_STAGES+1)'(N - 1);
                end
            end else if (flushing) begin
                if (flush_cnt == (NUM_STAGES+1)'(1)) begin
                    cnt       <= '0;
                    flush_cnt <= '0;
                end else begin
                    cnt       <= cnt + 1'b1;
                    flush_cnt <= flush_cnt - 1'b1;
                end
            end
        end
    end

    // Stage Steering & Twiddle Address Generators
    generate
        for (genvar s = 0; s < NUM_STAGES; s++) begin : gen_ctrl_stage
            // Steering selector alternates with period 2 * DELAY_DEPTH
            assign stage_sel[s] = cnt[NUM_STAGES - 1 - s];

            if (s < NUM_STAGES - 2) begin : gen_mult_tw
                // Multiplier stages: cnt[NUM_STAGES - 2 - s : 0] shifted left by s
                assign stage_tw_addr[s] = (TW_ADDR_WIDTH'(cnt[NUM_STAGES - 2 - s : 0])) << s;
            end else if (s == NUM_STAGES - 2) begin : gen_trivial_tw
                // Penultimate stage: W4 trivial twiddle controlled by cnt[0]
                assign stage_tw_addr[s] = TW_ADDR_WIDTH'(cnt[0]);
            end else begin : gen_final_tw
                // Final stage: Multiplier-free wire pass-through
                assign stage_tw_addr[s] = '0;
            end
        end
    endgenerate

    // (N - 1)-Cycle Valid Pipeline Shift Register
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
