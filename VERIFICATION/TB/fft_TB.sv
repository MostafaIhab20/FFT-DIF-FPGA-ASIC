// =============================================================================
// File Name      : fft_TB.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-09-28
// Version        : 1.0
// Description    : Self-checking multi-frame SystemVerilog testbench for Parameterized
//                  Radix-2 DIF R2SDF pipelined FFT (supports arbitrary N).
//                  Features:
//                    - Parameterized FFT points (parameter int N = 32)
//                    - Parameterized multiplier latency (parameter int MULT_PIPE_STAGES = 0)
//                    - Parameterized frame count (default: 100 frames)
//                    - 100% duty-cycle continuous streaming injection
//                    - Automatic pipeline flush verification upon valid_in deassertion
//                    - Expected latency check: (N - 1) + log2(N) + (log2(N)-2)*MULT_PIPE_STAGES + 1
//                    - Cycle-by-cycle exact bit-comparison against golden reference
//                    - Comprehensive reporting (latency, max LSB diff, frame progress)
// =============================================================================

`timescale 1ns / 1ps

import fft_pkg::*;

module fft_TB #(
    parameter int N                = 32,
    parameter int MULT_PIPE_STAGES = 0
);

    // =========================================================================
    // Simulation Parameters
    // =========================================================================
    localparam time CLK_PERIOD         = 10ns; // 100 MHz system clock
    localparam int  NUM_STAGES         = $clog2(N);
    localparam int  MULT_STAGES        = (NUM_STAGES > 2) ? (NUM_STAGES - 2) : 0;
    localparam int  TOTAL_MULT_LAT     = MULT_STAGES * MULT_PIPE_STAGES;
    localparam int  PIPELINE_LAT       = (N - 1) + NUM_STAGES + TOTAL_MULT_LAT + 1;
    localparam int  DEFAULT_NUM_FRAMES = 100;
    localparam int  MAX_SAMPLES        = 65536;

    // =========================================================================
    // Signal & Variable Declarations
    // =========================================================================
    // Runtime Frame & Sample Counts
    int num_frames;
    int total_samples;

    // Device Under Test (DUT) Interface Signals
    logic               clk;
    logic               rst_n;
    logic               clk_en;
    logic               valid_in;
    logic signed [15:0] in_data_re;
    logic signed [15:0] in_data_im;
    logic               valid_out;
    logic signed [15:0] out_data_re;
    logic signed [15:0] out_data_im;

    // Golden & Stimulus Memory Arrays (32-bit hex: [31:16] = Re, [15:0] = Im)
    logic [31:0]        stim_mem   [0:MAX_SAMPLES-1];
    logic [31:0]        golden_mem [0:MAX_SAMPLES-1];

    // File Path Strings Dynamically Constructed Based on N
    string              stim_file   = $sformatf("../model/stimulus_%0d.mem", N);
    string              golden_file = $sformatf("../model/golden_%0d.mem", N);

    // Verification Tracking & Error Counters
    int                 error_count;
    int                 sample_out_cnt;
    int                 latency_cycles;
    bit                 latency_captured;
    int                 max_abs_diff_re;
    int                 max_abs_diff_im;

    // Latency Measurement Internal Signals
    int                 cycle_cnt;
    bit                 measuring;

    // Output Monitor and Checker Variables
    logic signed [15:0] exp_re;
    logic signed [15:0] exp_im;
    int                 diff_re;
    int                 diff_im;
    int                 cur_frame;
    int                 cur_sample_in_frame;

    // ---------------------------------------------------------------------
    // DUT Instantiation (Parameterized Core)
    // ---------------------------------------------------------------------
    fft_top #(
        .N                (N),
        .MULT_PIPE_STAGES (MULT_PIPE_STAGES)
    ) u_dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .clk_en      (clk_en),
        .valid_in    (valid_in),
        .in_data_re  (in_data_re),
        .in_data_im  (in_data_im),
        .valid_out   (valid_out),
        .out_data_re (out_data_re),
        .out_data_im (out_data_im)
    );

    // ---------------------------------------------------------------------
    // Clock Generation (100 MHz)
    // ---------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ---------------------------------------------------------------------
    // Main Verification Process
    // ---------------------------------------------------------------------
    initial begin
        num_frames = DEFAULT_NUM_FRAMES;
        void'($value$plusargs("NUM_FRAMES=%d", num_frames));
        void'($value$plusargs("STIM_FILE=%s", stim_file));
        void'($value$plusargs("GOLDEN_FILE=%s", golden_file));

        total_samples = num_frames * N;

        $display("\n=========================================================================");
        $display("   STARTING MULTI-FRAME TESTBENCH: %0d-Point Radix-2 DIF R2SDF FFT       ", N);
        $display("=========================================================================");
        $display("  FFT Points (N)        : %0d", N);
        $display("  Multiplier Stages (P) : %0d", MULT_PIPE_STAGES);
        $display("  Expected Latency      : %0d clock cycles", PIPELINE_LAT);
        $display("  Target Frames         : %0d frames (%0d complex samples)", num_frames, total_samples);
        $display("  Clock Period          : %0t", CLK_PERIOD);
        $display("  Stimulus File         : %s", stim_file);
        $display("  Golden File           : %s\n", golden_file);

        // Load test vectors into memory
        $readmemh(stim_file, stim_mem);
        $readmemh(golden_file, golden_mem);

        // Initialize DUT Inputs
        clk_en     = 1'b1;
        valid_in   = 1'b0;
        in_data_re = '0;
        in_data_im = '0;
        rst_n      = 1'b0;

        // Apply Reset for 5 clock cycles
        #(CLK_PERIOD * 5);
        @(negedge clk);
        rst_n = 1'b1;
        $display("[%0t] Reset released. Injecting %0d frames continuously (100%% duty cycle)...", $time, num_frames);

        // Continuous streaming of all frames
        @(negedge clk);
        for (int i = 0; i < total_samples; i++) begin
            valid_in   = 1'b1;
            in_data_re = signed'(stim_mem[i][31:16]);
            in_data_im = signed'(stim_mem[i][15:0]);
            @(negedge clk);
        end

        // Deassert valid_in after streaming all frames (test core auto-flush)
        valid_in   = 1'b0;
        in_data_re = '0;
        in_data_im = '0;
        $display("[%0t] All %0d input samples streamed. Waiting for remaining pipeline flush...", $time, total_samples);

        // Wait until all outputs are received
        wait(sample_out_cnt == total_samples);
        @(posedge clk);
        #(CLK_PERIOD * 5);

        // -----------------------------------------------------------------
        // Final Summary Report
        // -----------------------------------------------------------------
        $display("\n=========================================================================");
        $display("                         SIMULATION SUMMARY REPORT                       ");
        $display("=========================================================================");
        $display("  FFT Points (N)       : %0d", N);
        $display("  Multiplier Stages (P): %0d", MULT_PIPE_STAGES);
        $display("  Total Frames Tested  : %0d", num_frames);
        $display("  Total Samples Tested : %0d", total_samples);
        $display("  Pipeline Latency     : %0d clock cycles (Expected: %0d)", latency_cycles, PIPELINE_LAT);
        $display("  Max Abs Diff (Re)    : %0d LSB", max_abs_diff_re);
        $display("  Max Abs Diff (Im)    : %0d LSB", max_abs_diff_im);
        $display("  Total Error Samples  : %0d", error_count);
        $display("  -----------------------------------------------------------------------");
        if (error_count == 0 && latency_cycles == PIPELINE_LAT) begin
            $display("  FINAL VERDICT        : *** ALL %0d FRAMES PASSED (100%% BIT-ACCURATE) ***", num_frames);
        end else begin
            $display("  FINAL VERDICT        : *** SIMULATION FAILED WITH %0d ERRORS ***", error_count);
        end
        $display("=========================================================================\n");

        $finish;
    end

    // ---------------------------------------------------------------------
    // Latency Counter (from first valid_in to first valid_out)
    // ---------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            cycle_cnt <= 0;
            measuring <= 0;
        end else begin
            if (valid_in && !measuring) begin
                measuring <= 1;
                cycle_cnt <= 1;
            end else if (measuring && !latency_captured) begin
                cycle_cnt <= cycle_cnt + 1;
                if (valid_out) begin
                    latency_cycles   <= cycle_cnt;
                    latency_captured <= 1;
                    measuring        <= 0;
                end
            end
        end
    end

    // ---------------------------------------------------------------------
    // Output Monitor and Checker
    // ---------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst_n && valid_out) begin
            cur_frame           = sample_out_cnt / N;
            cur_sample_in_frame = sample_out_cnt % N;

            exp_re = signed'(golden_mem[sample_out_cnt][31:16]);
            exp_im = signed'(golden_mem[sample_out_cnt][15:0]);

            diff_re = out_data_re - exp_re;
            diff_im = out_data_im - exp_im;

            // Track maximum LSB difference
            if (diff_re < 0 && -diff_re > max_abs_diff_re) max_abs_diff_re = -diff_re;
            if (diff_re > 0 &&  diff_re > max_abs_diff_re) max_abs_diff_re =  diff_re;
            if (diff_im < 0 && -diff_im > max_abs_diff_im) max_abs_diff_im = -diff_im;
            if (diff_im > 0 &&  diff_im > max_abs_diff_im) max_abs_diff_im =  diff_im;

            // Frame 1 detailed table printout (first N samples)
            if (sample_out_cnt < N) begin
                if (sample_out_cnt == 0) begin
                    $display("\n--- Detailed Output Check: Frame 1 (First %0d Samples) ---", N);
                    $display("  Bin | Hardware (Re, Im) | Golden (Re, Im)   | Diff (Re, Im) | Status");
                    $display("  ----+-------------------+-------------------+---------------+--------");
                end
                $display("   %2d |  %6d, %6d  |  %6d, %6d  |   %3d, %3d   | %s",
                         sample_out_cnt,
                         out_data_re, out_data_im,
                         exp_re, exp_im,
                         diff_re, diff_im,
                         (diff_re == 0 && diff_im == 0) ? "PASS" : "FAIL ***");
            end

            // Error tracking
            if (diff_re != 0 || diff_im != 0) begin
                error_count++;
                if (error_count <= 20) begin
                    $display("  [ERROR @ Frame %0d, Bin %0d]: HW=(%d, %d) != GOLD=(%d, %d) Diff=(%d, %d)",
                             cur_frame, cur_sample_in_frame, out_data_re, out_data_im, exp_re, exp_im, diff_re, diff_im);
                end
            end

            // Progress report every 10 frames
            if (cur_sample_in_frame == N - 1) begin
                if ((cur_frame + 1) % 10 == 0 || (cur_frame + 1) == num_frames) begin
                    $display("  • Progress: Frame %3d / %0d completed | %4d samples checked | Errors: %0d",
                             cur_frame + 1, num_frames, sample_out_cnt + 1, error_count);
                end
            end

            sample_out_cnt++;
        end
    end

    // Dynamic Timeout Watchdog
    initial begin
        #(CLK_PERIOD * (MAX_SAMPLES + 5000));
        $display("\n[FATAL] Simulation TIMEOUT watchdog reached!");
        $finish;
    end

endmodule : fft_TB
