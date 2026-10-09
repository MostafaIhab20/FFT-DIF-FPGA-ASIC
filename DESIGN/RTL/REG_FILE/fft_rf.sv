// =============================================================================
// File Name      : fft_rf.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-01
// Version        : 1.0
// Description    : Register file for the AHB-Lite peripheral subsystem.
//                  Provides memory-mapped control, status, programmable FIFO
//                  watermarks, pure sticky interrupt generation, hardware DMA
//                  mode gating, and error event tracking.
// =============================================================================

//==============================================================================
// Register File
//==============================================================================
// -----------------------------------------------------------------------------
// Register name      |      Address      |  P  | Reset Value | Size |
// -----------------------------------------------------------------------------
// 1)  ID             |   Base + 0x000    | RO  | 0x49500001  |  32  |
//     [31:0]  id [RO]
// 2)  VERSION        |   Base + 0x004    | RO  | 0x00010000  |  24  |
//     [23:16] major [RO]
//     [15:8]  minor [RO]
//     [7:0]   patch [RO]
// 3)  CTRL           |   Base + 0x008    | RW  | 0x0         |   5  |
//     [4]     dma_en [RW]
//     [3]     flush_out [SC]
//     [2]     flush_in [SC]
//     [1]     soft_reset [SC]
//     [0]     enable [RW]
// 4)  STATUS         |   Base + 0x00C    | RO  | 0x2A        |   7  |
//     [6]     out_almost_full [RO]
//     [5]     in_almost_empty [RO]
//     [4]     out_full [RO]
//     [3]     out_empty [RO]
//     [2]     in_full [RO]
//     [1]     in_empty [RO]
//     [0]     busy [RO]
// 5)  INT_EN         |   Base + 0x010    | RW  | 0x00        |   3  |
//     [2]     out_underflow [RW]
//     [1]     in_overflow [RW]
//     [0]     frame_done [RW]
// 6)  INT_STATUS     |   Base + 0x014    | RO* | 0x00        |   3  |
//     [2]     out_underflow [W1C]
//     [1]     in_overflow [W1C]
//     [0]     frame_done [W1C]
// 7)  IN_LEVEL       |   Base + 0x018    | RO  | 0x0000      |  16  |
//     [15:0]  in_level [RO]
// 8)  OUT_LEVEL      |   Base + 0x01C    | RO  | 0x0000      |  16  |
//     [15:0]  out_level [RO]
// 9)  IN_THRESH      |   Base + 0x020    | RW  | IN_DEPTH/4  |  16  |
//     [15:0]  in_thresh [RW]
// 10) OUT_THRESH     |   Base + 0x024    | RW  |OUT_DEPTH*3/4|  16  |
//     [15:0]  out_thresh [RW]
// 11) FIFO_DATA      | Base + 0x100-0x1FF| WR  | -           |  32  |
//     [31:0]  fifo_data [WR]
// --------------------------------------------------------------
// Access Rights:
//   RO  = Read-Only
//   RW  = Read/Write
//   RO* = Read-Only status with Write-1-to-Clear (W1C) sticky flags
//   WR  = Write pushes to IN FIFO, Read pops from OUT FIFO
//   SC  = Self-Clearing strobe bit
//
// Key Formulas & Flow Control:
//   irq        = |(INT_STATUS[2:0] & INT_EN[2:0])
//   dma_rx_req = enable & dma_en & (IN_LEVEL <= IN_THRESH)
//   dma_tx_req = dma_en & (OUT_LEVEL >= OUT_THRESH)
//   HRESP      = Asserted on write to RO registers or unmapped addresses
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
    input  logic              rst_active,       // From reset controller (active reset hold)
    input  logic              ip_busy,          // From IP core (synchronized to HCLK)
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
    // Control and DMA Mode Configuration
    logic             dma_en;

    // Interrupt Enable Mask & Sticky Flags
    logic [2:0]       int_en;
    logic             sticky_frame_done;
    logic             sticky_ovf;
    logic             sticky_unf;

    // Programmable FIFO Watermark Thresholds
    logic [LVL_W-1:0] in_thresh;
    logic [LVL_W-1:0] out_thresh;

    // Live Status & Threshold Detection Flags
    logic             busy;
    logic             in_empty;
    logic             out_full;
    logic             in_almost_empty;
    logic             out_almost_full;

    // Packed 32-bit Status Registers
    logic [31:0]      status;
    logic [31:0]      int_status;

    // Internal Write Decode Helpers
    logic             ctrl_wr;
    logic             any_req;

    // =========================================================================
    // Status, DMA Requests, & Interrupt 
    // =========================================================================
    assign busy            = rst_active | (in_level != '0) | ip_busy;
    assign in_empty        = (in_level == '0);
    assign out_full        = (out_level == LVL_W'(OUT_DEPTH));
    assign in_almost_empty = (in_level  <= in_thresh);
    assign out_almost_full = (out_level >= out_thresh);

    // DMA Handshaking Flow Control (Gated by enable and dma_en)
    assign dma_rx_req      = enable & dma_en & in_almost_empty;
    assign dma_tx_req      = dma_en & out_almost_full;

    // Live Peripheral Status Register
    assign status     = {25'b0, out_almost_full, in_almost_empty, out_full,
                         out_empty, in_full, in_empty, busy};

    // Purely Sticky (W1C) Interrupt Status Register
    assign int_status = {29'b0, sticky_unf, sticky_ovf, sticky_frame_done};

    // Masked interrupt generation across the 3 event sources
    assign irq = |(int_status[2:0] & int_en);

    // =========================================================================
    // Synchronous Register Write Logic
    // =========================================================================
    assign ctrl_wr = reg_wr_en && (reg_addr == R_CTRL);
    assign any_req = ctrl_wr && (reg_wdata[CTRL_SOFT_RESET] | reg_wdata[CTRL_FLUSH_IN] | reg_wdata[CTRL_FLUSH_OUT]);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            enable            <= 1'b0;
            dma_en            <= 1'b0;
            soft_reset_req    <= 1'b0;
            flush_in_req      <= 1'b0;
            flush_out_req     <= 1'b0;
            int_en            <= '0;
            in_thresh         <= LVL_W'(IN_DEPTH / 4);
            out_thresh        <= LVL_W'((OUT_DEPTH * 3) / 4);
            sticky_frame_done <= 1'b0;
            sticky_ovf        <= 1'b0;
            sticky_unf        <= 1'b0;
        end else begin
            // Generate single-cycle reset/flush pulses
            soft_reset_req <= ctrl_wr & reg_wdata[CTRL_SOFT_RESET];
            flush_in_req   <= ctrl_wr & reg_wdata[CTRL_FLUSH_IN];
            flush_out_req  <= ctrl_wr & reg_wdata[CTRL_FLUSH_OUT];

            // Enable and DMA mode control (cleared automatically on any reset request)
            if (ctrl_wr) begin
                enable <= reg_wdata[CTRL_ENABLE];
                dma_en <= reg_wdata[CTRL_DMA_EN];
            end
            if (any_req) begin
                enable <= 1'b0;
                dma_en <= 1'b0;
            end

            // Programmable register writes
            if (reg_wr_en) begin
                case (reg_addr)
                    R_INT_EN:     int_en     <= reg_wdata[2:0];
                    R_IN_THRESH:  in_thresh  <= reg_wdata[LVL_W-1:0];
                    R_OUT_THRESH: out_thresh <= reg_wdata[LVL_W-1:0];
                    default: ;
                endcase
            end

            // Write-1-to-Clear (W1C) sticky error & frame-done flags (hardware set wins over clear)
            if (reg_wr_en && (reg_addr == R_INT_STATUS)) begin
                if (reg_wdata[0]) sticky_frame_done <= 1'b0;
                if (reg_wdata[1]) sticky_ovf        <= 1'b0;
                if (reg_wdata[2]) sticky_unf        <= 1'b0;
            end
            if (ev_frame_done)    sticky_frame_done <= 1'b1;
            if (ev_in_overflow)   sticky_ovf        <= 1'b1;
            if (ev_out_underflow) sticky_unf        <= 1'b1;
        end
    end

    // =========================================================================
    // Combinational Register Read Logic
    // =========================================================================
    always_comb begin
        case (reg_addr)
            R_ID:         reg_rdata = ID;
            R_VERSION:    reg_rdata = VERSION;
            R_CTRL:       reg_rdata = {30'b0, dma_en, enable};
            R_STATUS:     reg_rdata = status;
            R_INT_EN:     reg_rdata = {29'b0, int_en};
            R_INT_STATUS: reg_rdata = int_status;
            R_IN_LEVEL:   reg_rdata = 32'(in_level);
            R_OUT_LEVEL:  reg_rdata = 32'(out_level);
            R_IN_THRESH:  reg_rdata = 32'(in_thresh);
            R_OUT_THRESH: reg_rdata = 32'(out_thresh);
            default:      reg_rdata = 32'h0;
        endcase
    end

endmodule : reg_file