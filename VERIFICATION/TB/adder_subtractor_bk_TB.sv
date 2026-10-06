// =============================================================================
// File Name      : adder_subtractor_bk_TB.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-09-27
// Version        : 1.0
// Description    : Self-checking unit testbench for parameterized Brent-Kung
//                  unified adder/subtractor. Verifies WIDTH=18, 32, and 33
//                  across corner cases and 10,000+ random stimulus vectors
//                  in both addition and subtraction modes.
// =============================================================================

`timescale 1ns / 1ps

module adder_subtractor_bk_TB;

    int total_errors = 0;

    // -------------------------------------------------------------------------
    // Task to test arbitrary width
    // -------------------------------------------------------------------------
    // We instantiate 3 instances for the widths relevant to our FFT:
    //  - 18-bit (Butterfly PE)
    //  - 32-bit (Multiplier final adder)
    //  - 33-bit (Complex Multiplier accumulate / subtract)

    // 18-bit Signals
    logic [17:0] a18, b18, sum18;
    logic        sub18, cout18, ovf18;

    adder_subtractor_bk #(.WIDTH(18)) u_dut18 (
        .a        (a18),
        .b        (b18),
        .sub      (sub18),
        .sum      (sum18),
        .cout     (cout18),
        .overflow (ovf18)
    );

    // 32-bit Signals
    logic [31:0] a32, b32, sum32;
    logic        sub32, cout32, ovf32;

    adder_subtractor_bk #(.WIDTH(32)) u_dut32 (
        .a        (a32),
        .b        (b32),
        .sub      (sub32),
        .sum      (sum32),
        .cout     (cout32),
        .overflow (ovf32)
    );

    // 33-bit Signals
    logic [32:0] a33, b33, sum33;
    logic        sub33, cout33, ovf33;

    adder_subtractor_bk #(.WIDTH(33)) u_dut33 (
        .a        (a33),
        .b        (b33),
        .sub      (sub33),
        .sum      (sum33),
        .cout     (cout33),
        .overflow (ovf33)
    );

    initial begin : proc_test
        logic [18:0] exp18;
        logic [32:0] exp32;
        logic [33:0] exp33;

        $display("\n=========================================================================");
        $display("   TESTBENCH: Parameterized Brent-Kung Unified Adder/Subtractor          ");
        $display("=========================================================================");

        // ---------------------------------------------------------------------
        // 18-Bit Adder and Subtractor Verification (Butterfly PE)
        // ---------------------------------------------------------------------
        $display("\n>>> Starting 18-bit Adder/Subtractor Verification (10,000 vectors)...");
        for (int i = 0; i < 10000; i++) begin
            a18   = $urandom;
            b18   = $urandom;
            sub18 = $urandom_range(0, 1);
            #1;

            if (sub18 == 1'b0) begin
                exp18 = {1'b0, a18} + {1'b0, b18};
                if (sum18 !== exp18[17:0] || cout18 !== exp18[18]) begin
                    $display("[FAIL 18-bit ADD @ %0d]: a=%h, b=%h -> HW_sum=%h (exp=%h), HW_cout=%b (exp=%b)",
                             i, a18, b18, sum18, exp18[17:0], cout18, exp18[18]);
                    total_errors++;
                end
            end else begin
                exp18 = {1'b0, a18} + {1'b0, ~b18} + 19'd1;
                if (sum18 !== exp18[17:0] || cout18 !== exp18[18]) begin
                    $display("[FAIL 18-bit SUB @ %0d]: a=%h, b=%h -> HW_sum=%h (exp=%h), HW_cout=%b (exp=%b)",
                             i, a18, b18, sum18, exp18[17:0], cout18, exp18[18]);
                    total_errors++;
                end
            end
        end
        $display("  18-bit test finished with %0d errors.", total_errors);

        // ---------------------------------------------------------------------
        // 32-Bit Adder and Subtractor Verification (Multiplier Core)
        // ---------------------------------------------------------------------
        $display("\n>>> Starting 32-bit Adder/Subtractor Verification (10,000 vectors)...");
        for (int i = 0; i < 10000; i++) begin
            a32   = {$urandom, $urandom};
            b32   = {$urandom, $urandom};
            sub32 = $urandom_range(0, 1);
            #1;

            if (sub32 == 1'b0) begin
                exp32 = {1'b0, a32} + {1'b0, b32};
                if (sum32 !== exp32[31:0] || cout32 !== exp32[32]) begin
                    $display("[FAIL 32-bit ADD @ %0d]: a=%h, b=%h -> HW_sum=%h (exp=%h), HW_cout=%b (exp=%b)",
                             i, a32, b32, sum32, exp32[31:0], cout32, exp32[32]);
                    total_errors++;
                end
            end else begin
                exp32 = {1'b0, a32} + {1'b0, ~b32} + 33'd1;
                if (sum32 !== exp32[31:0] || cout32 !== exp32[32]) begin
                    $display("[FAIL 32-bit SUB @ %0d]: a=%h, b=%h -> HW_sum=%h (exp=%h), HW_cout=%b (exp=%b)",
                             i, a32, b32, sum32, exp32[31:0], cout32, exp32[32]);
                    total_errors++;
                end
            end
        end
        $display("  32-bit test finished with %0d errors cumulative.", total_errors);

        // ---------------------------------------------------------------------
        // 33-Bit Adder and Subtractor Verification (Accumulator)
        // ---------------------------------------------------------------------
        $display("\n>>> Starting 33-bit Adder/Subtractor Verification (10,000 vectors)...");
        for (int i = 0; i < 10000; i++) begin
            a33   = {$urandom_range(0, 1), $urandom, $urandom};
            b33   = {$urandom_range(0, 1), $urandom, $urandom};
            sub33 = $urandom_range(0, 1);
            #1;

            if (sub33 == 1'b0) begin
                exp33 = {1'b0, a33} + {1'b0, b33};
                if (sum33 !== exp33[32:0] || cout33 !== exp33[33]) begin
                    $display("[FAIL 33-bit ADD @ %0d]: a=%h, b=%h -> HW_sum=%h (exp=%h), HW_cout=%b (exp=%b)",
                             i, a33, b33, sum33, exp33[32:0], cout33, exp33[33]);
                    total_errors++;
                end
            end else begin
                exp33 = {1'b0, a33} + {1'b0, ~b33} + 34'd1;
                if (sum33 !== exp33[32:0] || cout33 !== exp33[33]) begin
                    $display("[FAIL 33-bit SUB @ %0d]: a=%h, b=%h -> HW_sum=%h (exp=%h), HW_cout=%b (exp=%b)",
                             i, a33, b33, sum33, exp33[32:0], cout33, exp33[33]);
                    total_errors++;
                end
            end
        end
        $display("  33-bit test finished with %0d errors cumulative.", total_errors);

        // ---------------------------------------------------------------------
        // Boundary and Arithmetic Corner Case Verification
        // ---------------------------------------------------------------------
        $display("\n>>> Testing Specific Corner Cases...");
        // 18-bit corner cases
        a18 = 18'sh3FFFF; b18 = 18'sh00001; sub18 = 0; #1; // -1 + 1 = 0
        if (sum18 !== 18'h0) total_errors++;
        a18 = 18'sh00000; b18 = 18'sh00001; sub18 = 1; #1; // 0 - 1 = -1
        if (sum18 !== 18'h3FFFF) total_errors++;

        $display("\n=========================================================================");
        if (total_errors == 0) begin
            $display("   ALL BRENT-KUNG ADDER/SUBTRACTOR TESTS PASSED (0 ERRORS)!              ");
        end else begin
            $display("   TESTS FAILED WITH %0d ERRORS!                                         ", total_errors);
        end
        $display("=========================================================================\n");

        $finish;
    end

endmodule : adder_subtractor_bk_TB
