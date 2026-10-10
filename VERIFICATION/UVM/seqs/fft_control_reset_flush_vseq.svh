// =============================================================================
// File Name      : fft_control_reset_flush_vseq.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-07
// Version        : 4.0
// Description    : Control reset and FIFO flushing command virtual sequence.
//                  Validates independent flush_in (CTRL[30]), flush_out (CTRL[31])
//                  strobes, synchronous soft_reset (CTRL[29]) command, self-clearing
//                  behavior, and post-reset clean pipeline execution.
// =============================================================================

`ifndef FFT_CONTROL_RESET_FLUSH_VSEQ_SVH
`define FFT_CONTROL_RESET_FLUSH_VSEQ_SVH

class fft_control_reset_flush_vseq extends fft_base_vseq;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(fft_control_reset_flush_vseq)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_control_reset_flush_vseq");
        super.new(name);
    endfunction

    // ==================================================
    // Sequence Body Task
    // ==================================================
    virtual task body();
        uvm_status_e   status;
        uvm_reg_data_t rdata;
        bit [31:0]     samples_20[20];
        bit [31:0]     samples_32[32];
        bit [31:0]     samples_15[15];

        `uvm_info("CTRL_RST_VSEQ", "Starting Control Reset & FIFO Flush Strobe Verification Sequence...", UVM_LOW)

        // ==================================================
        // Configurations
        // ==================================================
        // Identification Check via RAL
        reg_model.reg_id.read(status, rdata);
        reg_model.reg_version.read(status, rdata);

        // ==================================================
        // Test Scenario
        // ==================================================
        // FLUSH_IN Strobe Verification (CTRL[30] = 1)
        `uvm_info("CTRL_RST_VSEQ", "Testing FLUSH_IN strobe: Loading 20 words into IN FIFO...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h00);

        for (int i = 0; i < 20; i++) samples_20[i] = 32'hA000_B000 + i;
        push_samples_burst(samples_20, HBURST_INCR);

        reg_model.reg_in_level.read(status, rdata);
        if (rdata != 32'd20) `uvm_error("CTRL_RST_VSEQ", $sformatf("Expected IN_LEVEL == 20, got %0d", rdata))

        // Issue FLUSH_IN command via RAL
        `uvm_info("CTRL_RST_VSEQ", "Issuing FLUSH_IN strobe (CTRL = 0x4000_0000, bit 30)...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h4000_0000);

        // Verify bit 30 self-clears
        reg_model.reg_ctrl.read(status, rdata);
        if ((rdata & 32'h4000_0000) != 32'h0) `uvm_error("CTRL_RST_VSEQ", "Expected CTRL[30] (flush_in) to self-clear!")

        // Wait for reset hold sequencer (16 cycles) via RAL polling
        repeat (20) reg_model.reg_status.read(status, rdata);

        // Verify IN FIFO is completely empty
        reg_model.reg_in_level.read(status, rdata);
        if (rdata != 32'h0) `uvm_error("CTRL_RST_VSEQ", $sformatf("Expected IN_LEVEL == 0 after flush_in, got %0d", rdata))

        reg_model.reg_status.read(status, rdata);
        if ((rdata & 32'h02) == 32'h0) `uvm_error("CTRL_RST_VSEQ", "Expected STATUS[1] (in_empty) to be asserted!")
        `uvm_info("CTRL_RST_VSEQ", "PASS: FLUSH_IN strobe flushed IN FIFO and self-cleared successfully!", UVM_MEDIUM)

        // FLUSH_OUT Strobe Verification (CTRL[31] = 1)
        `uvm_info("CTRL_RST_VSEQ", "Testing FLUSH_OUT strobe: Processing 32 samples into OUT FIFO...", UVM_LOW)
        reg_model.reg_int_en.write(status, 32'h01);
        reg_model.reg_ctrl.write(status, 32'h01);

        for (int i = 0; i < 32; i++) samples_32[i] = 32'h3000_1000;
        push_samples_burst(samples_32, HBURST_INCR);

        wait_for_irq(1'b1);
        wait_for_out_level(32, 2000);
        wait_for_idle(2000);

        reg_model.reg_out_level.read(status, rdata);
        if (rdata != 32'd32) `uvm_error("CTRL_RST_VSEQ", $sformatf("Expected OUT_LEVEL == 32, got %0d", rdata))

        // Issue FLUSH_OUT command via RAL
        `uvm_info("CTRL_RST_VSEQ", "Issuing FLUSH_OUT strobe (CTRL = 0x8000_0000, bit 31)...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h8000_0000);

        // Verify bit 31 self-clears
        reg_model.reg_ctrl.read(status, rdata);
        if ((rdata & 32'h8000_0000) != 32'h0) `uvm_error("CTRL_RST_VSEQ", "Expected CTRL[31] (flush_out) to self-clear!")

        // Wait for reset hold sequencer (16 cycles) via RAL polling
        repeat (20) reg_model.reg_status.read(status, rdata);

        // Verify OUT FIFO is completely empty
        reg_model.reg_out_level.read(status, rdata);
        if (rdata != 32'h0) `uvm_error("CTRL_RST_VSEQ", $sformatf("Expected OUT_LEVEL == 0 after flush_out, got %0d", rdata))

        reg_model.reg_status.read(status, rdata);
        if ((rdata & 32'h08) == 32'h0) `uvm_error("CTRL_RST_VSEQ", "Expected STATUS[3] (out_empty) to be asserted!")
        `uvm_info("CTRL_RST_VSEQ", "PASS: FLUSH_OUT strobe flushed OUT FIFO and self-cleared successfully!", UVM_MEDIUM)

        // Clear FRAME_DONE interrupt from earlier processing
        reg_model.reg_int_status.write(status, 32'h01);
        wait_for_irq(1'b0);

        // SOFT_RESET Strobe Verification (CTRL[29] = 1)
        `uvm_info("CTRL_RST_VSEQ", "Testing SOFT_RESET strobe: Populating state prior to reset...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h00);

        // Populate IN FIFO with 15 samples
        for (int i = 0; i < 15; i++) samples_15[i] = 32'h5555_AAAA;
        push_samples_burst(samples_15, HBURST_INCR);

        reg_model.reg_in_level.read(status, rdata);
        if (rdata != 32'd15) `uvm_error("CTRL_RST_VSEQ", $sformatf("Expected IN_LEVEL == 15, got %0d", rdata))

        // Issue SOFT_RESET command via RAL
        `uvm_info("CTRL_RST_VSEQ", "Issuing SOFT_RESET strobe (CTRL = 0x2000_0000, bit 29)...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h2000_0000);

        // Verify bit 29 self-clears
        reg_model.reg_ctrl.read(status, rdata);
        if ((rdata & 32'h2000_0000) != 32'h0) `uvm_error("CTRL_RST_VSEQ", "Expected CTRL[29] (soft_reset) to self-clear!")

        // Drain reset hold duration (16 cycles) via RAL polling
        repeat (25) reg_model.reg_status.read(status, rdata);

        // Verify subsystem state returned to default reset baseline
        reg_model.reg_in_level.read(status, rdata);
        if (rdata != 32'h0) `uvm_error("CTRL_RST_VSEQ", $sformatf("IN_LEVEL non-zero after soft_reset: %0d", rdata))

        reg_model.reg_out_level.read(status, rdata);
        if (rdata != 32'h0) `uvm_error("CTRL_RST_VSEQ", $sformatf("OUT_LEVEL non-zero after soft_reset: %0d", rdata))

        reg_model.reg_status.read(status, rdata);
        if (rdata != 32'h2A) `uvm_error("CTRL_RST_VSEQ", $sformatf("STATUS mismatch: got 0x%08h, exp 0x2A", rdata))
        `uvm_info("CTRL_RST_VSEQ", "PASS: SOFT_RESET returned core and FIFOs to default reset baseline!", UVM_MEDIUM)

        // Post-Reset End-to-End Functional Frame Execution
        `uvm_info("CTRL_RST_VSEQ", "Running end-to-end 32-point frame post-reset...", UVM_LOW)
        reg_model.reg_int_en.write(status, 32'h01);
        reg_model.reg_ctrl.write(status, 32'h01);

        for (int i = 0; i < 32; i++) samples_32[i] = 32'h6CCD_0000;
        push_samples_burst(samples_32, HBURST_INCR);

        wait_for_irq(1'b1);
        handle_frame_done();

        reg_model.reg_ctrl.write(status, 32'h00);

        `uvm_info("CTRL_RST_VSEQ", "Control Reset & FIFO Flush Strobe Verification Sequence completed successfully!", UVM_LOW)
    endtask

endclass : fft_control_reset_flush_vseq

`endif // FFT_CONTROL_RESET_FLUSH_VSEQ_SVH
