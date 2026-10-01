// =============================================================================
// File Name      : rst_ctrl.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-01
// Version        : 1.0
// Description    : Synchronous reset sequencer and controller in the HCLK domain.
//                  Generates glitch-free, synchronized active-low resets for the
//                  IN FIFO, OUT FIFO, and IP core upon software reset or flush requests.
// =============================================================================

module rst_ctrl #(
    parameter int HOLD = 16 // Reset duration in HCLK clock cycles
)(
    input  logic clk,
    input  logic rst_n,
    input  logic req_soft,      // Full soft reset request
    input  logic req_flush_in,  // Flush IN FIFO + IP core request
    input  logic req_flush_out, // Flush OUT FIFO + IP core request
    output logic in_rst_n,      // Active-low reset for IN FIFO (HCLK domain)
    output logic out_rst_n,     // Active-low reset for OUT FIFO (HCLK domain)
    output logic ip_rst_n,      // Active-low reset for IP core (HCLK domain)
    output logic active         // High while reset sequencing is in progress
);

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================
    logic [$clog2(HOLD+1)-1:0] cnt;

    // =========================================================================
    // Reset Sequencing Logic
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_rst_n  <= 1'b0;
            out_rst_n <= 1'b0;
            ip_rst_n  <= 1'b0;
            cnt       <= '0;
        end else if (req_soft | req_flush_in | req_flush_out) begin
            ip_rst_n <= 1'b0;
            if (req_soft | req_flush_in)  in_rst_n  <= 1'b0;
            if (req_soft | req_flush_out) out_rst_n <= 1'b0;
            cnt <= HOLD;
        end else if (cnt != 0) begin
            cnt <= cnt - 1'b1;
        end else begin
            in_rst_n  <= 1'b1;
            out_rst_n <= 1'b1;
            ip_rst_n  <= 1'b1;
        end
    end

    // Active status flag: high while any reset output is held low
    assign active = ~(in_rst_n & out_rst_n & ip_rst_n);

endmodule : rst_ctrl
