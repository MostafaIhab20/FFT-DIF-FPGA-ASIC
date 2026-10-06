// =============================================================================
// File Name      : ahb_slave_TB.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-01
// Version        : 1.0
// Description    : Self-checking testbench for the AHB-Lite slave interface
//                  (ahb_slave). Validates address/data phase pipeline timing,
//                  two-cycle error responses (HRESP), unmapped access handling,
//                  alignment checking, and decoded bus control strobes.
// =============================================================================

`timescale 1ns / 1ps

module tb_ahb_slave;

    // =========================================================================
    // Simulation Parameters
    // =========================================================================
    localparam int ADDR_W = 32;

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================
    // Clock and Reset
    logic              HCLK;
    logic              HRESETn;

    // AHB-Lite Bus Interface
    logic              HSEL;
    logic [ADDR_W-1:0] HADDR;
    logic [1:0]        HTRANS;
    logic              HWRITE;
    logic [2:0]        HSIZE;
    logic [31:0]       HWDATA;
    logic              HREADY;
    logic              HREADYOUT;
    logic [31:0]       HRDATA;
    logic              HRESP;

    // Simple Register Bus Interface
    logic [ADDR_W-1:0] bus_addr;
    logic              bus_write;
    logic [31:0]       bus_wdata;
    logic              bus_wr_en;
    logic              bus_rd_en;
    logic [31:0]       bus_rdata;
    logic              bus_err;

    // Mock Target Memory & Emulation Signals
    logic [31:0]       mock_regs [4];
    int                wr_strobes;
    int                rd_strobes;
    int                prev_wr_strobes;
    int                prev_rd_strobes;

    // Verification Variables & Counters
    int                errors;
    int                bus_errs;
    logic [31:0]       rdata;
    bit                resp_err;

    // =========================================================================
    // Device Under Test (DUT)
    // =========================================================================
    ahb_slave #(
        .ADDR_W (ADDR_W)
    ) u_dut (
        .HCLK      (HCLK),
        .HRESETn   (HRESETn),
        .HSEL      (HSEL),
        .HADDR     (HADDR),
        .HTRANS    (HTRANS),
        .HWRITE    (HWRITE),
        .HSIZE     (HSIZE),
        .HWDATA    (HWDATA),
        .HREADY    (HREADY),
        .HREADYOUT (HREADYOUT),
        .HRDATA    (HRDATA),
        .HRESP     (HRESP),
        .bus_addr  (bus_addr),
        .bus_write (bus_write),
        .bus_wdata (bus_wdata),
        .bus_wr_en (bus_wr_en),
        .bus_rd_en (bus_rd_en),
        .bus_rdata (bus_rdata),
        .bus_err   (bus_err)
    );

    // =========================================================================
    // Clock Generation
    // =========================================================================
    initial begin
        HCLK = 0;
        forever #5 HCLK = ~HCLK; // 100 MHz HCLK
    end

    assign HREADY = HREADYOUT;

    // =========================================================================
    // Mock Target Memory & Error Generation
    // =========================================================================
    // 4 registers @ 0x0..0xC: Reg 0 is Read-Only, Regs 1-3 are RW, > 0xC unmapped
    assign bus_rdata = mock_regs[bus_addr[3:2]];
    assign bus_err   = (bus_addr[31:4] != '0) || (bus_write && (bus_addr[3:2] == 2'b00));

    always @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            mock_regs[0] <= 32'h1234_0000;
            mock_regs[1] <= 32'h0000_0000;
            mock_regs[2] <= 32'h0000_0000;
            mock_regs[3] <= 32'h0000_0000;
            wr_strobes   <= 0;
            rd_strobes   <= 0;
        end else begin
            if (bus_wr_en) begin
                mock_regs[bus_addr[3:2]] <= bus_wdata;
                wr_strobes               <= wr_strobes + 1;
            end
            if (bus_rd_en) begin
                rd_strobes <= rd_strobes + 1;
            end
        end
    end

    // =========================================================================
    // AHB-Lite Bus Master Tasks
    // =========================================================================
    task automatic ahb_transaction(
        input  bit          wr,
        input  logic [31:0] addr,
        input  logic [2:0]  size,
        input  logic [31:0] wd,
        output logic [31:0] rd,
        output bit          err
    );
        @(negedge HCLK);
        HSEL   = 1'b1;
        HTRANS = 2'b10; // NONSEQ
        HADDR  = addr;
        HWRITE = wr;
        HSIZE  = size;

        @(negedge HCLK);
        HSEL   = 1'b0;
        HTRANS = 2'b00; // IDLE
        HWDATA = wd;

        while (!HREADY) @(negedge HCLK);
        rd  = HRDATA;
        err = HRESP;
        if (err) bus_errs++;
        @(posedge HCLK);
        #1;
    endtask

    task automatic ahb_write(input logic [31:0] a, input logic [31:0] d);
        logic [31:0] dummy_rd;
        bit          dummy_err;
        ahb_transaction(1'b1, a, 3'b010, d, dummy_rd, dummy_err);
    endtask

    task automatic ahb_read(input logic [31:0] a, output logic [31:0] d);
        bit dummy_err;
        ahb_transaction(1'b0, a, 3'b010, 32'h0, d, dummy_err);
    endtask

    task automatic check(input string msg, input bit cond);
        if (!cond) begin
            errors++;
            $display("[%0t] [ERROR] %s", $time, msg);
        end else begin
            $display("[%0t] [PASS]  %s", $time, msg);
        end
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
        $display("   STARTING UNIT VERIFICATION: AHB-Lite Slave Interface (ahb_slave)      ");
        $display("=========================================================================\n");

        // Reset Pulse
        repeat (5) @(negedge HCLK);
        HRESETn = 1'b1;
        repeat (2) @(posedge HCLK);

        // =====================================================================
        // Single Word Write & Readback Verification
        // =====================================================================
        $display("--- Single Word Write & Readback Verification ---");
        ahb_write(32'h04, 32'hAAAA_0004);
        ahb_write(32'h08, 32'hBBBB_0008);
        check("Writes completed without bus errors", bus_errs == 0);

        ahb_read(32'h04, rdata);
        check("Readback from 0x04 matches expected", (rdata == 32'hAAAA_0004) && (bus_errs == 0));

        ahb_read(32'h08, rdata);
        check("Readback from 0x08 matches expected", (rdata == 32'hBBBB_0008) && (bus_errs == 0));

        ahb_read(32'h00, rdata);
        check("Readback from RO Reg 0x00 matches expected", (rdata == 32'h1234_0000) && (bus_errs == 0));

        // =====================================================================
        // Error Response Generation and Protocol Protection
        // =====================================================================
        $display("\n--- Error Response Generation and Protocol Protection ---");
        prev_wr_strobes = wr_strobes;
        prev_rd_strobes = rd_strobes;

        // Write to Read-Only Reg 0
        ahb_write(32'h00, 32'hDEAD_BEEF);
        check("Write to RO register triggers HRESP error", bus_errs == 1);

        // Read unmapped address
        ahb_read(32'h40, rdata);
        check("Read from unmapped address triggers HRESP error", bus_errs == 2);

        // Write unmapped address
        ahb_write(32'h40, 32'h0000_0001);
        check("Write to unmapped address triggers HRESP error", bus_errs == 3);

        // half-word access via direct transaction
        ahb_transaction(1'b1, 32'h04, 3'b001, 32'h1111_1111, rdata, resp_err);
        check("Half-word access triggers HRESP error", resp_err && (bus_errs == 4));

        // Misaligned address (0x05)
        ahb_write(32'h05, 32'h2222_2222);
        check("Misaligned address triggers HRESP error", bus_errs == 5);

        check("No write/read strobes issued during error cycles",
              (wr_strobes == prev_wr_strobes) && (rd_strobes == prev_rd_strobes));
        check("Registers remain uncorrupted following error violations",
              (mock_regs[0] == 32'h1234_0000) && (mock_regs[1] == 32'hAAAA_0004));

        // =====================================================================
        // Bus Error Recovery Verification
        // =====================================================================
        $display("\n--- Bus Error Recovery Verification ---");
        ahb_write(32'h0C, 32'hCCCC_000C);
        check("Write immediately after error cycles succeeds without new error", bus_errs == 5);

        ahb_read(32'h0C, rdata);
        check("Readback immediately after error cycles matches expected", (rdata == 32'hCCCC_000C) && (bus_errs == 5));

        // =====================================================================
        // Pipelined Back-to-Back Bus Write Transactions
        // =====================================================================
        $display("\n--- Pipelined Back-to-Back Bus Write Transactions ---");
        @(negedge HCLK);
        HSEL   = 1'b1;
        HTRANS = 2'b10; // NONSEQ
        HADDR  = 32'h04;
        HWRITE = 1'b1;
        HSIZE  = 3'b010;

        @(negedge HCLK);
        HTRANS = 2'b11; // SEQ
        HADDR  = 32'h08;
        HWDATA = 32'h0000_0044;

        @(negedge HCLK);
        HTRANS = 2'b11; // SEQ
        HADDR  = 32'h0C;
        HWDATA = 32'h0000_0088;

        @(negedge HCLK);
        HSEL   = 1'b0;
        HTRANS = 2'b00; // IDLE
        HWDATA = 32'h0000_00CC;

        @(negedge HCLK);
        check("Pipelined write to Reg 1 matches", mock_regs[1] == 32'h0000_0044);
        check("Pipelined write to Reg 2 matches", mock_regs[2] == 32'h0000_0088);
        check("Pipelined write to Reg 3 matches", mock_regs[3] == 32'h0000_00CC);

        // =====================================================================
        // Read Strobe Generation Verification
        // =====================================================================
        $display("\n--- Read Strobe Generation Verification ---");
        prev_rd_strobes = rd_strobes;
        ahb_read(32'h04, rdata);
        check("Exactly one read strobe generated per read transaction", rd_strobes == prev_rd_strobes + 1);

        // =====================================================================
        // Idle and Busy Transfer Filtering
        // =====================================================================
        $display("\n--- Idle and Busy Transfer Filtering ---");
        prev_wr_strobes = wr_strobes;
        @(negedge HCLK);
        HSEL   = 1'b1;
        HTRANS = 2'b01; // BUSY
        HADDR  = 32'h04;
        HWRITE = 1'b1;

        @(negedge HCLK);
        HSEL   = 1'b0;
        HTRANS = 2'b00; // IDLE
        HWDATA = 32'hFFFF_FFFF;

        @(negedge HCLK);
        check("BUSY/IDLE cycles produce no internal write strobes", wr_strobes == prev_wr_strobes);

        // =====================================================================
        // Simulation Summary
        // =====================================================================
        $display("\n=========================================================================");
        $display("                         SIMULATION SUMMARY REPORT                       ");
        $display("=========================================================================");
        $display("  Total Check Errors: %0d", errors);
        $display("  Total Bus Errors  : %0d (Expected: 5 forced protocol checks)", bus_errs);
        $display("  -----------------------------------------------------------------------");
        if (errors == 0 && bus_errs == 5) begin
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
        #100_000;
        $display("\n[%0t] [FATAL] Simulation watchdog timeout triggered!", $time);
        $finish;
    end

endmodule : tb_ahb_slave
