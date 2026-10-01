// =============================================================================
// File Name      : addr_decoder.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-01
// Version        : 1.0
// Description    : Combinational address decoder routing AHB register bus transfers
//                  to either the register file (0x000-0x0FF) or the FIFO data
//                  window (0x100-0x1FF) with strict bus error detection.
// =============================================================================

import ip_regs_pkg::*;

module addr_decoder #(
    parameter int ADDR_W = 32
)(
    // Simple Register Bus Input from AHB Slave
    input  logic [ADDR_W-1:0] bus_addr,
    input  logic              bus_write,
    input  logic [31:0]       bus_wdata,
    input  logic              bus_wr_en,
    input  logic              bus_rd_en,
    output logic [31:0]       bus_rdata,
    output logic              bus_err,

    // Register File Interface
    output logic [5:0]        reg_addr,
    output logic              reg_wr_en,
    output logic [31:0]       reg_wdata,
    input  logic [31:0]       reg_rdata,

    // Asynchronous IN FIFO Host Interface (Write Port)
    output logic              in_push,
    output logic [31:0]       in_wdata,

    // Asynchronous OUT FIFO Host Interface (Read Port)
    output logic              out_pop,
    input  logic [31:0]       out_rdata,
    input  logic              out_empty
);

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================
    logic [11:0] off;
    logic        is_reg;
    logic        is_win;
    logic        reg_valid;
    logic        reg_wr_ok;

    // =========================================================================
    // 1. Address Region Classification
    // =========================================================================
    assign off      = bus_addr[11:0];
    assign is_reg   = (off[11:8] == 4'h0);
    assign is_win   = (off[11:8] == 4'h1);
    assign reg_addr = off[7:2];

    // =========================================================================
    // 2. Register Access Validity & Permission Checking
    // =========================================================================
    assign reg_valid = is_reg && (reg_addr <= R_OUT_THRESH);
    assign reg_wr_ok = (reg_addr == R_CTRL)       ||
                       (reg_addr == R_INT_EN)     ||
                       (reg_addr == R_INT_STATUS) ||
                       (reg_addr == R_IN_THRESH)  ||
                       (reg_addr == R_OUT_THRESH);

    // Error on unmapped address, or write to read-only register
    assign bus_err = !(is_win || reg_valid) || (bus_write && is_reg && !reg_wr_ok);

    // =========================================================================
    // 3. Register File and FIFO Steering Strobes
    // =========================================================================
    assign reg_wr_en = bus_wr_en & is_reg;
    assign reg_wdata = bus_wdata;

    assign in_push   = bus_wr_en & is_win;
    assign in_wdata  = bus_wdata;
    assign out_pop   = bus_rd_en & is_win;

    // Reading an empty OUT FIFO returns 0 (and raises the underflow event)
    assign bus_rdata = is_win ? (out_empty ? 32'h0 : out_rdata) : reg_rdata;

endmodule : addr_decoder
