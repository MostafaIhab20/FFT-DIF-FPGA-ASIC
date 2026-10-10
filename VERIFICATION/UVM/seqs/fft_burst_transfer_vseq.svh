// =============================================================================
// File Name      : fft_burst_transfer_vseq.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-06
// Version        : 4.0
// Description    : Pipelined AHB burst transfer virtual sequence exercising all
//                  AMBA AHB-Lite burst types (INCR4, INCR8, INCR16, WRAP4,
//                  WRAP8, WRAP16, INCR, and SINGLE) for FIFO streaming
//                  with reactive sideband interrupt synchronization.
// =============================================================================

`ifndef FFT_BURST_TRANSFER_VSEQ_SVH
`define FFT_BURST_TRANSFER_VSEQ_SVH

class fft_burst_transfer_vseq extends fft_base_vseq;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(fft_burst_transfer_vseq)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_burst_transfer_vseq");
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

        `uvm_info("BURST_TRANSFER_VSEQ", "Starting FFT Burst Transfer Verification Sequence...", UVM_LOW)

        // ==================================================
        // Configurations
        // ==================================================
        // Identification Check via RAL
        reg_model.reg_id.read(status, rdata);
        reg_model.reg_version.read(status, rdata);

        // Enable Frame Done Interrupt via RAL
        reg_model.reg_int_en.write(status, 32'h01);

        // ==================================================
        // Test Scenario
        // ==================================================
        // Prepare Test Payloads (DC Complex Samples: Re = 0x6CCD, Im = 0x0000)
        burst_16 = new[16]; foreach (burst_16[i]) burst_16[i] = 32'h6CCD_0000;
        burst_8  = new[8];  foreach (burst_8[i])  burst_8[i]  = 32'h6CCD_0000;
        burst_4  = new[4];  foreach (burst_4[i])  burst_4[i]  = 32'h6CCD_0000;

        // Frame 1: Stream using INCR16, INCR8, INCR4, WRAP4
        `uvm_info("BURST_TRANSFER_VSEQ", "Frame 1: Streaming 16 samples via INCR16 burst...", UVM_LOW)
        push_samples_burst(burst_16, HBURST_INCR16);

        `uvm_info("BURST_TRANSFER_VSEQ", "Frame 1: Streaming 8 samples via INCR8 burst...", UVM_LOW)
        push_samples_burst(burst_8, HBURST_INCR8);

        `uvm_info("BURST_TRANSFER_VSEQ", "Frame 1: Streaming 4 samples via INCR4 burst...", UVM_LOW)
        push_samples_burst(burst_4, HBURST_INCR4);

        `uvm_info("BURST_TRANSFER_VSEQ", "Frame 1: Streaming 4 samples via WRAP4 burst...", UVM_LOW)
        push_samples_burst(burst_4, HBURST_WRAP4);

        // Verify IN FIFO level prior to processing
        reg_model.reg_in_level.read(status, rdata);
        `uvm_info("BURST_TRANSFER_VSEQ", $sformatf("Frame 1 IN_LEVEL: %0d", rdata), UVM_LOW)

        // Enable FFT Core
        reg_model.reg_ctrl.write(status, 32'h01);

        // Await Frame 1 completion reactively
        wait_for_irq(1'b1);
        wait_for_out_level(32, 2000);
        wait_for_idle(2000);

        // Read 32 FFT Output Bins using WRAP4, INCR4, INCR8, INCR16
        `uvm_info("BURST_TRANSFER_VSEQ", "Frame 1: Popping bins via WRAP4, INCR4, INCR8, INCR16...", UVM_LOW)
        pop_samples_burst(read_chunk, 4, HBURST_WRAP4);
        pop_samples_burst(read_chunk, 4, HBURST_INCR4);
        pop_samples_burst(read_chunk, 8, HBURST_INCR8);
        pop_samples_burst(read_chunk, 16, HBURST_INCR16);

        // Clear FRAME_DONE interrupt via RAL (W1C) and verify deassertion
        reg_model.reg_int_status.write(status, 32'h01);
        reg_model.reg_int_status.read(status, rdata);
        if (rdata[0] !== 1'b0) `uvm_error("BURST_TRANSFER_VSEQ", "Frame 1 FRAME_DONE failed to clear!")

        // Frame 2: Stream using WRAP16, WRAP8, INCR, SINGLE
        `uvm_info("BURST_TRANSFER_VSEQ", "Frame 2: Streaming via WRAP16, WRAP8, INCR, SINGLE...", UVM_LOW)
        push_samples_burst(burst_16, HBURST_WRAP16);
        push_samples_burst(burst_8,  HBURST_WRAP8);
        push_samples_burst(burst_4,  HBURST_INCR);
        for (int i = 0; i < 4; i++) push_sample(burst_4[i]);

        // Await Frame 2 completion reactively
        wait_for_irq(1'b1);
        wait_for_out_level(32, 2000);
        wait_for_idle(2000);

        // Read 32 FFT Output Bins from Frame 2 using WRAP16, WRAP8, INCR, SINGLE
        `uvm_info("BURST_TRANSFER_VSEQ", "Frame 2: Popping bins via WRAP16, WRAP8, INCR, SINGLE...", UVM_LOW)
        pop_samples_burst(read_chunk, 16, HBURST_WRAP16);
        pop_samples_burst(read_chunk, 8,  HBURST_WRAP8);
        pop_samples_burst(read_chunk, 4,  HBURST_INCR);
        for (int i = 0; i < 4; i++) begin
            bit [31:0] s;
            pop_sample(s);
        end

        // Clear FRAME_DONE interrupt via RAL (W1C)
        reg_model.reg_int_status.write(status, 32'h01);
        reg_model.reg_int_status.read(status, rdata);
        if (rdata[0] !== 1'b0) `uvm_error("BURST_TRANSFER_VSEQ", "Frame 2 FRAME_DONE failed to clear!")

        // Disable FFT Core via RAL
        reg_model.reg_ctrl.write(status, 32'h00);

        `uvm_info("BURST_TRANSFER_VSEQ", "FFT Burst Transfer Verification Sequence completed successfully!", UVM_LOW)
    endtask

endclass : fft_burst_transfer_vseq

`endif // FFT_BURST_TRANSFER_VSEQ_SVH
