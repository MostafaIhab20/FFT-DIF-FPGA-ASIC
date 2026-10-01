// =============================================================================
// File Name      : fft_controller.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-09-27
// Version        : 1.0
// Description    : Parameterized timing and synchronization controller for R2SDF pipeline.
//                  Includes:
//                    - Parameterized sample counter (cnt[NUM_STAGES-1:0])
//                    - Parameterized inter-stage control skew pipeline for stage_sel and tw_addr
//                      incorporating multiplier latency (MULT_PIPE_STAGES)
//                    - Parameterized valid_out pipeline delay shift register
//                    - Automatic flush controller (flush_cnt) to drain in-flight samples
// =============================================================================

import fft_pkg::*;

module fft_controller #(
    parameter int N                = 32,
    parameter int MULT_PIPE_STAGES = 0,
    localparam int NUM_STAGES      = $clog2(N),
    localparam int TW_ADDR_WIDTH   = (N <= 4) ? 1 : (NUM_STAGES - 1),
    localparam int MULT_STAGES     = (NUM_STAGES > 2) ? (NUM_STAGES - 2) : 0,
    localparam int TOTAL_MULT_LAT  = MULT_STAGES * MULT_PIPE_STAGES,
    localparam int PIPELINE_LAT    = (N - 1) + NUM_STAGES + TOTAL_MULT_LAT,
    localparam int FLUSH_WIDTH     = $clog2(PIPELINE_LAT + 1)
)(
    input  logic                                     clk,
    input  logic                                     rst_n,
    input  logic                                     clk_en,
    input  logic                                     valid_in,
    output logic [NUM_STAGES-1:0]                    stage_sel,
    output logic [NUM_STAGES-1:0][TW_ADDR_WIDTH-1:0] stage_tw_addr,
    output logic                                     core_en,
    output logic                                     valid_out
);

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================
    // Sample Counter & Flush State Signals
    logic [NUM_STAGES-1:0]                           cnt;
    logic [FLUSH_WIDTH-1:0]                          flush_cnt;
    logic                                            flushing;

    // Raw (Unskewed) Stage Steering & Twiddle Address Decoders
    logic [NUM_STAGES-1:0]                           raw_stage_sel;
    logic [NUM_STAGES-1:0][TW_ADDR_WIDTH-1:0]        raw_stage_tw_addr;

    // Pipeline Valid Shift Register
    logic [PIPELINE_LAT-1:0]                         valid_pipe;

    // =========================================================================
    // 1. Core Enable & Flush Logic
    // =========================================================================
    assign flushing = (flush_cnt != '0);
    assign core_en  = clk_en && (valid_in || flushing);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt       <= '0;
            flush_cnt <= '0;
        end else if (clk_en) begin
            if (valid_in) begin
                cnt <= cnt + 1'b1;
                if (cnt == NUM_STAGES'(N - 1)) begin
                    flush_cnt <= FLUSH_WIDTH'(PIPELINE_LAT);
                end
            end else if (flushing) begin
                if (flush_cnt == FLUSH_WIDTH'(1)) begin
                    cnt       <= '0;
                    flush_cnt <= '0;
                end else begin
                    cnt       <= cnt + 1'b1;
                    flush_cnt <= flush_cnt - 1'b1;
                end
            end
        end
    end

    // =========================================================================
    // 2. Raw Stage Steering & Twiddle Address Decoders
    // =========================================================================
    generate
        for (genvar s = 0; s < NUM_STAGES; s++) begin : gen_raw_ctrl
            // Steering selector alternates with period 2 * DELAY_DEPTH
            assign raw_stage_sel[s] = cnt[NUM_STAGES - 1 - s];

            if (s < NUM_STAGES - 2) begin : gen_mult_tw
                // Multiplier stages: cnt[NUM_STAGES - 2 - s : 0] shifted left by s
                assign raw_stage_tw_addr[s] = (TW_ADDR_WIDTH'(cnt[NUM_STAGES - 2 - s : 0])) << s;
            end else if (s == NUM_STAGES - 2) begin : gen_trivial_tw
                // Penultimate stage: W4 trivial twiddle controlled by cnt[0]
                assign raw_stage_tw_addr[s] = TW_ADDR_WIDTH'(cnt[0]);
            end else begin : gen_final_tw
                // Final stage: Multiplier-free wire pass-through
                assign raw_stage_tw_addr[s] = '0;
            end
        end
    endgenerate

    // =========================================================================
    // 3. Inter-Stage Control Skew Pipeline Registers
    //    Stage s receives data delayed by STAGE_SKEW(s) cycles; control signals
    //    are delayed by the exact same amount to maintain strict synchronization.
    // =========================================================================
    generate
        for (genvar s = 0; s < NUM_STAGES; s++) begin : gen_skew_pipe
            localparam int MULT_BEFORE = (s < (NUM_STAGES - 2)) ? s : ((NUM_STAGES > 2) ? (NUM_STAGES - 2) : 0);
            localparam int SKEW_CYCLES = s + MULT_BEFORE * MULT_PIPE_STAGES;

            if (SKEW_CYCLES == 0) begin : gen_no_skew
                assign stage_sel[s]     = raw_stage_sel[s];
                assign stage_tw_addr[s] = raw_stage_tw_addr[s];
            end else begin : gen_with_skew
                logic [SKEW_CYCLES-1:0]                    sel_pipe;
                logic [SKEW_CYCLES-1:0][TW_ADDR_WIDTH-1:0] tw_pipe;

                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        sel_pipe <= '0;
                        for (int i = 0; i < SKEW_CYCLES; i++) begin
                            tw_pipe[i] <= '0;
                        end
                    end else if (core_en) begin
                        sel_pipe[0] <= raw_stage_sel[s];
                        tw_pipe[0]  <= raw_stage_tw_addr[s];
                        for (int i = 1; i < SKEW_CYCLES; i++) begin
                            sel_pipe[i] <= sel_pipe[i-1];
                            tw_pipe[i]  <= tw_pipe[i-1];
                        end
                    end
                end

                assign stage_sel[s]     = sel_pipe[SKEW_CYCLES-1];
                assign stage_tw_addr[s] = tw_pipe[SKEW_CYCLES-1];
            end
        end
    endgenerate

    // =========================================================================
    // 4. Valid Pipeline Shift Register
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipe <= '0;
        end else if (core_en) begin
            valid_pipe <= {valid_pipe[PIPELINE_LAT-2:0], valid_in};
        end
    end

    assign valid_out = valid_pipe[PIPELINE_LAT-1];

endmodule : fft_controller
