// =============================================================================
// File Name      : fft_reset_flush_seq.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-07
// Version        : 3.0 (Virtual Sequence with Reactive Interrupt Synchronization)
// Description    : Reset and FIFO flushing command verification sequence.
//                  Validates independent flush_in, flush_out strobes and
//                  synchronous soft_reset command via RAL and reactive IRQ tracking.
// =============================================================================

`ifndef FFT_RESET_FLUSH_SEQ_SVH
`define FFT_RESET_FLUSH_SEQ_SVH

class fft_reset_flush_seq extends fft_base_vseq;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(fft_reset_flush_seq)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_reset_flush_seq");
        super.new(name);
    endfunction

    // ==================================================
    // Sequence Body Task
    // ==================================================
    virtual task body();
        uvm_status_e   status;
        uvm_reg_data_t rdata;
        bit [31:0]     sample_val;

        `uvm_info("RST_FLUSH_SEQ", "Starting Reset & FIFO Flush Strobe Verification Sequence...", UVM_LOW)

        // ==================================================
        // Configurations
        // ==================================================
        // Peripheral Identification Check via RAL
        reg_model.reg_id.read(status, rdata);
        reg_model.reg_version.read(status, rdata);

        // ==================================================
        // Test Scenario
        // ==================================================
        // FLUSH_IN Strobe Verification (CTRL[30] = 1) via RAL
        `uvm_info("RST_FLUSH_SEQ", "Testing FLUSH_IN strobe: Loading 20 words into IN FIFO...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h00);

        for (int i = 0; i < 20; i++) begin
            push_sample(32'hA000_B000 + i);
        end

        reg_model.reg_in_level.read(status, rdata);
        if (rdata != 32'd20) `uvm_error("RST_FLUSH_SEQ", $sformatf("Expected IN_LEVEL == 20, got %0d", rdata))

        // Issue FLUSH_IN command via RAL
        `uvm_info("RST_FLUSH_SEQ", "Issuing FLUSH_IN strobe (CTRL = 0x4000_0000, bit 30)...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h4000_0000);

        // Read CTRL: verify bit 30 self-clears via RAL
        reg_model.reg_ctrl.read(status, rdata);
        if ((rdata & 32'h4000_0000) != 32'h0) `uvm_error("RST_FLUSH_SEQ", "Expected CTRL[30] (flush_in) to self-clear!")

        // Wait for reset hold sequencer (16 cycles) via RAL
        repeat (20) reg_model.reg_status.read(status, rdata);

        // Verify IN FIFO is completely empty via RAL
        reg_model.reg_in_level.read(status, rdata);
        if (rdata != 32'h0) `uvm_error("RST_FLUSH_SEQ", $sformatf("Expected IN_LEVEL == 0 after flush_in, got %0d", rdata))

        reg_model.reg_status.read(status, rdata);
        if ((rdata & 32'h02) == 32'h0) `uvm_error("RST_FLUSH_SEQ", "Expected STATUS[1] (in_empty) to be asserted!")
        `uvm_info("RST_FLUSH_SEQ", "PASS: FLUSH_IN strobe flushed IN FIFO and self-cleared successfully!", UVM_MEDIUM)

        // FLUSH_OUT Strobe Verification (CTRL[31] = 1) via RAL
        `uvm_info("RST_FLUSH_SEQ", "Testing FLUSH_OUT strobe: Processing 32 samples into OUT FIFO...", UVM_LOW)
        reg_model.reg_int_en.write(status, 32'h01);
        reg_model.reg_ctrl.write(status, 32'h01); // Enable core

        for (int i = 0; i < 32; i++) begin
            push_sample(32'h3000_1000);
        end

        wait_for_irq(1'b1);
        wait_for_out_level(32, 2000);
        wait_for_idle(2000);

        reg_model.reg_out_level.read(status, rdata);
        if (rdata != 32'd32) `uvm_error("RST_FLUSH_SEQ", $sformatf("Expected OUT_LEVEL == 32, got %0d", rdata))

        // Issue FLUSH_OUT command via RAL
        `uvm_info("RST_FLUSH_SEQ", "Issuing FLUSH_OUT strobe (CTRL = 0x8000_0000, bit 31)...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h8000_0000);

        // Read CTRL: verify bit 31 self-clears via RAL
        reg_model.reg_ctrl.read(status, rdata);
        if ((rdata & 32'h8000_0000) != 32'h0) `uvm_error("RST_FLUSH_SEQ", "Expected CTRL[31] (flush_out) to self-clear!")

        // Wait for reset hold sequencer (16 cycles) via RAL
        repeat (20) reg_model.reg_status.read(status, rdata);

        // Verify OUT FIFO is completely empty via RAL
        reg_model.reg_out_level.read(status, rdata);
        if (rdata != 32'h0) `uvm_error("RST_FLUSH_SEQ", $sformatf("Expected OUT_LEVEL == 0 after flush_out, got %0d", rdata))

        reg_model.reg_status.read(status, rdata);
        if ((rdata & 32'h08) == 32'h0) `uvm_error("RST_FLUSH_SEQ", "Expected STATUS[3] (out_empty) to be asserted!")
        `uvm_info("RST_FLUSH_SEQ", "PASS: FLUSH_OUT strobe flushed OUT FIFO and self-cleared successfully!", UVM_MEDIUM)

        // Clear FRAME_DONE interrupt from earlier processing via RAL
        reg_model.reg_int_status.write(status, 32'h01);
        wait_for_irq(1'b0);

        // SOFT_RESET Strobe Verification (CTRL[29] = 1) via RAL
        `uvm_info("RST_FLUSH_SEQ", "Testing SOFT_RESET strobe: Populating state prior to full reset...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h00);

        // Put 15 samples in IN FIFO
        for (int i = 0; i < 15; i++) begin
            push_sample(32'h5555_AAAA);
        end

        reg_model.reg_in_level.read(status, rdata);
        if (rdata != 32'd15) `uvm_error("RST_FLUSH_SEQ", $sformatf("Expected IN_LEVEL == 15, got %0d", rdata))

        // Issue SOFT_RESET command via RAL
        `uvm_info("RST_FLUSH_SEQ", "Issuing SOFT_RESET strobe (CTRL = 0x2000_0000, bit 29)...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h2000_0000);

        // Read CTRL: verify bit 29 self-clears via RAL
        reg_model.reg_ctrl.read(status, rdata);
        if ((rdata & 32'h2000_0000) != 32'h0) `uvm_error("RST_FLUSH_SEQ", "Expected CTRL[29] (soft_reset) to self-clear!")

        // Drain reset hold duration (16 cycles) via RAL
        repeat (25) reg_model.reg_status.read(status, rdata);

        // Verify subsystem state is completely clean: IN_LEVEL=0, OUT_LEVEL=0, STATUS=0x2A via RAL
        reg_model.reg_in_level.read(status, rdata);
        if (rdata != 32'h0) `uvm_error("RST_FLUSH_SEQ", $sformatf("IN_LEVEL non-zero after soft_reset: %0d", rdata))

        reg_model.reg_out_level.read(status, rdata);
        if (rdata != 32'h0) `uvm_error("RST_FLUSH_SEQ", $sformatf("OUT_LEVEL non-zero after soft_reset: %0d", rdata))

        reg_model.reg_status.read(status, rdata);
        if (rdata != 32'h2A) `uvm_error("RST_FLUSH_SEQ", $sformatf("STATUS mismatch after soft_reset: got 0x%08h, exp 0x2A", rdata))
        `uvm_info("RST_FLUSH_SEQ", "PASS: SOFT_RESET returned core and FIFOs to default reset baseline!", UVM_MEDIUM)

        // Post-Reset End-to-End Functional Frame Execution
        `uvm_info("RST_FLUSH_SEQ", "Running end-to-end 32-point frame post-reset to verify recovery...", UVM_LOW)
        reg_model.reg_int_en.write(status, 32'h01);
        reg_model.reg_ctrl.write(status, 32'h01); // Enable core

        for (int i = 0; i < 32; i++) begin
            push_sample(32'h6CCD_0000); // 32 DC samples
        end

        wait_for_irq(1'b1);
        wait_for_out_level(32, 2000);
        wait_for_idle(2000);

        for (int i = 0; i < 32; i++) begin
            pop_sample(sample_val);
        end

        // Clear FRAME_DONE interrupt via RAL (W1C)
        reg_model.reg_int_status.write(status, 32'h01);
        wait_for_irq(1'b0);
        reg_model.reg_ctrl.write(status, 32'h00);

        `uvm_info("RST_FLUSH_SEQ", "Reset & FIFO Flush Strobe Verification Sequence completed successfully!", UVM_LOW)
    endtask

endclass : fft_reset_flush_seq

`endif // FFT_RESET_FLUSH_SEQ_SVH
