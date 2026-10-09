// =============================================================================
// File Name      : fft_coverage_closure_seq.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-07
// Version        : 2.0 (Direct RAL Control & FIFO Streaming)
// Description    : Corner-case coverage closure stimulus sequence.
//                  Targets butterfly clamping boundaries, multiplier saturation,
//                  backpressure core stalling, unaligned wait-state assertions,
//                  and bus transfer condition toggle permutations.
// =============================================================================

`ifndef FFT_COVERAGE_CLOSURE_SEQ_SVH
`define FFT_COVERAGE_CLOSURE_SEQ_SVH

class fft_coverage_closure_seq extends fft_base_vseq;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(fft_coverage_closure_seq)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_coverage_closure_seq");
        super.new(name);
    endfunction

    // ==================================================
    // Sequence Body Task
    // ==================================================
    virtual task body();
        uvm_status_e   status;
        uvm_reg_data_t rdata;
        bit [31:0]     frame_samples[32];
        bit [31:0]     burst_err_payload[4];

        `uvm_info("COV_CLOSURE_SEQ", "Starting FFT Coverage Closure Verification Sequence...", UVM_LOW)

        // ==================================================
        // Configurations
        // ==================================================
        // Read Identification Registers via RAL
        reg_model.reg_id.read(status, rdata);
        reg_model.reg_version.read(status, rdata);

        // Enable Frame Done and Error Interrupts via RAL
        reg_model.reg_int_en.write(status, 32'h07);

        // ==================================================
        // Test Scenario
        // ==================================================
        // Phase 1: Butterfly Saturation Clamping Across All 5 Stages
        // (Clamps when A - B + 1 == 65536: A = +32767 [0x7FFF], B = -32768 [0x8000])
        // =====================================================================
        `uvm_info("COV_CLOSURE_SEQ", "Phase 1: Testing Butterfly Clamping & Multiplier Saturation...", UVM_LOW)

        // Vector 0: Stage 0 (Delay = 16) -> First 16 samples +32767, last 16 samples -32768
        for (int i = 0; i < 32; i++) begin
            if (i < 16) frame_samples[i] = 32'h7FFF_7FFF; // Re = +32767, Im = +32767
            else        frame_samples[i] = 32'h8000_8000; // Re = -32768, Im = -32768
        end
        run_frame_test(frame_samples, "Stage 0 (Delay 16) Saturation Vector");

        // Vector 1: Stage 1 (Delay = 8) -> Blocks of 8 samples +32767 and 8 samples -32768
        for (int i = 0; i < 32; i++) begin
            if ((i / 8) % 2 == 0) frame_samples[i] = 32'h7FFF_7FFF;
            else                  frame_samples[i] = 32'h8000_8000;
        end
        run_frame_test(frame_samples, "Stage 1 (Delay 8) Saturation Vector");

        // Vector 2: Stage 2 (Delay = 4) -> Blocks of 4 samples +32767 and 4 samples -32768
        for (int i = 0; i < 32; i++) begin
            if ((i / 4) % 2 == 0) frame_samples[i] = 32'h7FFF_7FFF;
            else                  frame_samples[i] = 32'h8000_8000;
        end
        run_frame_test(frame_samples, "Stage 2 (Delay 4) Saturation Vector");

        // Vector 3: Stage 3 (Delay = 2) -> Blocks of 2 samples +32767 and 2 samples -32768
        for (int i = 0; i < 32; i++) begin
            if ((i / 2) % 2 == 0) frame_samples[i] = 32'h7FFF_7FFF;
            else                  frame_samples[i] = 32'h8000_8000;
        end
        run_frame_test(frame_samples, "Stage 3 (Delay 2) Saturation Vector");

        // Vector 4: Stage 4 (Delay = 1) -> Alternating samples +32767 and -32768
        for (int i = 0; i < 32; i++) begin
            if (i % 2 == 0) frame_samples[i] = 32'h7FFF_7FFF;
            else            frame_samples[i] = 32'h8000_8000;
        end
        run_frame_test(frame_samples, "Stage 4 (Delay 1) Saturation Vector");

        // Vector 5: Inverse Saturation (Negative first, then Positive)
        for (int i = 0; i < 32; i++) begin
            if (i < 16) frame_samples[i] = 32'h8000_8000;
            else        frame_samples[i] = 32'h7FFF_7FFF;
        end
        run_frame_test(frame_samples, "Inverse Sign Saturation Vector");

        // =====================================================================
        // Phase 2: Downstream Backpressure Stalling (clk_en = 0, ip_ce = 0)
        // =====================================================================
        `uvm_info("COV_CLOSURE_SEQ", "Phase 2: Testing Downstream Backpressure & Core Stalling...", UVM_LOW)

        // Load Frame 1 (32 samples) and enable core via RAL
        for (int i = 0; i < 32; i++) frame_samples[i] = 32'h1000_0000;
        for (int i = 0; i < 32; i++) push_sample(frame_samples[i]);
        reg_model.reg_ctrl.write(status, 32'h01); // Enable core

        // Wait until OUT FIFO holds 32 samples (Do NOT pop them yet!)
        wait_for_out_level(32, 2000);
        wait_for_idle(2000);
        reg_model.reg_int_status.write(status, 32'h01); // Clear frame done

        // Immediately push Frame 2 (32 samples) into IN FIFO while OUT FIFO holds 32 samples
        for (int i = 0; i < 32; i++) push_sample(frame_samples[i]);

        // Await OUT FIFO reaching full capacity (64 samples)
        // Once OUT FIFO reaches 64 samples, ip_ce (~out_full) deasserts to 0 and stalls clk_en!
        wait_for_out_level(64, 2000);

        // Read STATUS register via RAL to confirm out_full is asserted
        reg_model.reg_status.read(status, rdata);
        `uvm_info("COV_CLOSURE_SEQ", $sformatf("STATUS with full OUT FIFO: 0x%08h (out_full bit = %0b)", rdata, rdata[4]), UVM_LOW)

        // Idle for 100 clock cycles while clk_en is stalled to ensure coverage sampling
        idle_cycles(100);

        // Pop all 64 samples from OUT FIFO to relieve backpressure and resume core
        for (int i = 0; i < 64; i++) begin
            bit [31:0] s;
            pop_sample(s);
        end

        // Await idle state and clear interrupts via RAL
        wait_for_idle(1000);
        reg_model.reg_int_status.write(status, 32'h07);
        reg_model.reg_ctrl.write(status, 32'h00); // Disable core

        // =====================================================================
        // Phase 3: Pipelined Error Wait State & SVA Stability Assertion
        // =====================================================================
        `uvm_info("COV_CLOSURE_SEQ", "Phase 3: Testing Pipelined Error Wait-State & SVA Stability...", UVM_LOW)

        // Issue a 4-beat burst to an unaligned address (0x001)
        // Beat 0 detects unaligned access -> Cycle 1 asserts HRESP_ERROR and deasserts HREADYOUT=0.
        // During Cycle 1, Beat 1 address phase is presented with HSEL=1, HTRANS=SEQ.
        // Because HREADYOUT=0, Beat 1 address/controls are held stable -> triggers assert_addr_ctrl_stable!
        foreach (burst_err_payload[i]) burst_err_payload[i] = 32'hA5A5_5A5A;
        write_burst(32'h001, burst_err_payload, HBURST_INCR4);

        // Allow bus recovery by performing a clean aligned read via RAL
        reg_model.reg_id.read(status, rdata);
        `uvm_info("COV_CLOSURE_SEQ", $sformatf("Bus recovered after pipelined error: ID = 0x%08h", rdata), UVM_LOW)

        // =====================================================================
        // Phase 4: Deselected Slave and Selected IDLE Transfers
        // =====================================================================
        `uvm_info("COV_CLOSURE_SEQ", "Phase 4: Testing Deselected Slave & Selected IDLE Transfers...", UVM_LOW)

        // Transfer 1: Deselected slave (HSEL = 0, HTRANS = NONSEQ) -> hits HSEL_0 in (HSEL & HTRANS[1])
        drive_raw_cycle(32'h000, 1'b0, HTRANS_NONSEQ, 1'b0);

        // Transfer 2: Selected IDLE (HSEL = 1, HTRANS = IDLE) -> hits HTRANS[1]_0 in (HSEL & HTRANS[1])
        drive_raw_cycle(32'h000, 1'b1, HTRANS_IDLE, 1'b0);

        // Transfer 3: Selected BUSY (HSEL = 1, HTRANS = BUSY)
        drive_raw_cycle(32'h000, 1'b1, HTRANS_BUSY, 1'b0);

        // Final verification read via RAL
        reg_model.reg_id.read(status, rdata);

        `uvm_info("COV_CLOSURE_SEQ", "FFT Coverage Closure Verification Sequence Completed Successfully!", UVM_LOW)
    endtask

    // Helper: Run an end-to-end frame test and drain output
    virtual task run_frame_test(input bit [31:0] samples[32], input string desc);
        uvm_status_e status;
        bit [31:0]   out_val;

        `uvm_info("COV_CLOSURE_FRAME", $sformatf("Streaming frame: %s", desc), UVM_MEDIUM)

        // Push 32 samples into IN FIFO
        for (int i = 0; i < 32; i++) begin
            push_sample(samples[i]);
        end

        // Enable FFT Core via RAL
        reg_model.reg_ctrl.write(status, 32'h01);

        // Wait for reactive sideband IRQ & output bins
        wait_for_irq(1'b1);
        wait_for_out_level(32, 2000);
        wait_for_idle(2000);

        // Pop 32 output bins
        for (int i = 0; i < 32; i++) begin
            pop_sample(out_val);
        end

        // Clear interrupt via RAL (W1C)
        reg_model.reg_int_status.write(status, 32'h01);
        wait_for_irq(1'b0);

        // Disable FFT Core via RAL
        reg_model.reg_ctrl.write(status, 32'h00);
    endtask

    // Helper: Drive raw cycle with explicit HSEL and HTRANS
    virtual task drive_raw_cycle(
        input bit [31:0]  target_addr,
        input bit         target_sel,
        input ahb_trans_e target_trans,
        input bit         target_write
    );
        ahb_seq_item req = ahb_seq_item::type_id::create("req");
        start_item(req, -1, ahb_sqr);
        if (!req.randomize() with {
            req.addr  == target_addr;
            req.sel   == target_sel;
            req.trans == target_trans;
            req.write == target_write;
            req.burst == HBURST_SINGLE;
            req.size  == HSIZE_WORD;
        }) begin
            `uvm_fatal("COV_CLOSURE_SEQ", "Randomization failed for drive_raw_cycle")
        end
        finish_item(req);
    endtask

endclass : fft_coverage_closure_seq

`endif // FFT_COVERAGE_CLOSURE_SEQ_SVH
