// =============================================================================
// File Name      : top_TB.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-01
// Version        : 1.0
// Description    : Self-checking system testbench for the AHB-Lite 32-point
//                  Radix-2 DIF FFT subsystem (top_wrapper). Validates register
//                  file, FIFO boundary conditions, DMA requests, interrupt
//                  generation, and end-to-end FFT processing.
// =============================================================================

`timescale 1ns / 1ps

import ip_regs_pkg::*;
import fft_pkg::*;

module tb_top;

    // =========================================================================
    // Simulation Parameters
    // =========================================================================
    localparam int IN_AW                = 6;  // 64 words (2 full frames)
    localparam int OUT_AW               = 6;  // 64 words (2 full frames)
    localparam int IN_DEPTH             = 1 << IN_AW;
    localparam int OUT_DEPTH            = 1 << OUT_AW;
    localparam int FFT_N                = 32;

    // Register Byte Addresses (HADDR)
    localparam logic [31:0] A_ID        = 32'h00;
    localparam logic [31:0] A_VER       = 32'h04;
    localparam logic [31:0] A_CTRL      = 32'h08;
    localparam logic [31:0] A_STATUS    = 32'h0C;
    localparam logic [31:0] A_INT_EN    = 32'h10;
    localparam logic [31:0] A_INT_ST    = 32'h14;
    localparam logic [31:0] A_INLVL     = 32'h18;
    localparam logic [31:0] A_OUTLVL    = 32'h1C;
    localparam logic [31:0] A_INTH      = 32'h20;
    localparam logic [31:0] A_OUTTH     = 32'h24;
    localparam logic [31:0] A_FIFO_DATA = 32'h100;

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================
    // Clocks and Resets
    logic        HCLK;
    logic        HRESETn;
    logic        ip_clk;

    // AHB-Lite Bus Interface
    logic        HSEL;
    logic [31:0] HADDR;
    logic [1:0]  HTRANS;
    logic        HWRITE;
    logic [2:0]  HSIZE;
    logic [31:0] HWDATA;
    logic        HREADY;
    logic        HREADYOUT;
    logic [31:0] HRDATA;
    logic        HRESP;

    // Interrupt and Hardware DMA Handshake Interface
    logic        irq;
    logic        dma_rx_req;
    logic        dma_tx_req;

    // Verification Variables & Counters
    int          errors;
    int          bus_errs;
    logic [31:0] rdata;
    int          bin_errors;
    int          timeout;

    // =========================================================================
    // Device Under Test (DUT)
    // =========================================================================
    top_wrapper #(
        .ADDR_W               (32),
        .IN_ADDR_W            (IN_AW),
        .OUT_ADDR_W           (OUT_AW),
        .HOLD_CYCLES          (16),
        .IP_ID                (32'h4950_0001),
        .IP_VERSION           (32'h0001_0000),
        .FFT_N                (FFT_N),
        .MULT_PIPE_STAGES     (0),
        .NATURAL_OUTPUT_ORDER (1'b1)
    ) u_dut (
        .HCLK       (HCLK),
        .HRESETn    (HRESETn),
        .ip_clk     (ip_clk),
        .HSEL       (HSEL),
        .HADDR      (HADDR),
        .HTRANS     (HTRANS),
        .HWRITE     (HWRITE),
        .HSIZE      (HSIZE),
        .HWDATA     (HWDATA),
        .HREADY     (HREADY),
        .HREADYOUT  (HREADYOUT),
        .HRDATA     (HRDATA),
        .HRESP      (HRESP),
        .irq        (irq),
        .dma_rx_req (dma_rx_req),
        .dma_tx_req (dma_tx_req)
    );

    // =========================================================================
    // Clock Generation
    // =========================================================================
    initial begin
        HCLK = 0;
        forever #5 HCLK = ~HCLK;       // 100 MHz HCLK
    end

    initial begin
        ip_clk = 0;
        forever #3.5 ip_clk = ~ip_clk; // ~143 MHz asynchronous ip_clk
    end

    assign HREADY = HREADYOUT;

    // =========================================================================
    // AHB-Lite Bus Master Tasks
    // =========================================================================
    task automatic ahb_transaction(
        input  bit          wr,
        input  logic [31:0] addr,
        input  logic [31:0] wd,
        output logic [31:0] rd
    );
        @(negedge HCLK);
        HSEL   = 1'b1;
        HTRANS = 2'b10; // NONSEQ
        HADDR  = addr;
        HWRITE = wr;
        HSIZE  = 3'b010; // 32-bit word

        @(negedge HCLK);
        HSEL   = 1'b0;
        HTRANS = 2'b00; // IDLE
        HWDATA = wd;

        while (!HREADY) @(negedge HCLK);
        rd = HRDATA;
        if (HRESP) bus_errs++;
        @(posedge HCLK);
        #1;
    endtask

    task automatic ahb_write(input logic [31:0] a, input logic [31:0] d);
        logic [31:0] dummy;
        ahb_transaction(1'b1, a, d, dummy);
    endtask

    task automatic ahb_read(input logic [31:0] a, output logic [31:0] d);
        ahb_transaction(1'b0, a, 32'h0, d);
    endtask

    task automatic check(input string msg, input bit cond);
        if (!cond) begin
            errors++;
            $display("[%0t] [ERROR] %s", $time, msg);
        end else begin
            $display("[%0t] [PASS]  %s", $time, msg);
        end
    endtask

    task automatic wait_idle();
        logic [31:0] s;
        repeat (10) @(posedge HCLK);
        do begin
            ahb_read(A_STATUS, s);
        end while (s[0]);
    endtask

    // =========================================================================
    // Main Verification Process
    // =========================================================================
    initial begin
        // Signal Initialization
        HRESETn    = 1'b0;
        HSEL       = 1'b0;
        HADDR      = '0;
        HTRANS     = '0;
        HWRITE     = 1'b0;
        HSIZE      = 3'b010;
        HWDATA     = '0;
        errors     = 0;
        bus_errs   = 0;

        $display("\n=========================================================================");
        $display("   STARTING SYSTEM VERIFICATION: AHB-Lite FFT Subsystem (top_wrapper)   ");
        $display("=========================================================================\n");

        // Release Reset after 10 HCLK cycles
        repeat (10) @(negedge HCLK);
        HRESETn = 1'b1;
        wait_idle();

        // =====================================================================
        // Test 1: Reset & Peripheral Identification
        // =====================================================================
        $display("--- Test 1: Reset & Peripheral Identification ---");
        ahb_read(A_ID, rdata);
        check("IP ID matches 0x49500001", rdata == 32'h4950_0001);

        ahb_read(A_VER, rdata);
        check("IP Version matches 0x00010000", rdata == 32'h0001_0000);

        ahb_read(A_STATUS, rdata);
        check("Initial STATUS: in_empty=1, out_empty=1, busy=0", (rdata[1] == 1'b1) && (rdata[3] == 1'b1) && (rdata[0] == 1'b0));

        ahb_read(A_INLVL, rdata);
        check("Initial IN FIFO Level is 0", rdata == 32'd0);

        ahb_read(A_OUTLVL, rdata);
        check("Initial OUT FIFO Level is 0", rdata == 32'd0);

        // =====================================================================
        // Test 2: Register R/W and Threshold Configuration
        // =====================================================================
        $display("\n--- Test 2: Register R/W and Threshold Configuration ---");
        ahb_write(A_INT_EN, 32'h7);
        ahb_read(A_INT_EN, rdata);
        check("INT_EN configured to 0x7", rdata == 32'h7);

        ahb_write(A_INTH, 32'd8);
        ahb_read(A_INTH, rdata);
        check("IN_THRESH programmed to 8", rdata == 32'd8);

        ahb_write(A_OUTTH, 32'd16);
        ahb_read(A_OUTTH, rdata);
        check("OUT_THRESH programmed to 16", rdata == 32'd16);

        // =====================================================================
        // Test 3: Hardware DMA Handshake Flow Control
        // =====================================================================
        $display("\n--- Test 3: Hardware DMA Handshake Flow Control ---");
        // DMA disabled initially: dma_rx_req must be 0
        check("DMA disabled: dma_rx_req is low", dma_rx_req === 1'b0);

        // Set dma_en=1 with enable=0: dma_rx_req must remain 0
        ahb_write(A_CTRL, 32'h10);
        #1;
        check("dma_en=1 but enable=0: dma_rx_req remains low", dma_rx_req === 1'b0);

        // Set dma_en=1 and enable=1: IN FIFO is almost-empty, dma_rx_req must assert
        ahb_write(A_CTRL, 32'h11);
        #1;
        check("dma_en=1 and enable=1: dma_rx_req asserts", dma_rx_req === 1'b1);

        // Disable DMA mode: dma_rx_req must deassert immediately
        ahb_write(A_CTRL, 32'h01);
        #1;
        check("dma_en=0: dma_rx_req deasserts", dma_rx_req === 1'b0);

        // Disable core for next test
        ahb_write(A_CTRL, 32'h00);

        // =====================================================================
        // Test 4: Fault Injection & Sticky W1C Interrupts
        // =====================================================================
        $display("\n--- Test 4: Fault Injection & Sticky W1C Interrupts ---");
        // Fill IN FIFO to maximum capacity (64 words)
        for (int i = 0; i < IN_DEPTH; i++) begin
            ahb_write(A_FIFO_DATA, 32'hA000_0000 + i);
        end

        ahb_read(A_INLVL, rdata);
        check("IN FIFO full: level is 64", rdata == IN_DEPTH);

        ahb_read(A_STATUS, rdata);
        check("STATUS in_full bit asserted", rdata[2] == 1'b1);

        // Overflow injection: write 65th word
        ahb_write(A_FIFO_DATA, 32'hDEAD_BEEF);

        ahb_read(A_INT_ST, rdata);
        check("INT_STATUS[1] in_overflow sticky flag asserted", rdata[1] == 1'b1);
        check("IRQ line asserted for in_overflow", irq === 1'b1);

        // Clear overflow via W1C
        ahb_write(A_INT_ST, 32'h02);
        ahb_read(A_INT_ST, rdata);
        check("INT_STATUS[1] in_overflow cleared after W1C", rdata[1] == 1'b0);
        check("IRQ line deasserted after W1C", irq === 1'b0);

        // Underflow injection: read from empty OUT FIFO
        ahb_read(A_FIFO_DATA, rdata);
        check("Underflow read returns 0", rdata == 32'h0);

        ahb_read(A_INT_ST, rdata);
        check("INT_STATUS[2] out_underflow sticky flag asserted", rdata[2] == 1'b1);
        check("IRQ line asserted for out_underflow", irq === 1'b1);

        // Clear underflow via W1C
        ahb_write(A_INT_ST, 32'h04);
        ahb_read(A_INT_ST, rdata);
        check("INT_STATUS[2] out_underflow cleared after W1C", rdata[2] == 1'b0);
        check("IRQ line deasserted after W1C", irq === 1'b0);

        // =====================================================================
        // Test 5: IN FIFO Flush Control
        // =====================================================================
        $display("\n--- Test 5: IN FIFO Flush Control ---");
        // IN FIFO still contains 64 words; trigger flush_in (CTRL[2])
        ahb_write(A_CTRL, 32'h04);
        wait_idle();

        ahb_read(A_INLVL, rdata);
        check("IN FIFO level is 0 after flush_in", rdata == 32'd0);

        ahb_read(A_STATUS, rdata);
        check("STATUS in_empty asserted after flush_in", rdata[1] == 1'b1);

        // =====================================================================
        // Test 6: End-to-End 32-Point FFT Frame Verification (DC Signal)
        // =====================================================================
        $display("\n--- Test 6: End-to-End 32-Point FFT Frame Verification (DC Signal) ---");
        // Enable only FRAME_DONE interrupt
        ahb_write(A_INT_EN, 32'h01);

        // Push 32 DC complex samples: Re = 0x6CCD, Im = 0x0000
        for (int i = 0; i < FFT_N; i++) begin
            ahb_write(A_FIFO_DATA, 32'h6CCD_0000);
        end

        ahb_read(A_INLVL, rdata);
        check("IN FIFO holds 32 samples prior to enable", rdata == 32'd32);

        // Enable IP Core (CTRL[0] = 1)
        ahb_write(A_CTRL, 32'h01);

        // Await FRAME_DONE interrupt with timeout
        timeout = 0;
        while (!irq && (timeout < 5000)) begin
            @(posedge HCLK);
            timeout++;
        end

        check("IRQ asserted by FRAME_DONE event", irq === 1'b1);

        ahb_read(A_INT_ST, rdata);
        check("INT_STATUS[0] frame_done bit asserted", rdata[0] == 1'b1);

        ahb_read(A_OUTLVL, rdata);
        check("OUT FIFO holds exactly 32 output samples", rdata == 32'd32);

        // Read 32 output bins in natural order
        bin_errors = 0;
        for (int i = 0; i < FFT_N; i++) begin
            ahb_read(A_FIFO_DATA, rdata);
            if (i == 0) begin
                check("Bin 0 (DC) magnitude matches expected (0x6CCD_0000)", rdata == 32'h6CCD_0000);
            end else begin
                if (rdata != 32'h0000_0000) bin_errors++;
            end
        end
        check("All AC Bins (1..31) are zero", bin_errors == 0);

        // Clear FRAME_DONE interrupt via W1C
        ahb_write(A_INT_ST, 32'h01);
        ahb_read(A_INT_ST, rdata);
        check("INT_STATUS[0] cleared after W1C", rdata[0] == 1'b0);
        check("IRQ line deasserted after clear", irq === 1'b0);

        // =====================================================================
        // Test 7: Soft Reset
        // =====================================================================
        $display("\n--- Test 7: Soft Reset ---");
        // Push residual samples
        for (int i = 0; i < 4; i++) begin
            ahb_write(A_FIFO_DATA, 32'h1234_5678);
        end

        // Trigger Soft Reset (CTRL[1] = 1)
        ahb_write(A_CTRL, 32'h02);
        wait_idle();

        ahb_read(A_CTRL, rdata);
        check("CTRL enable cleared by soft reset", rdata == 32'h0);

        ahb_read(A_STATUS, rdata);
        check("STATUS indicates both FIFOs empty after soft reset", (rdata[1] == 1'b1) && (rdata[3] == 1'b1));

        // =====================================================================
        // Test 8: Bus Protocol Error Check
        // =====================================================================
        $display("\n--- Test 8: Bus Protocol Error Check ---");
        // Write to Read-Only ID register
        ahb_write(A_ID, 32'hBADD_CAFE);

        // Read from unmapped address
        ahb_read(32'h200, rdata);

        // Write to unmapped address
        ahb_write(32'h300, 32'h1);

        check("Protocol errors generated on illegal accesses", bus_errs >= 3);

        // =====================================================================
        // Simulation Summary
        // =====================================================================
        $display("\n=========================================================================");
        $display("                         SIMULATION SUMMARY REPORT                       ");
        $display("=========================================================================");
        $display("  Total Check Errors: %0d", errors);
        $display("  Total Bus Errors  : %0d (Expected: 3 forced protocol checks)", bus_errs);
        $display("  -----------------------------------------------------------------------");
        if (errors == 0 && bus_errs == 3) begin
            $display("  FINAL VERDICT     : *** ALL TESTS PASSED SUCCESSFULLY ***");
        end else begin
            $display("  FINAL VERDICT     : *** SIMULATION FAILED (errors=%0d) ***", errors);
        end
        $display("=========================================================================\n");

        $finish;
    end

    // =========================================================================
    // Watchdog Timer
    // =========================================================================
    initial begin
        #5_000_000;
        $display("\n[%0t] [FATAL] Simulation watchdog timeout triggered!", $time);
        $finish;
    end

endmodule : tb_top
