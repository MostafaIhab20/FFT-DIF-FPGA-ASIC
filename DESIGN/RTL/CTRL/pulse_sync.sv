// =============================================================================
// File Name      : pulse_sync.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-01
// Version        : 1.0
// Description    : Single-pulse Clock Domain Crossing (CDC) synchronizer.
//                  Translates a 1-cycle pulse in the source clock domain into a
//                  guaranteed 1-cycle pulse in the destination clock domain using
//                  a toggle flip-flop, 2-stage synchronizer, and edge detector.
// =============================================================================

module pulse_sync #(
    parameter int SYNC_STAGES = 2
)(
    // Source Clock Domain
    input  logic src_clk,
    input  logic src_rst_n,
    input  logic src_pulse,

    // Destination Clock Domain
    input  logic dst_clk,
    input  logic dst_rst_n,
    output logic dst_pulse
);

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================
    logic                     toggle_src;
    logic                     toggle_dst;
    logic                     toggle_dst_dly;
    logic [SYNC_STAGES-1:0]   sync_pipe;

    // =========================================================================
    // 1. Source Domain: Pulse-to-Toggle Generator
    // =========================================================================
    always_ff @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            toggle_src <= 1'b0;
        end else if (src_pulse) begin
            toggle_src <= ~toggle_src;
        end
    end

    // =========================================================================
    // 2. Destination Domain: Multi-Stage Synchronizer
    // =========================================================================
    (* ASYNC_REG = "TRUE" *)
    always_ff @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            sync_pipe <= '0;
        end else begin
            sync_pipe <= {sync_pipe[SYNC_STAGES-2:0], toggle_src};
        end
    end

    assign toggle_dst = sync_pipe[SYNC_STAGES-1];

    // =========================================================================
    // 3. Destination Domain: Edge Detector (Toggle-to-Pulse)
    // =========================================================================
    always_ff @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            toggle_dst_dly <= 1'b0;
        end else begin
            toggle_dst_dly <= toggle_dst;
        end
    end

    // Output pulse generated whenever a transition (0->1 or 1->0) is detected
    assign dst_pulse = toggle_dst ^ toggle_dst_dly;

endmodule : pulse_sync
