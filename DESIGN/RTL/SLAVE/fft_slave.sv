// =============================================================================
// File Name      : fft_slave.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-01
// Version        : 1.0
// Description    : Zero-wait-state AHB-Lite slave protocol interface.
//                  Translates AHB address and data phases into a simple,
//                  demultiplexed internal register bus with 2-cycle ERROR responses.
// =============================================================================

module ahb_slave #(
    parameter int ADDR_W = 32
)(
    input  logic              HCLK,
    input  logic              HRESETn,

    // AHB-Lite Slave Bus Interface
    input  logic              HSEL,
    input  logic [ADDR_W-1:0] HADDR,
    input  logic [1:0]        HTRANS,
    input  logic              HWRITE,
    input  logic [2:0]        HSIZE,
    input  logic [31:0]       HWDATA,
    input  logic              HREADY,      // System-level bus ready
    output logic              HREADYOUT,
    output logic [31:0]       HRDATA,
    output logic              HRESP,       // Bus transfer response (OKAY / ERROR)

    // Simple Internal Register Bus Interface
    output logic [ADDR_W-1:0] bus_addr,
    output logic              bus_write,
    output logic [31:0]       bus_wdata,
    output logic              bus_wr_en,
    output logic              bus_rd_en,
    input  logic [31:0]       bus_rdata,
    input  logic              bus_err
);

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================
    // Registered Address Phase State
    logic              d_valid;
    logic              d_write;
    logic [2:0]        d_size;
    logic [ADDR_W-1:0] d_addr;

    // Error Handling State
    logic              err_ph2; // Second cycle of 2-cycle AHB ERROR response
    logic              size_bad;
    logic              err_now;

    // Bus Access Enable
    logic              access;

    // =========================================================================
    // Address Phase Capture
    // =========================================================================
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            d_valid <= 1'b0;
            d_write <= 1'b0;
            d_size  <= '0;
            d_addr  <= '0;
        end else if (HREADY) begin
            // Sample active transfer on NONSEQ (2'b10) or SEQ (2'b11)
            d_valid <= HSEL & HTRANS[1];
            d_write <= HWRITE;
            d_size  <= HSIZE;
            d_addr  <= HADDR;
        end
    end

    // =========================================================================
    // Error Response Logic
    // =========================================================================
    // Restrict access strictly to 32-bit aligned words (HSIZE == 2, HADDR[1:0] == 00)
    assign size_bad = (d_size != 3'b010) || (d_addr[1:0] != 2'b00);

    // Error detected during data phase (Cycle 1 of error response)
    assign err_now  = d_valid & ~err_ph2 & (size_bad | bus_err);

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            err_ph2 <= 1'b0;
        end else begin
            err_ph2 <= err_now;
        end
    end

    // AHB-Lite Two-Cycle Error Response:
    // Cycle 1: HREADYOUT = 0, HRESP = 1
    // Cycle 2: HREADYOUT = 1, HRESP = 1
    assign HREADYOUT = ~err_now;
    assign HRESP     = err_now | err_ph2;

    // =========================================================================
    // Simple Register Bus Outputs
    // =========================================================================
    assign access    = d_valid & ~err_now & ~err_ph2;

    assign bus_addr  = d_addr;
    assign bus_write = d_write;
    assign bus_wdata = HWDATA;
    assign bus_wr_en = access &  d_write;
    assign bus_rd_en = access & ~d_write;
    assign HRDATA    = bus_rdata;

endmodule : ahb_slave
