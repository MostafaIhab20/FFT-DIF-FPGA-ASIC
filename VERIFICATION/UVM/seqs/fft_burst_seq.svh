// =============================================================================
// File Name      : fft_burst_seq.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-06
// Version        : 3.0 (Virtual Sequence with Reactive Interrupt Synchronization)
// Description    : Burst verification sequence exercising multi-beat pipelined
//                  burst transfers (INCR4, INCR8, INCR16, WRAP4) for FIFO streaming
//                  with reactive sideband interrupt synchronization.
// =============================================================================

`ifndef FFT_BURST_SEQ_SVH
`define FFT_BURST_SEQ_SVH

class fft_burst_seq extends fft_base_vseq;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(fft_burst_seq)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_burst_seq");
        super.new(name);
    endfunction

    // ==================================================
    // Sequence Body Task
    // ==================================================
    virtual task body();
        uvm_status_e   status;
        uvm_reg_data_t rdata;
        bit [31:0]     burst_16[];
        bit [31:0]     burst_8[];
        bit [31:0]     burst_4[];
        bit [31:0]     read_chunk[];

        `uvm_info("BURST_SEQ", "Starting FFT Burst Verification Sequence...", UVM_LOW)

        // ==================================================
        // Configurations
        // ==================================================
        // Peripheral Identification Check via RAL
        reg_model.reg_id.read(status, rdata);
        `uvm_info("BURST_SEQ", $sformatf("Read IP ID: 0x%08h", rdata), UVM_LOW)

        reg_model.reg_version.read(status, rdata);
        `uvm_info("BURST_SEQ", $sformatf("Read IP Version: 0x%08h", rdata), UVM_LOW)

        // Configure Frame Done Interrupt via RAL
        reg_model.reg_int_en.write(status, 32'h01);
        reg_model.reg_int_en.read(status, rdata);
        `uvm_info("BURST_SEQ", $sformatf("Configured INT_EN: 0x%08h", rdata), UVM_LOW)

        // ==================================================
        // Test Scenario
        // ==================================================
        // Prepare Test Payloads (DC Complex Samples: Re = 0x6CCD, Im = 0x0000)
        burst_16 = new[16];
        foreach (burst_16[i]) burst_16[i] = 32'h6CCD_0000;

        burst_8 = new[8];
        foreach (burst_8[i]) burst_8[i] = 32'h6CCD_0000;

        burst_4 = new[4];
        foreach (burst_4[i]) burst_4[i] = 32'h6CCD_0000;

        // Frame 1: Stream using INCR16, INCR8, INCR4, WRAP4
        `uvm_info("BURST_SEQ", "Frame 1: Streaming 16 samples via INCR16 burst...", UVM_LOW)
        push_samples_burst(burst_16, HBURST_INCR16);

        `uvm_info("BURST_SEQ", "Frame 1: Streaming 8 samples via INCR8 burst...", UVM_LOW)
        push_samples_burst(burst_8, HBURST_INCR8);

        `uvm_info("BURST_SEQ", "Frame 1: Streaming 4 samples via INCR4 burst...", UVM_LOW)
        push_samples_burst(burst_4, HBURST_INCR4);

        `uvm_info("BURST_SEQ", "Frame 1: Streaming 4 samples via WRAP4 burst...", UVM_LOW)
        push_samples_burst(burst_4, HBURST_WRAP4);

        // Verify IN FIFO level (expecting 32 samples loaded) via RAL
        reg_model.reg_in_level.read(status, rdata);
        `uvm_info("BURST_SEQ", $sformatf("IN FIFO Level prior to processing: %0d", rdata), UVM_LOW)

        // Start Core Processing (CTRL[0] = 1) via RAL
        `uvm_info("BURST_SEQ", "Enabling FFT Core (CTRL[0] = 1)...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h01);

        // Await Frame 1 completion reactively via sideband IRQ
        `uvm_info("BURST_SEQ", "Frame 1: Waiting on sideband agent for IRQ assertion...", UVM_MEDIUM)
        wait_for_irq(1'b1);
        wait_for_out_level(32, 2000);
        wait_for_idle(2000);

        // Read 32 FFT Output Bins from OUT FIFO using diverse bursts
        `uvm_info("BURST_SEQ", "Frame 1: Popping 4 bins via WRAP4 burst...", UVM_LOW)
        pop_samples_burst(read_chunk, 4, HBURST_WRAP4);

        `uvm_info("BURST_SEQ", "Frame 1: Popping 4 bins via INCR4 burst...", UVM_LOW)
        pop_samples_burst(read_chunk, 4, HBURST_INCR4);

        `uvm_info("BURST_SEQ", "Frame 1: Popping 8 bins via INCR8 burst...", UVM_LOW)
        pop_samples_burst(read_chunk, 8, HBURST_INCR8);

        `uvm_info("BURST_SEQ", "Frame 1: Popping 16 bins via INCR16 burst...", UVM_LOW)
        pop_samples_burst(read_chunk, 16, HBURST_INCR16);

        // Clear FRAME_DONE interrupt via RAL (W1C)
        reg_model.reg_int_status.write(status, 32'h01);
        wait_for_irq(1'b0);
        `uvm_info("BURST_SEQ", "Frame 1: PASS: IRQ deasserted after W1C clear", UVM_MEDIUM)

        // Frame 2: Stream using WRAP16, WRAP8, INCR, SINGLE
        `uvm_info("BURST_SEQ", "Frame 2: Streaming 16 samples via WRAP16 burst...", UVM_LOW)
        push_samples_burst(burst_16, HBURST_WRAP16);

        `uvm_info("BURST_SEQ", "Frame 2: Streaming 8 samples via WRAP8 burst...", UVM_LOW)
        push_samples_burst(burst_8, HBURST_WRAP8);

        `uvm_info("BURST_SEQ", "Frame 2: Streaming 4 samples via INCR burst...", UVM_LOW)
        push_samples_burst(burst_4, HBURST_INCR);

        `uvm_info("BURST_SEQ", "Frame 2: Streaming 4 samples via SINGLE writes...", UVM_LOW)
        for (int i = 0; i < 4; i++) begin
            push_sample(burst_4[i]);
        end

        // Await Frame 2 completion reactively via sideband IRQ
        `uvm_info("BURST_SEQ", "Frame 2: Waiting on sideband agent for IRQ assertion...", UVM_MEDIUM)
        wait_for_irq(1'b1);
        wait_for_out_level(32, 2000);
        wait_for_idle(2000);

        // Read 32 FFT Output Bins from Frame 2 using WRAP16, WRAP8, INCR, SINGLE
        `uvm_info("BURST_SEQ", "Frame 2: Popping 16 bins via WRAP16 burst...", UVM_LOW)
        pop_samples_burst(read_chunk, 16, HBURST_WRAP16);

        `uvm_info("BURST_SEQ", "Frame 2: Popping 8 bins via WRAP8 burst...", UVM_LOW)
        pop_samples_burst(read_chunk, 8, HBURST_WRAP8);

        `uvm_info("BURST_SEQ", "Frame 2: Popping 4 bins via INCR burst...", UVM_LOW)
        pop_samples_burst(read_chunk, 4, HBURST_INCR);

        `uvm_info("BURST_SEQ", "Frame 2: Popping 4 bins via SINGLE reads...", UVM_LOW)
        for (int i = 0; i < 4; i++) begin
            bit [31:0] s;
            pop_sample(s);
        end

        // Clear FRAME_DONE interrupt via RAL (W1C)
        reg_model.reg_int_status.write(status, 32'h01);
        wait_for_irq(1'b0);
        `uvm_info("BURST_SEQ", "Frame 2: PASS: IRQ deasserted after W1C clear", UVM_MEDIUM)

        // Disable FFT Core via RAL
        reg_model.reg_ctrl.write(status, 32'h00);

        `uvm_info("BURST_SEQ", "FFT Burst Verification Sequence completed successfully!", UVM_LOW)
    endtask

endclass : fft_burst_seq

`endif // FFT_BURST_SEQ_SVH
