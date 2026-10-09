// =============================================================================
// File Name      : fft_sanity_seq.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 3.0 (Virtual Sequence with Reactive Interrupt Synchronization)
// Description    : End-to-end sanity sequence verifying peripheral identification,
//                  register configuration via RAL, 32-point DC frame transformation,
//                  reactive sideband interrupt waiting, and interrupt clearing.
// =============================================================================

`ifndef FFT_SANITY_SEQ_SVH
`define FFT_SANITY_SEQ_SVH

class fft_sanity_seq extends fft_base_vseq;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(fft_sanity_seq)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_sanity_seq");
        super.new(name);
    endfunction

    // ==================================================
    // Sequence Body Task
    // ==================================================
    virtual task body();
        uvm_status_e   status;
        uvm_reg_data_t rdata;
        bit [31:0]     sample_val;

        `uvm_info("SANITY_SEQ", "Starting FFT Sanity Sequence execution...", UVM_LOW)

        // ==================================================
        // Configurations
        // ==================================================
        // Peripheral Identification Check via RAL
        reg_model.reg_id.read(status, rdata);
        `uvm_info("SANITY_SEQ", $sformatf("Read IP ID: 0x%08h", rdata), UVM_LOW)

        reg_model.reg_version.read(status, rdata);
        `uvm_info("SANITY_SEQ", $sformatf("Read IP Version: 0x%08h", rdata), UVM_LOW)

        // Configure Frame Done Interrupt via RAL
        reg_model.reg_int_en.write(status, 32'h01);
        reg_model.reg_int_en.read(status, rdata);
        `uvm_info("SANITY_SEQ", $sformatf("Configured INT_EN: 0x%08h", rdata), UVM_LOW)

        // ==================================================
        // Test Scenario
        // ==================================================
        // Push 32 DC Complex Samples (Re = 0x6CCD, Im = 0x0000)
        `uvm_info("SANITY_SEQ", "Pushing 32 DC complex samples into IN FIFO...", UVM_LOW)
        for (int i = 0; i < 32; i++) begin
            push_sample(32'h6CCD_0000);
        end

        // Verify IN FIFO level via RAL
        reg_model.reg_in_level.read(status, rdata);
        `uvm_info("SANITY_SEQ", $sformatf("IN FIFO Level prior to processing: %0d", rdata), UVM_LOW)

        // Start Core Processing (CTRL[0] = 1) via RAL
        `uvm_info("SANITY_SEQ", "Enabling FFT Core (CTRL[0] = 1)...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h01);

        // Await frame completion reactively via sideband IRQ and FIFO levels
        `uvm_info("SANITY_SEQ", "Waiting on sideband agent for IRQ assertion (frame done)...", UVM_MEDIUM)
        wait_for_irq(1'b1);
        wait_for_out_level(32, 2000);
        wait_for_idle(2000);

        // Check Interrupt Status via RAL
        reg_model.reg_int_status.read(status, rdata);
        `uvm_info("SANITY_SEQ", $sformatf("INT_STATUS after processing: 0x%08h", rdata), UVM_LOW)

        // Read 32 FFT Output Bins from OUT FIFO
        `uvm_info("SANITY_SEQ", "Popping 32 output bins from OUT FIFO...", UVM_LOW)
        for (int i = 0; i < 32; i++) begin
            pop_sample(sample_val);
            `uvm_info("SANITY_SEQ", $sformatf("Bin [%0d] = 0x%08h (Re=%0d, Im=%0d)",
                i, sample_val, signed'(sample_val[31:16]), signed'(sample_val[15:0])), UVM_HIGH)
        end

        // Clear FRAME_DONE interrupt via RAL (W1C)
        reg_model.reg_int_status.write(status, 32'h01);
        reg_model.reg_int_status.read(status, rdata);
        `uvm_info("SANITY_SEQ", $sformatf("INT_STATUS after W1C clear: 0x%08h", rdata), UVM_LOW)

        // Verify physical interrupt line deassertion via sideband agent
        wait_for_irq(1'b0);
        `uvm_info("SANITY_SEQ", "PASS: Physical IRQ deasserted after W1C clear", UVM_MEDIUM)

        // Disable FFT Core via RAL
        reg_model.reg_ctrl.write(status, 32'h00);

        `uvm_info("SANITY_SEQ", "FFT Sanity Sequence execution completed successfully!", UVM_LOW)
    endtask

endclass : fft_sanity_seq

`endif // FFT_SANITY_SEQ_SVH
