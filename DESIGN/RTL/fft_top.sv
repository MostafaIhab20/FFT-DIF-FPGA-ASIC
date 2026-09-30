// =============================================================================
// File Name      : fft_top.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-09-28
// Version        : 1.0
// Description    : Parameterized Top-level Core for N-Point Radix-2 Decimation-in-Frequency (DIF)
//                  Single-Path Delay Feedback (R2SDF) FFT.
//                  Supports arbitrary power-of-2 N (e.g., 8, 16, 32, 64, 128, ...).
//                  Key Characteristics:
//                    - Arithmetic: 16-bit Signed Fixed-Point Q1.15
//                    - Scaling   : Divide-by-2 per stage (total 1/N scaling, 0 bit growth)
//                    - Throughput: 1 complex sample / clock continuous streaming (100% duty)
//                    - Latency   : Exactly (N - 1) + log2(N) + (log2(N) - 2)*MULT_PIPE_STAGES + 1 cycles
//                    - Pipelining: Registered inputs, inter-stage registers, registered outputs,
//                                  and parameterized internal multiplier pipelining (MULT_PIPE_STAGES)
//                    - Resources : log2(N) Butterfly PEs, log2(N)-2 Complex Multipliers, N-1 Delay Regs
//                    - Output    : Bit-reversed frequency bins (hardware standard DIF)
// =============================================================================

import fft_pkg::*;

module fft_top #(
    parameter int N                = 32,
    parameter int MULT_PIPE_STAGES = 0
)(
    input  logic                            clk,
    input  logic                            rst_n,
    input  logic                            valid_in,
    input  logic signed [DATA_WIDTH-1:0]    in_data_re,
    input  logic signed [DATA_WIDTH-1:0]    in_data_im,
    output logic                            valid_out,
    output logic signed [DATA_WIDTH-1:0]    out_data_re,
    output logic signed [DATA_WIDTH-1:0]    out_data_im
);

    // =========================================================================
    // Architectural Constants
    // =========================================================================
    localparam int NUM_STAGES    = $clog2(N);
    localparam int TW_ADDR_WIDTH = (N <= 4) ? 1 : (NUM_STAGES - 1);

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================
    // Input Boundary Registers
    complex_t                                        in_FF;
    logic                                            valid_in_FF;

    // Controller Interconnects
    logic                                            core_en;
    logic [NUM_STAGES-1:0]                           stage_sel;
    logic [NUM_STAGES-1:0][TW_ADDR_WIDTH-1:0]        stage_tw_addr;

    // Inter-Stage Data Interconnects
    complex_t                                        stage_data [0:NUM_STAGES];

    // =========================================================================
    // Input Register
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_FF.re    <= '0;
            in_FF.im    <= '0;
            valid_in_FF <= 1'b0;
        end else begin
            valid_in_FF <= valid_in;
            if (valid_in) begin
                in_FF.re <= in_data_re;
                in_FF.im <= in_data_im;
            end else if (core_en) begin
                in_FF.re <= '0;
                in_FF.im <= '0;
            end
        end
    end

    // Feed Registered Input to Stage 0
    assign stage_data[0] = (valid_in_FF) ? in_FF : '{re: '0, im: '0};

    // =========================================================================
    // Controller
    // =========================================================================
    fft_controller #(
        .N                (N),
        .MULT_PIPE_STAGES (MULT_PIPE_STAGES)
    ) u_controller (
        .clk           (clk),
        .rst_n         (rst_n),
        .valid_in      (valid_in_FF),
        .stage_sel     (stage_sel),
        .stage_tw_addr (stage_tw_addr),
        .core_en       (core_en),
        .valid_out     (valid_out)
    );

    // =========================================================================
    // N Pipeline Stages
    // =========================================================================
    generate
        for (genvar s = 0; s < NUM_STAGES; s++) begin : gen_stages
            localparam int DELAY_DEPTH   = N / (2**(s + 1));
            localparam int HAS_MULT      = (s < NUM_STAGES - 2) ? 1 : 0;
            localparam int IS_W4_STAGE   = (s == NUM_STAGES - 2) ? 1 : 0;

            fft_stage #(
                .N                (N),
                .DELAY_DEPTH      (DELAY_DEPTH),
                .TW_ADDR_WIDTH    (TW_ADDR_WIDTH),
                .HAS_MULTIPLIER   (HAS_MULT),
                .IS_W4_STAGE      (IS_W4_STAGE),
                .MULT_PIPE_STAGES (MULT_PIPE_STAGES)
            ) u_stage (
                .clk       (clk),
                .rst_n     (rst_n),
                .en        (core_en),
                .sel       (stage_sel[s]),
                .tw_addr   (stage_tw_addr[s]),
                .stage_in  (stage_data[s]),
                .stage_out (stage_data[s+1])
            );
        end
    endgenerate

    // =========================================================================
    // Output Unpacking 
    // =========================================================================
    assign out_data_re = stage_data[NUM_STAGES].re;
    assign out_data_im = stage_data[NUM_STAGES].im;

endmodule : fft_top
