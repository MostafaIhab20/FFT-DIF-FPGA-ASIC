// =============================================================================
// File Name      : async_fifo_TB.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-01
// Version        : 1.0
// Description    : Self-checking testbench for dual-clock asynchronous FIFO
//                  (async_fifo). Validates reset synchronization, full/empty
//                  boundary conditions, overflow/underflow protection, and
//                  concurrent stress streaming across asynchronous clock domains.
// =============================================================================

`timescale 1ns / 1ps

module tb_async_fifo;

    // =========================================================================
    // Simulation Parameters
    // =========================================================================
    localparam int DATA_W           = 32;
    localparam int ADDR_W           = 4;
    localparam int DEPTH            = 1 << ADDR_W;
    localparam int NUM_STRESS_WORDS = 20000;

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================
    // Write Domain Clocks & Resets
    logic              wclk;
    logic              wrst_n;
    logic              winc;
    logic [DATA_W-1:0] wdata;
    logic              wfull;
    logic [ADDR_W:0]   wlevel;

    // Read Domain Clocks & Resets
    logic              rclk;
    logic              rrst_n;
    logic              rinc;
    logic [DATA_W-1:0] rdata;
    logic              rempty;
    logic [ADDR_W:0]   rlevel;

    // Direct Test Interface Drivers
    logic              direct_winc;
    logic [DATA_W-1:0] direct_wdata;
    logic              direct_rinc;
    logic [DATA_W-1:0] captured_rdata;

    // Stress Test Drivers & Variables
    bit                stress_active;
    logic              stress_winc;
    logic              stress_rinc;
    int                pw;
    int                pr;
    int                wcnt;
    int                rcnt;
    int                errors;
    int                saw_full;
    int                saw_empty;
    int                rejected_w;

    // Dynamic multiplexing between direct tests and concurrent stress test
    assign wdata = stress_active ? wcnt        : direct_wdata;
    assign winc  = stress_active ? stress_winc : direct_winc;
    assign rinc  = stress_active ? stress_rinc : direct_rinc;

    // =========================================================================
    // Device Under Test (DUT)
    // =========================================================================
    async_fifo #(
        .DATA_W (DATA_W),
        .ADDR_W (ADDR_W)
    ) u_dut (
        .wclk   (wclk),
        .wrst_n (wrst_n),
        .winc   (winc),
        .wdata  (wdata),
        .wfull  (wfull),
        .wlevel (wlevel),
        .rclk   (rclk),
        .rrst_n (rrst_n),
        .rinc   (rinc),
        .rdata  (rdata),
        .rempty (rempty),
        .rlevel (rlevel)
    );

    // =========================================================================
    // Clock Generation
    // =========================================================================
    initial begin
        wclk = 0;
        forever #5.0 wclk = ~wclk; // 100 MHz Write Clock
    end

    initial begin
        rclk = 0;
        forever #3.3 rclk = ~rclk; // ~151.5 MHz Asynchronous Read Clock
    end

    // =========================================================================
    // Verification Tasks
    // =========================================================================
    task automatic check(input string msg, input bit cond);
        if (!cond) begin
            errors++;
            $display("[%0t] [ERROR] %s", $time, msg);
        end else begin
            $display("[%0t] [PASS]  %s", $time, msg);
        end
    endtask

    task automatic push_word(input logic [DATA_W-1:0] d);
        @(negedge wclk);
        direct_winc  = 1'b1;
        direct_wdata = d;
        @(negedge wclk);
        direct_winc  = 1'b0;
    endtask

    task automatic pop_word(output logic [DATA_W-1:0] d);
        @(negedge rclk);
        d           = rdata; // FWFT: data is already available combinationally
        direct_rinc = 1'b1;
        @(negedge rclk);
        direct_rinc = 1'b0;
    endtask

    // =========================================================================
    // Concurrent Stress Stimulus Processes
    // =========================================================================
    // Write Domain Random Driver (active during stress streaming)
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wcnt        <= 0;
            rejected_w  <= 0;
            saw_full    <= 0;
            stress_winc <= 1'b0;
        end else if (stress_active) begin
            if (stress_winc && !wfull) begin
                wcnt <= wcnt + 1;
            end
            if (stress_winc && wfull) begin
                rejected_w <= rejected_w + 1;
            end
            if (wfull) begin
                saw_full <= 1;
            end

            // Drive randomized write request
            stress_winc <= (wcnt + ((stress_winc && !wfull) ? 1 : 0) < NUM_STRESS_WORDS) &&
                           ($urandom_range(99) < pw);
        end else begin
            stress_winc <= 1'b0;
        end
    end

    // Read Domain Random Receiver (active during stress streaming)
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rcnt        <= 0;
            saw_empty   <= 0;
            stress_rinc <= 1'b0;
        end else if (stress_active) begin
            if (stress_rinc && !rempty) begin
                if (rdata !== rcnt) begin
                    errors++;
                    $display("[%0t] [ERROR] Data mismatch: expected %0d, received %0d", $time, rcnt, rdata);
                end
                rcnt <= rcnt + 1;
            end
            if (rempty) begin
                saw_empty <= 1;
            end

            // Drive randomized read request
            stress_rinc <= ($urandom_range(99) < pr);
        end else begin
            stress_rinc <= 1'b0;
        end
    end

    // Vary Pacing Rates Periodically during Stress Test
    always @(rcnt) begin
        if (stress_active) begin
            case ((rcnt / 4000) % 3)
                0: begin pw = 90; pr = 30; end // Fill-heavy
                1: begin pw = 20; pr = 90; end // Drain-heavy
                2: begin pw = 60; pr = 60; end // Balanced
            endcase
        end
    end

    // =========================================================================
    // Main Verification Process
    // =========================================================================
    initial begin
        // Signal Initialization
        wrst_n        = 1'b0;
        rrst_n        = 1'b0;
        direct_winc   = 1'b0;
        direct_wdata  = '0;
        direct_rinc   = 1'b0;
        errors        = 0;
        stress_active = 1'b0;
        pw            = 90;
        pr            = 30;

        $display("\n=========================================================================");
        $display("   STARTING UNIT VERIFICATION: Asynchronous FIFO (async_fifo)            ");
        $display("=========================================================================\n");

        // Apply Reset
        repeat (5) @(posedge wclk);
        wrst_n = 1'b1;
        rrst_n = 1'b1;
        repeat (10) @(posedge wclk);

        // =====================================================================
        // Reset State and Initial Watermark Verification
        // =====================================================================
        $display("--- Reset State and Initial Watermark Verification ---");
        check("FIFO is empty after reset", rempty === 1'b1);
        check("FIFO is not full after reset", wfull === 1'b0);
        check("Initial write level is 0", wlevel == '0);
        check("Initial read level is 0", rlevel == '0);

        // =====================================================================
        // FIFO Fill to Capacity and Overflow Protection
        // =====================================================================
        $display("\n--- FIFO Fill to Capacity and Overflow Protection ---");
        for (int i = 0; i < DEPTH; i++) begin
            push_word(32'hA000_0000 + i);
        end
        repeat (5) @(posedge wclk);

        check("FIFO asserts wfull at capacity", wfull === 1'b1);
        check("wlevel equals DEPTH", wlevel == DEPTH);

        // Attempt write while full
        push_word(32'hDEAD_BEEF);
        repeat (3) @(posedge wclk);
        check("wlevel remains at DEPTH after rejected write", wlevel == DEPTH);

        // =====================================================================
        // FIFO Drain to Empty and Underflow Protection
        // =====================================================================
        $display("\n--- FIFO Drain to Empty and Underflow Protection ---");
        for (int i = 0; i < DEPTH; i++) begin
            pop_word(captured_rdata);
            if (captured_rdata !== (32'hA000_0000 + i)) begin
                errors++;
                $display("[%0t] [ERROR] Word %0d mismatch: exp 0x%08h, got 0x%08h",
                         $time, i, 32'hA000_0000 + i, captured_rdata);
            end
        end
        repeat (5) @(posedge rclk);

        check("FIFO asserts rempty when completely drained", rempty === 1'b1);
        check("FIFO deasserts wfull", wfull === 1'b0);

        // Attempt read while empty
        pop_word(captured_rdata);
        repeat (3) @(posedge rclk);
        check("FIFO remains empty after underflow read attempt", rempty === 1'b1);

        // =====================================================================
        // Asynchronous Dual-Clock Concurrent Stress Streaming
        // =====================================================================
        $display("\n--- Asynchronous Dual-Clock Concurrent Stress Streaming ---");
        $display("Streaming %0d words across 100MHz (write) and 151MHz (read) domains...", NUM_STRESS_WORDS);

        // Align stimulus process
        @(posedge wclk);
        stress_active = 1'b1;

        // Await completion of all words
        wait(rcnt == NUM_STRESS_WORDS);
        stress_active = 1'b0;
        repeat (20) @(posedge rclk);

        check("Stress test transferred all words bit-accurately", (wcnt == NUM_STRESS_WORDS) && (rcnt == NUM_STRESS_WORDS));
        check("FIFO full condition encountered during stress", saw_full == 1);
        check("FIFO empty condition encountered during stress", saw_empty == 1);

        // =====================================================================
        // Simulation Summary
        // =====================================================================
        $display("\n=========================================================================");
        $display("                         SIMULATION SUMMARY REPORT                       ");
        $display("=========================================================================");
        $display("  Total Check Errors: %0d", errors);
        $display("  Total Words Streamed: %0d", rcnt);
        $display("  Full Boundary Seen  : %s", saw_full ? "YES" : "NO");
        $display("  Empty Boundary Seen : %s", saw_empty ? "YES" : "NO");
        $display("  -----------------------------------------------------------------------");
        if (errors == 0 && (rcnt == NUM_STRESS_WORDS) && saw_full && saw_empty) begin
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
        #50_000_000;
        $display("\n[%0t] [FATAL] Simulation watchdog timeout triggered!", $time);
        $finish;
    end

endmodule : tb_async_fifo
