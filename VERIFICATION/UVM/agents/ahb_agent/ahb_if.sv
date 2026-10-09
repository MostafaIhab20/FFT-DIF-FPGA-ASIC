// =============================================================================
// File Name      : ahb_if.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : SystemVerilog interface for AHB-Lite protocol verification.
//                  Includes clocking blocks, modports, and formal SVA checks.
// =============================================================================

`timescale 1ns/1ps

`ifndef AHB_IF_SV
`define AHB_IF_SV

interface ahb_if #(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 32
)(
    input logic HCLK,
    input logic HRESETn
);

    // ==================================================
    // AHB-Lite Bus Signals
    // ==================================================
    logic              HSEL;
    logic [ADDR_W-1:0] HADDR;
    logic [1:0]        HTRANS;
    logic [2:0]        HBURST;
    logic              HWRITE;
    logic [2:0]        HSIZE;
    logic [DATA_W-1:0] HWDATA;
    logic              HREADY;
    logic              HREADYOUT;
    logic [DATA_W-1:0] HRDATA;
    logic              HRESP;
    bit                enable_alignment_check = 1'b1;

    // ==================================================
    // Driver Clocking Block
    // ==================================================
    clocking drv_cb @(posedge HCLK);
        default input #1step output #1ns;
        output HSEL;
        output HADDR;
        output HTRANS;
        output HBURST;
        output HWRITE;
        output HSIZE;
        output HWDATA;
        input  HREADY;
        input  HREADYOUT;
        input  HRDATA;
        input  HRESP;
    endclocking

    // ==================================================
    // Monitor Clocking Block
    // ==================================================
    clocking mon_cb @(posedge HCLK);
        default input #1step;
        input HSEL;
        input HADDR;
        input HTRANS;
        input HBURST;
        input HWRITE;
        input HSIZE;
        input HWDATA;
        input HREADY;
        input HREADYOUT;
        input HRDATA;
        input HRESP;
    endclocking

    // ==================================================
    // Interface Modports
    // ==================================================
    modport master_mp (
        clocking drv_cb,
        input    HCLK,
        input    HRESETn
    );

    modport monitor_mp (
        clocking mon_cb,
        input    HCLK,
        input    HRESETn
    );

    // ==================================================
    // Protocol Assertions (SVA)
    // ==================================================
    // Address and control signals must remain stable during wait states
    property p_addr_ctrl_stable_during_wait;
        @(posedge HCLK) disable iff (!HRESETn)
        (HSEL && HTRANS[1] && !HREADYOUT) |=> 
            ($stable(HADDR) && $stable(HTRANS) && $stable(HBURST) && $stable(HWRITE) && $stable(HSIZE) && $stable(HSEL));
    endproperty
    assert_addr_ctrl_stable: assert property (p_addr_ctrl_stable_during_wait)
        else $error("[SVA-AHB] Address or control signals changed during wait state!");

    // Two-cycle ERROR response verification
    property p_two_cycle_error_response;
        @(posedge HCLK) disable iff (!HRESETn)
        ($rose(HRESP)) |-> (!HREADYOUT ##1 (HRESP && HREADYOUT));
    endproperty
    assert_two_cycle_error: assert property (p_two_cycle_error_response)
        else $error("[SVA-AHB] Two-cycle ERROR response violated (Cycle 1: HREADYOUT=0, Cycle 2: HREADYOUT=1)!");

    // 32-bit Word access address alignment check
    property p_word_aligned_address;
        @(posedge HCLK) disable iff (!HRESETn || !enable_alignment_check)
        (HSEL && HTRANS[1] && (HSIZE == 3'b010)) |-> (HADDR[1:0] == 2'b00);
    endproperty
    assert_word_aligned_addr: assert property (p_word_aligned_address)
        else $error("[SVA-AHB] Word transfer initiated with unaligned address!");

    // Control signal unknown (X/Z) prevention while out of reset
    property p_no_x_on_control;
        @(posedge HCLK) disable iff (!HRESETn)
        !$isunknown({HSEL, HTRANS, HBURST, HWRITE, HSIZE, HREADY});
    endproperty
    assert_no_x_control: assert property (p_no_x_on_control)
        else $error("[SVA-AHB] Unknown value detected on AHB master control signals!");

endinterface : ahb_if

`endif // AHB_IF_SV
