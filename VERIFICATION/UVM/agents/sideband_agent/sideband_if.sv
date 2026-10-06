// =============================================================================
// File Name      : sideband_if.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : SystemVerilog interface for top-level sideband signals,
//                  including interrupts and hardware DMA handshakes.
// =============================================================================

`timescale 1ns/1ps

`ifndef SIDEBAND_IF_SV
`define SIDEBAND_IF_SV

interface sideband_if (
    input logic HCLK,
    input logic HRESETn,
    input logic ip_clk
);

    // ==================================================
    // Sideband Signals
    // ==================================================
    logic irq;
    logic dma_rx_req;
    logic dma_tx_req;

    // ==================================================
    // Monitor Clocking Block (HCLK Domain)
    // ==================================================
    clocking mon_cb @(posedge HCLK);
        default input #1step;
        input irq;
        input dma_rx_req;
        input dma_tx_req;
    endclocking

    // ==================================================
    // Interface Modports
    // ==================================================
    modport monitor_mp (
        clocking mon_cb,
        input    HCLK,
        input    HRESETn,
        input    ip_clk
    );

    // ==================================================
    // Protocol Assertions (SVA)
    // ==================================================
    // Ensure sideband lines do not contain unknown logic levels when not in reset
    property p_no_x_on_sidebands;
        @(posedge HCLK) disable iff (!HRESETn)
        !$isunknown({irq, dma_rx_req, dma_tx_req});
    endproperty
    assert_no_x_sidebands: assert property (p_no_x_on_sidebands)
        else $error("[SVA-SIDEBAND] Unknown level detected on interrupt or DMA handshake outputs!");

endinterface : sideband_if

`endif // SIDEBAND_IF_SV
