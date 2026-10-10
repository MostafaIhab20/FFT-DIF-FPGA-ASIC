// =============================================================================
// File Name      : fft_single_frame_vseq.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 4.0
// Description    : Single-frame sanity virtual sequence verifying peripheral
//                  discovery (ID & VERSION), interrupt configuration via RAL,
//                  deterministic 32-point DC frame streaming via INCR burst,
//                  reactive sideband interrupt waiting, and frame completion handling.
// =============================================================================

`ifndef FFT_SINGLE_FRAME_VSEQ_SVH
`define FFT_SINGLE_FRAME_VSEQ_SVH

class fft_single_frame_vseq extends fft_base_vseq;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(fft_single_frame_vseq)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_single_frame_vseq");
        super.new(name);
    endfunction

    // ==================================================
    // Sequence Body Task
    // ==================================================
    virtual task body();
        uvm_status_e   status;
        uvm_reg_data_t rdata;
        bit [31:0]     dc_frame[32];

        `uvm_info("SINGLE_FRAME_VSEQ", "Starting Single-Frame Sanity Sequence execution...", UVM_LOW)

        // ==================================================
        // Configurations
        // ==================================================
        // Peripheral Identification Check via RAL
        reg_model.reg_id.read(status, rdata);
        `uvm_info("SINGLE_FRAME_VSEQ", $sformatf("Read IP ID: 0x%08h", rdata), UVM_LOW)

        reg_model.reg_version.read(status, rdata);
        `uvm_info("SINGLE_FRAME_VSEQ", $sformatf("Read IP Version: 0x%08h", rdata), UVM_LOW)

        // Enable Frame Done Interrupt (INT_EN[0] = 1) via RAL
        reg_model.reg_int_en.write(status, 32'h01);
        reg_model.reg_int_en.read(status, rdata);
        `uvm_info("SINGLE_FRAME_VSEQ", $sformatf("Configured INT_EN: 0x%08h", rdata), UVM_LOW)

        // ==================================================
        // Test Scenario
        // ==================================================
        // Prepare 32 DC Complex Samples (Re = 0x6CCD, Im = 0x0000)
        for (int i = 0; i < 32; i++) begin
            dc_frame[i] = 32'h6CCD_0000;
        end

        // Stream 32 DC samples into IN FIFO via INCR burst
        `uvm_info("SINGLE_FRAME_VSEQ", "Pushing 32 DC complex samples into IN FIFO via INCR burst...", UVM_LOW)
        push_samples_burst(dc_frame, HBURST_INCR);

        // Verify IN FIFO level via RAL prior to processing
        reg_model.reg_in_level.read(status, rdata);
        `uvm_info("SINGLE_FRAME_VSEQ", $sformatf("IN FIFO Level prior to processing: %0d", rdata), UVM_LOW)

        // Enable FFT Core (CTRL[0] = 1) via RAL
        `uvm_info("SINGLE_FRAME_VSEQ", "Enabling FFT Core (CTRL[0] = 1)...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h01);

        // Await reactive sideband IRQ assertion
        `uvm_info("SINGLE_FRAME_VSEQ", "Waiting on sideband agent for IRQ assertion (frame done)...", UVM_MEDIUM)
        wait_for_irq(1'b1);

        // Drain output frame and clear FRAME_DONE interrupt via handle_frame_done()
        `uvm_info("SINGLE_FRAME_VSEQ", "Draining 32 output bins and clearing IRQ via handle_frame_done()...", UVM_LOW)
        handle_frame_done();

        // Disable FFT Core via RAL
        reg_model.reg_ctrl.write(status, 32'h00);

        `uvm_info("SINGLE_FRAME_VSEQ", "Single-Frame Sanity Sequence completed successfully!", UVM_LOW)
    endtask

endclass : fft_single_frame_vseq

`endif // FFT_SINGLE_FRAME_VSEQ_SVH
