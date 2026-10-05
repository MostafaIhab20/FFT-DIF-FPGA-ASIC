// =============================================================================
// File Name      : fft_sys_ctrl.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-01
// Version        : 1.0
// Description    : Stream flow controller in the IP clock domain interfacing
//                  between asynchronous FIFOs and the streaming IP core.
//                  Includes in-flight sample counter and backpressure handling.
// =============================================================================

module fft_sys_ctrl #(
    parameter int DATA_W = 32,
    parameter int CNT_W  = 16
)(
    input  logic              clk,
    input  logic              rst_n,          // ip_clk-domain synchronized reset

    input  logic              enable,         // Enable signal from HCLK domain

    // Asynchronous IN FIFO Read Side (FWFT Interface)
    input  logic              in_empty,
    input  logic [DATA_W-1:0] in_rdata,
    output logic              in_pop,

    // Asynchronous OUT FIFO Write Side
    input  logic              out_full,
    output logic              out_push,
    output logic [DATA_W-1:0] out_wdata,

    // Streaming IP Core Interface
    output logic              ip_ce,
    output logic              ip_valid_in,
    output logic [DATA_W-1:0] ip_data_in,
    input  logic              ip_valid_out,
    input  logic [DATA_W-1:0] ip_data_out,

    // Status Output
    output logic              busy            // High while samples are in flight within the IP
);

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================
    logic             enable_s;
    logic [CNT_W-1:0] inflight;

    // =========================================================================
    // Enable Synchronization (HCLK -> ip_clk Domain)
    // =========================================================================
    bit_sync #(
        .WIDTH (1)
    ) u_en_sync (
        .clk   (clk),
        .rst_n (rst_n),
        .d     (enable),
        .q     (enable_s)
    );

    // =========================================================================
    // IP Streaming Flow Control
    // =========================================================================
    // Clock enable reflects downstream backpressure (stalls when OUT FIFO is full)
    assign ip_ce       = ~out_full;
    assign ip_valid_in = enable_s & ~in_empty;
    assign ip_data_in  = in_rdata;
    assign in_pop      = ip_ce & ip_valid_in;

    assign out_push    = ip_ce & ip_valid_out;
    assign out_wdata   = ip_data_out;

    // =========================================================================
    // Sample Counter
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            inflight <= '0;
        end else begin
            case ({in_pop, out_push})
                2'b10:   inflight <= inflight + 1'b1;
                2'b01:   inflight <= inflight - 1'b1;
                default: ; // Both active or neither active: no net change
            endcase
        end
    end

    // Core is busy if any samples remain in flight within the pipeline
    assign busy = (inflight != '0);

endmodule : fft_sys_ctrl
