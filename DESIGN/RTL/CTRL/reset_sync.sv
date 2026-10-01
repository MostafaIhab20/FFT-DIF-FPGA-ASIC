// =============================================================================
// File Name      : reset_sync.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-01
// Version        : 1.0
// Description    : Asynchronous assert, synchronous deassert active-low reset
//                  synchronizer with ASYNC_REG attribute for safe clock domain crossing.
// =============================================================================

module reset_sync #(
    parameter int STAGES = 2 // Minimum 2 stages recommended for MTBF
)(
    input  logic clk,
    input  logic arst_n,     // Asynchronous active-low reset input
    output logic srst_n      // Synchronous active-low reset output
);

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================
    (* ASYNC_REG = "TRUE" *) logic [STAGES-1:0] q;

    // =========================================================================
    // Reset Synchronizer Shift Register
    // =========================================================================
    always_ff @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            q <= '0;
        end else begin
            q <= {q[STAGES-2:0], 1'b1};
        end
    end

    assign srst_n = q[STAGES-1];

endmodule : reset_sync
