// =============================================================================
// File Name      : fft_burst_seq.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-06
// Version        : 1.0
// Description    : Burst verification sequence exercising multi-beat pipelined
//                  burst transfers (INCR4, INCR8, INCR16, WRAP4) for FIFO streaming.
// =============================================================================

`ifndef FFT_BURST_SEQ_SVH
`define FFT_BURST_SEQ_SVH

class fft_burst_seq extends fft_base_seq;

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
        bit [31:0] rdata;
        bit [31:0] burst_16[];
        bit [31:0] burst_8[];
        bit [31:0] burst_4[];
        bit [31:0] read_chunk[];

        `uvm_info("BURST_SEQ", "Starting FFT Burst Verification Sequence...", UVM_LOW)

        // Peripheral Identification
        read_reg(ADDR_ID, rdata);
        `uvm_info("BURST_SEQ", $sformatf("Read IP ID: 0x%08h", rdata), UVM_LOW)

        read_reg(ADDR_VERSION, rdata);
        `uvm_info("BURST_SEQ", $sformatf("Read IP Version: 0x%08h", rdata), UVM_LOW)

        // Enable Frame Done Interrupt
        write_reg(ADDR_INT_EN, 32'h01);
        read_reg(ADDR_INT_EN, rdata);
        `uvm_info("BURST_SEQ", $sformatf("Configured INT_EN: 0x%08h", rdata), UVM_LOW)

        // Prepare Test Payloads (DC Complex Samples: Re = 0x6CCD, Im = 0x0000)
        burst_16 = new[16];
        foreach (burst_16[i]) burst_16[i] = 32'h6CCD_0000;

        burst_8 = new[8];
        foreach (burst_8[i]) burst_8[i] = 32'h6CCD_0000;

        burst_4 = new[4];
        foreach (burst_4[i]) burst_4[i] = 32'h6CCD_0000;

        // Streaming Input Samples using Multiple Burst Types into FIFO Window
        `uvm_info("BURST_SEQ", "Streaming 16 samples via INCR16 burst...", UVM_LOW)
        push_samples_burst(burst_16, HBURST_INCR16);

        `uvm_info("BURST_SEQ", "Streaming 8 samples via INCR8 burst...", UVM_LOW)
        push_samples_burst(burst_8, HBURST_INCR8);

        `uvm_info("BURST_SEQ", "Streaming 4 samples via INCR4 burst...", UVM_LOW)
        push_samples_burst(burst_4, HBURST_INCR4);

        `uvm_info("BURST_SEQ", "Streaming 4 samples via WRAP4 burst...", UVM_LOW)
        push_samples_burst(burst_4, HBURST_WRAP4);

        // Verify IN FIFO level (expecting 32 samples loaded)
        read_reg(ADDR_IN_LEVEL, rdata);
        `uvm_info("BURST_SEQ", $sformatf("IN FIFO Level prior to processing: %0d", rdata), UVM_LOW)

        // Start Core Processing (CTRL[0] = 1)
        `uvm_info("BURST_SEQ", "Enabling FFT Core (CTRL[0] = 1)...", UVM_LOW)
        write_reg(ADDR_CTRL, 32'h01);

        // Await frame completion and output availability
        wait_for_out_level(32, 2000);
        wait_for_idle(2000);

        // Check Interrupt Status
        read_reg(ADDR_INT_STATUS, rdata);
        `uvm_info("BURST_SEQ", $sformatf("INT_STATUS after processing: 0x%08h", rdata), UVM_LOW)

        // Read 32 FFT Output Bins from OUT FIFO using Burst Reads
        `uvm_info("BURST_SEQ", "Popping first 16 output bins via INCR16 burst...", UVM_LOW)
        pop_samples_burst(read_chunk, 16, HBURST_INCR16);

        `uvm_info("BURST_SEQ", "Popping remaining 16 output bins via INCR16 burst...", UVM_LOW)
        pop_samples_burst(read_chunk, 16, HBURST_INCR16);

        // Clear FRAME_DONE interrupt via W1C
        write_reg(ADDR_INT_STATUS, 32'h01);
        read_reg(ADDR_INT_STATUS, rdata);
        `uvm_info("BURST_SEQ", $sformatf("INT_STATUS after W1C clear: 0x%08h", rdata), UVM_LOW)

        // Disable FFT Core
        write_reg(ADDR_CTRL, 32'h00);

        `uvm_info("BURST_SEQ", "FFT Burst Verification Sequence completed successfully!", UVM_LOW)
    endtask

endclass : fft_burst_seq

`endif // FFT_BURST_SEQ_SVH
