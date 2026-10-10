// =============================================================================
// File Name      : fft_top_uvm.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Top-level SystemVerilog UVM testbench module for top_wrapper.
//                  Instantiates clocks, asynchronous resets, protocol interfaces,
//                  DUT subsystem, and kicks off UVM test phases.
// =============================================================================

`timescale 1ns/1ps

// ==================================================
// Package Imports & Macros
// ==================================================
import uvm_pkg::*;
`include "uvm_macros.svh"

import ahb_types_pkg::*;
import ahb_agent_pkg::*;
import sideband_agent_pkg::*;
import fft_env_pkg::*;
import fft_test_pkg::*;

module tb_top_uvm;

    // ==================================================
    // Clock & Reset Signals
    // ==================================================
    logic HCLK;
    logic ip_clk;
    logic HRESETn;

    // Clock Generation
    initial begin
        HCLK = 0;
        forever #5.0 HCLK = ~HCLK;     // 100 MHz AHB bus clock
    end

    initial begin
        ip_clk = 0;
        forever #3.5 ip_clk = ~ip_clk; // ~143 MHz asynchronous IP core clock
    end

    // Reset Generation
    initial begin
        HRESETn = 1'b0;
        #80ns;
        @(negedge HCLK);
        HRESETn = 1'b1;
    end

    // ==================================================
    // Protocol Interfaces
    // ==================================================
    ahb_if #(
        .ADDR_W(32),
        .DATA_W(32)
    ) ahb_vif (
        .HCLK(HCLK),
        .HRESETn(HRESETn)
    );

    sideband_if sb_vif (
        .HCLK(HCLK),
        .HRESETn(HRESETn),
        .ip_clk(ip_clk)
    );

    // ==================================================
    // Bus Interconnect & Loopback
    // ==================================================
    assign ahb_vif.HREADY = ahb_vif.HREADYOUT;

    // ==================================================
    // DUT Instantiation
    // ==================================================
    top_wrapper #(
        .ADDR_W               (32),
        .IN_ADDR_W            (6),
        .OUT_ADDR_W           (6),
        .HOLD_CYCLES          (16),
        .IP_ID                (32'h4950_0001),
        .IP_VERSION           (32'h0001_0000),
        .FFT_N                (32),
        .MULT_PIPE_STAGES     (0),
        .NATURAL_OUTPUT_ORDER (1'b1)
    ) u_dut (
        .HCLK        (HCLK),
        .HRESETn     (HRESETn),
        .ip_clk      (ip_clk),
        .HSEL        (ahb_vif.HSEL),
        .HADDR       (ahb_vif.HADDR),
        .HTRANS      (ahb_vif.HTRANS),
        .HBURST      (ahb_vif.HBURST),
        .HWRITE      (ahb_vif.HWRITE),
        .HSIZE       (ahb_vif.HSIZE),
        .HWDATA      (ahb_vif.HWDATA),
        .HREADY      (ahb_vif.HREADY),
        .HREADYOUT   (ahb_vif.HREADYOUT),
        .HRDATA      (ahb_vif.HRDATA),
        .HRESP       (ahb_vif.HRESP),
        .irq         (sb_vif.irq),
        .dma_rx_req  (sb_vif.dma_rx_req),
        .dma_tx_req  (sb_vif.dma_tx_req)
    );

    // ==================================================
    // UVM Configuration & Simulation Kick-off
    // ==================================================
    initial begin
        // Publish virtual interfaces to UVM configuration database
        uvm_config_db#(virtual ahb_if)::set(null, "*", "vif", ahb_vif);
        uvm_config_db#(virtual sideband_if)::set(null, "*", "vif", sb_vif);

        // Run selected UVM test
        run_test();
    end

endmodule : tb_top_uvm
