// =============================================================================
// File Name      : booth_radix4_multiplier_TB.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-09-27
// Version        : 1.0
// Description    : Self-checking unit testbench for 16x16 Signed Radix-4 Booth
//                  Multiplier with 4:2 Compressor Tree and Brent-Kung final adder.
//                  Verifies:
//                    - Combinational mode (PIPELINE_STAGES = 0)
//                    - Pipelined mode 1 stage (PIPELINE_STAGES = 1)
//                    - Pipelined mode 2 stages (PIPELINE_STAGES = 2)
//                    - Corner cases (0, +/-1, MAX_POS, MIN_NEG)
//                    - 20,000+ randomized vectors against golden model
// =============================================================================

`timescale 1ns / 1ps

module booth_radix4_multiplier_TB;

    localparam time CLK_PERIOD = 10ns;

    logic        clk;
    logic        rst_n;
    logic        en;
    int          total_errors = 0;

    // Clock Generation
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // -------------------------------------------------------------------------
    // DUT Instances: PIPELINE_STAGES = 0, 1, and 2
    // -------------------------------------------------------------------------
    logic signed [15:0] a0, b0;
    logic signed [31:0] p0;

    booth_radix4_multiplier #(.PIPELINE_STAGES(0)) u_mult_comb (
        .clk   (clk),
        .rst_n (rst_n),
        .en    (en),
        .a     (a0),
        .b     (b0),
        .p     (p0)
    );

    logic signed [15:0] a1, b1;
    logic signed [31:0] p1;

    booth_radix4_multiplier #(.PIPELINE_STAGES(1)) u_mult_pipe1 (
        .clk   (clk),
        .rst_n (rst_n),
        .en    (en),
        .a     (a1),
        .b     (b1),
        .p     (p1)
    );

    logic signed [15:0] a2, b2;
    logic signed [31:0] p2;

    booth_radix4_multiplier #(.PIPELINE_STAGES(2)) u_mult_pipe2 (
        .clk   (clk),
        .rst_n (rst_n),
        .en    (en),
        .a     (a2),
        .b     (b2),
        .p     (p2)
    );

    // -------------------------------------------------------------------------
    // Main Verification Process
    // -------------------------------------------------------------------------
    initial begin : proc_test
        logic signed [31:0] exp_p;
        logic signed [15:0] rand_a, rand_b;
        logic signed [15:0] test_vals [0:7];

        test_vals[0] = 16'sh0000;         //  0
        test_vals[1] = 16'sh0001;         // +1
        test_vals[2] = 16'shFFFF;         // -1
        test_vals[3] = 16'sh7FFF;         // +32767 (MAX_POS)
        test_vals[4] = 16'sh8000;         // -32768 (MIN_NEG)
        test_vals[5] = 16'sh5A82;         // +0.7071
        test_vals[6] = 16'shA57E;         // -0.7071
        test_vals[7] = 16'sh7D8A;         // Twiddle real part

        rst_n = 1'b0;
        en    = 1'b1;
        a0    = '0;
        b0    = '0;
        a1    = '0;
        b1    = '0;
        a2    = '0;
        b2    = '0;

        #(CLK_PERIOD * 3);
        @(negedge clk);
        rst_n = 1'b1;

        $display("\n=========================================================================");
        $display("   TESTBENCH: 16x16 Signed Radix-4 Booth Multiplier                      ");
        $display("=========================================================================");

        // ---------------------------------------------------------------------
        // Test 1: Combinational Multiplier (PIPELINE_STAGES = 0)
        // ---------------------------------------------------------------------
        $display("\n>>> 1. Testing Combinational Multiplier (Corner Cases)...");
        for (int i = 0; i < 8; i++) begin
            for (int j = 0; j < 8; j++) begin
                a0 = test_vals[i];
                b0 = test_vals[j];
                #1;
                exp_p = $signed(a0) * $signed(b0);
                if (p0 !== exp_p) begin
                    $display("[FAIL COMB CORNER]: a=%d, b=%d -> HW=%d, EXP=%d", a0, b0, p0, exp_p);
                    total_errors++;
                end
            end
        end

        $display(">>> 1. Testing Combinational Multiplier (20,000 Random Vectors)...");
        for (int i = 0; i < 20000; i++) begin
            a0 = $urandom;
            b0 = $urandom;
            #1;
            exp_p = $signed(a0) * $signed(b0);
            if (p0 !== exp_p) begin
                $display("[FAIL COMB RANDOM @ %0d]: a=%d, b=%d -> HW=%d, EXP=%d", i, a0, b0, p0, exp_p);
                total_errors++;
                if (total_errors > 20) break;
            end
        end
        $display("  Combinational multiplier passed with %0d errors.", total_errors);

        // ---------------------------------------------------------------------
        // Test 2: Pipelined Multiplier 1 Stage (PIPELINE_STAGES = 1)
        // ---------------------------------------------------------------------
        $display("\n>>> 2. Testing 1-Stage Pipelined Multiplier (10,000 Vectors)...");
        begin
            logic signed [15:0] pipe1_a_hist [0:10005];
            logic signed [15:0] pipe1_b_hist [0:10005];

            for (int i = 0; i < 10000; i++) begin
                rand_a = $urandom;
                rand_b = $urandom;

                @(posedge clk);
                #1; // Sample output from previous cycle
                if (i >= 1) begin
                    exp_p = $signed(pipe1_a_hist[i-1]) * $signed(pipe1_b_hist[i-1]);
                    if (p1 !== exp_p) begin
                        $display("[FAIL PIPE1 @ %0d]: a=%d, b=%d -> HW=%d, EXP=%d",
                                 i-1, pipe1_a_hist[i-1], pipe1_b_hist[i-1], p1, exp_p);
                        total_errors++;
                        if (total_errors > 20) break;
                    end
                end

                // Drive new inputs
                a1 = rand_a;
                b1 = rand_b;
                pipe1_a_hist[i] = rand_a;
                pipe1_b_hist[i] = rand_b;
            end
        end
        $display("  1-stage pipelined multiplier passed cumulative errors: %0d.", total_errors);

        // ---------------------------------------------------------------------
        // Test 3: Pipelined Multiplier 2 Stages (PIPELINE_STAGES = 2)
        // ---------------------------------------------------------------------
        $display("\n>>> 3. Testing 2-Stage Pipelined Multiplier (10,000 Vectors)...");
        begin
            logic signed [15:0] pipe2_a_hist [0:10005];
            logic signed [15:0] pipe2_b_hist [0:10005];

            for (int i = 0; i < 10000; i++) begin
                rand_a = $urandom;
                rand_b = $urandom;

                @(posedge clk);
                #1; // Sample output from 2 cycles ago
                if (i >= 2) begin
                    exp_p = $signed(pipe2_a_hist[i-2]) * $signed(pipe2_b_hist[i-2]);
                    if (p2 !== exp_p) begin
                        $display("[FAIL PIPE2 @ %0d]: a=%d, b=%d -> HW=%d, EXP=%d",
                                 i-2, pipe2_a_hist[i-2], pipe2_b_hist[i-2], p2, exp_p);
                        total_errors++;
                        if (total_errors > 20) break;
                    end
                end

                // Drive new inputs
                a2 = rand_a;
                b2 = rand_b;
                pipe2_a_hist[i] = rand_a;
                pipe2_b_hist[i] = rand_b;
            end
        end
        $display("  2-stage pipelined multiplier passed cumulative errors: %0d.", total_errors);

        // ---------------------------------------------------------------------
        // Final Summary
        // ---------------------------------------------------------------------
        $display("\n=========================================================================");
        if (total_errors == 0) begin
            $display("   ALL RADIX-4 BOOTH MULTIPLIER TESTS PASSED (0 ERRORS)!                 ");
        end else begin
            $display("   TESTS FAILED WITH %0d ERRORS!                                         ", total_errors);
        end
        $display("=========================================================================\n");

        $finish;
    end

endmodule : booth_radix4_multiplier_TB
