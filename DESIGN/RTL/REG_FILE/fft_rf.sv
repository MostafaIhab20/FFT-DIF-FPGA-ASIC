// =============================================================================
// File Name      : fft_rf.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-01
// Version        : 1.0
// Description    : Register file for the AHB-Lite peripheral subsystem.
//                  Provides memory-mapped control, status, programmable FIFO
//                  watermarks, interrupt generation (including frame_done),
//                  hardware DMA flow control handshakes, and sticky error tracking.
// =============================================================================

import ip_regs_pkg::*;

module reg_file #(
    parameter logic [31:0] ID        = 32'h4950_0001,
    parameter logic [31:0] VERSION   = 32'h0001_0000,
    parameter int          LVL_W     = 16,
    parameter int          IN_DEPTH  = 64,
    parameter int          OUT_DEPTH = 64
)(
    input  logic              clk,
    input  logic              rst_n,

    // Simple Register Bus Interface
    input  logic [5:0]        reg_addr,
    input  logic              reg_wr_en,
    input  logic [31:0]       reg_wdata,
    output logic [31:0]       reg_rdata,

    // Status Inputs from Core & FIFOs
    input  logic              busy,
    input  logic              in_full,
    input  logic              out_empty,
    input  logic [LVL_W-1:0]  in_level,
    input  logic [LVL_W-1:0]  out_level,
    input  logic              ev_in_overflow,   // Pulse: push attempted while IN FIFO full
    input  logic              ev_out_underflow, // Pulse: pop attempted while OUT FIFO empty
    input  logic              ev_frame_done,    // Pulse: complete FFT frame output emitted

    // Control Outputs to Reset Controller & Core
    output logic              enable,
    output logic              soft_reset_req,   // 1-cycle strobe
    output logic              flush_in_req,     // 1-cycle strobe
    output logic              flush_out_req,    // 1-cycle strobe
    output logic              irq,

    // Hardware DMA Handshake Interface
    output logic              dma_rx_req,       // Request DMA to push data into IN FIFO
    output logic              dma_tx_req        // Request DMA to pull data from OUT FIFO
);

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================
    // Configuration & Threshold Registers
    logic [7:0]       int_en;
    logic             sticky_ovf;
    logic             sticky_unf;
    logic             sticky_frame_done;
    logic [LVL_W-1:0] in_thresh;
    logic [LVL_W-1:0] out_thresh;

    // Live Status & Threshold Detection Flags
    logic             in_empty;
    logic             out_full;
    logic             in_almost_empty;
    logic             out_almost_full;
    logic             out_not_empty;

    // Packed 32-bit Status Registers
    logic [31:0]      status;
    logic [31:0]      int_status;

    // Internal Write Decode Helpers
    logic             ctrl_wr;
    logic             any_req;

    // =========================================================================
    // 1. Live Status, DMA Requests, & Interrupt Vector Assembly
    // =========================================================================
    assign in_empty        = (in_level == '0);
    assign out_full        = (out_level == LVL_W'(OUT_DEPTH));
    assign in_almost_empty = (in_level  <= in_thresh);
    assign out_almost_full = (out_level >= out_thresh);
    assign out_not_empty   = ~out_empty;

    // DMA Handshaking Flow Control
    assign dma_rx_req      = enable & in_almost_empty;
    assign dma_tx_req      = out_almost_full;

    assign status     = {25'b0, out_almost_full, in_almost_empty, out_full,
                         out_empty, in_full, in_empty, busy};

    assign int_status = {24'b0, sticky_frame_done, sticky_unf, sticky_ovf, out_full,
                         in_empty, in_almost_empty, out_not_empty, out_almost_full};

    // Masked interrupt generation across all 8 interrupt sources
    assign irq = |(int_status[7:0] & int_en);

    // =========================================================================
    // 2. Synchronous Register Write Logic
    // =========================================================================
    assign ctrl_wr = reg_wr_en && (reg_addr == R_CTRL);
    assign any_req = ctrl_wr && (reg_wdata[1] | reg_wdata[2] | reg_wdata[3]);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            enable            <= 1'b0;
            soft_reset_req    <= 1'b0;
            flush_in_req      <= 1'b0;
            flush_out_req     <= 1'b0;
            int_en            <= '0;
            in_thresh         <= LVL_W'(IN_DEPTH / 4);
            out_thresh        <= LVL_W'((OUT_DEPTH * 3) / 4);
            sticky_ovf        <= 1'b0;
            sticky_unf        <= 1'b0;
            sticky_frame_done <= 1'b0;
        end else begin
            // Generate single-cycle reset/flush pulses
            soft_reset_req <= ctrl_wr & reg_wdata[1];
            flush_in_req   <= ctrl_wr & reg_wdata[2];
            flush_out_req  <= ctrl_wr & reg_wdata[3];

            // Enable bit control (cleared automatically on any reset request)
            if (ctrl_wr) enable <= reg_wdata[0];
            if (any_req) enable <= 1'b0;

            // Programmable register writes
            if (reg_wr_en) begin
                case (reg_addr)
                    R_INT_EN:     int_en     <= reg_wdata[7:0];
                    R_IN_THRESH:  in_thresh  <= reg_wdata[LVL_W-1:0];
                    R_OUT_THRESH: out_thresh <= reg_wdata[LVL_W-1:0];
                    default: ;
                endcase
            end

            // Write-1-to-Clear (W1C) sticky error & frame-done flags (hardware set wins over clear)
            if (reg_wr_en && (reg_addr == R_INT_STATUS)) begin
                if (reg_wdata[5]) sticky_ovf        <= 1'b0;
                if (reg_wdata[6]) sticky_unf        <= 1'b0;
                if (reg_wdata[7]) sticky_frame_done <= 1'b0;
            end
            if (ev_in_overflow)   sticky_ovf        <= 1'b1;
            if (ev_out_underflow) sticky_unf        <= 1'b1;
            if (ev_frame_done)    sticky_frame_done <= 1'b1;
        end
    end

    // =========================================================================
    // 3. Combinational Register Read Multiplexer
    // =========================================================================
    always_comb begin
        case (reg_addr)
            R_ID:         reg_rdata = ID;
            R_VERSION:    reg_rdata = VERSION;
            R_CTRL:       reg_rdata = {31'b0, enable};
            R_STATUS:     reg_rdata = status;
            R_INT_EN:     reg_rdata = {24'b0, int_en};
            R_INT_STATUS: reg_rdata = int_status;
            R_IN_LEVEL:   reg_rdata = 32'(in_level);
            R_OUT_LEVEL:  reg_rdata = 32'(out_level);
            R_IN_THRESH:  reg_rdata = 32'(in_thresh);
            R_OUT_THRESH: reg_rdata = 32'(out_thresh);
            default:      reg_rdata = 32'h0;
        endcase
    end

endmodule : reg_file