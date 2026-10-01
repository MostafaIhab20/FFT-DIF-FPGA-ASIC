// =============================================================================
// File Name      : bit_sync.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-01
// Version        : 1.0
// Description    : Parameterized multi-stage flip-flop synchronizer with ASYNC_REG
//                  attribute for Clock Domain Crossing (CDC) of level signals
//                  and Gray-coded pointers.
// =============================================================================

module bit_sync #(
    parameter int WIDTH  = 1,
    parameter int STAGES = 2
)(
    input  logic             clk,
    input  logic             rst_n, // Destination-domain active-low reset
    input  logic [WIDTH-1:0] d,     // Asynchronous input from source domain
    output logic [WIDTH-1:0] q      // Synchronized output in destination domain
);

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================
    (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] sync_q [STAGES];

    // =========================================================================
    // Multi-Stage Synchronizer Shift Register
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < STAGES; i++) begin
                sync_q[i] <= '0;
            end
        end else begin
            sync_q[0] <= d;
            for (int i = 1; i < STAGES; i++) begin
                sync_q[i] <= sync_q[i-1];
            end
        end
    end

    assign q = sync_q[STAGES-1];

endmodule : bit_sync
