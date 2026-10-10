// =============================================================================
// File Name      : fft_fifo_boundary_overflow_vseq.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-07
// Version        : 4.0
// Description    : FIFO boundary, overflow, and underflow virtual sequence.
//                  Validates empty OUT FIFO pop underflow, full IN FIFO push
//                  overflow (64-word capacity limit), sticky interrupt flags,
//                  soft reset recovery, and post-recovery functional streaming.
// =============================================================================

`ifndef FFT_FIFO_BOUNDARY_OVERFLOW_VSEQ_SVH
`define FFT_FIFO_BOUNDARY_OVERFLOW_VSEQ_SVH

class fft_fifo_boundary_overflow_vseq extends fft_base_vseq;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(fft_fifo_boundary_overflow_vseq)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_fifo_boundary_overflow_vseq");
        super.new(name);
    endfunction

    // ==================================================
    // Sequence Body Task
    // ==================================================
    virtual task body();
        uvm_status_e   status;
        uvm_reg_data_t rdata;
        bit [31:0]     sample_val;
        bit [31:0]     fill_samples[64];
        bit [31:0]     recov_samples[32];

        `uvm_info("FIFO_BND_VSEQ", "Starting FIFO Boundary & Overflow/Underflow Sequence...", UVM_LOW)

        // ==================================================
        // Configurations
        // ==================================================
        // Identification Check via RAL
        reg_model.reg_id.read(status, rdata);
        reg_model.reg_version.read(status, rdata);

        // Enable All Interrupt Sources (Frame Done [0], In Overflow [1], Out Underflow [2]) via RAL
        reg_model.reg_int_en.write(status, 32'h07);
        reg_model.reg_int_en.read(status, rdata);
        if (rdata != 32'h07) begin
            `uvm_error("FIFO_BND_VSEQ", $sformatf("INT_EN configuration mismatch: got 0x%08h, exp 0x07", rdata))
        end

        // ==================================================
        // Test Scenario
        // ==================================================
        // OUT FIFO Underflow Verification
        `uvm_info("FIFO_BND_VSEQ", "Verifying OUT FIFO Underflow Detection...", UVM_LOW)

        // Verify OUT FIFO is initially empty
        reg_model.reg_out_level.read(status, rdata);
        if (rdata != 32'h0) `uvm_error("FIFO_BND_VSEQ", $sformatf("Expected OUT_LEVEL == 0, got %0d", rdata))

        reg_model.reg_status.read(status, rdata);
        if ((rdata & 32'h08) == 32'h0) `uvm_error("FIFO_BND_VSEQ", "Expected STATUS[3] (out_empty) to be asserted!")

        // Pop from empty OUT FIFO
        pop_sample(sample_val);
        if (sample_val != 32'h0) begin
            `uvm_error("FIFO_BND_VSEQ", $sformatf("Underflow pop returned non-zero value: 0x%08h", sample_val))
        end

        // Await reactive sideband IRQ assertion
        wait_for_irq(1'b1);

        // Check sticky OUT_UNDERFLOW flag in INT_STATUS (bit 2)
        reg_model.reg_int_status.read(status, rdata);
        if ((rdata & 32'h04) == 32'h0) begin
            `uvm_error("FIFO_BND_VSEQ", "Expected INT_STATUS[2] (out_underflow) to be asserted!")
        end else begin
            `uvm_info("FIFO_BND_VSEQ", "PASS: OUT FIFO Underflow flag asserted correctly!", UVM_LOW)
        end

        // Clear OUT_UNDERFLOW interrupt flag via RAL (W1C bit 2)
        reg_model.reg_int_status.write(status, 32'h04);
        reg_model.reg_int_status.read(status, rdata);
        if ((rdata & 32'h04) != 32'h0) `uvm_error("FIFO_BND_VSEQ", "Expected INT_STATUS[2] to clear after W1C write!")

        // IN FIFO Overflow Verification
        `uvm_info("FIFO_BND_VSEQ", "Verifying IN FIFO Overflow Detection...", UVM_LOW)

        // Ensure core is disabled to hold samples in IN FIFO
        reg_model.reg_ctrl.write(status, 32'h00);

        // Fill IN FIFO to maximum capacity (64 words) using INCR burst
        for (int i = 0; i < 64; i++) fill_samples[i] = 32'h1000_2000 + i;
        `uvm_info("FIFO_BND_VSEQ", "Streaming 64 words via INCR burst to reach full capacity...", UVM_LOW)
        push_samples_burst(fill_samples, HBURST_INCR);

        // Check IN_LEVEL reaches 64 and in_full (STATUS[2]) is asserted
        reg_model.reg_in_level.read(status, rdata);
        if (rdata != 32'd64) `uvm_error("FIFO_BND_VSEQ", $sformatf("Expected IN_LEVEL == 64, got %0d", rdata))

        reg_model.reg_status.read(status, rdata);
        if ((rdata & 32'h04) == 32'h0) `uvm_error("FIFO_BND_VSEQ", "Expected STATUS[2] (in_full) to be asserted!")

        // Push 65th word into full IN FIFO to trigger overflow
        `uvm_info("FIFO_BND_VSEQ", "Pushing 65th word into full IN FIFO to trigger overflow...", UVM_LOW)
        push_sample(32'hDEAD_BEEF);

        // Await reactive sideband IRQ assertion
        wait_for_irq(1'b1);

        // Verify IN_LEVEL remains 64 (unmodified)
        reg_model.reg_in_level.read(status, rdata);
        if (rdata != 32'd64) `uvm_error("FIFO_BND_VSEQ", $sformatf("IN_LEVEL corrupted: got %0d, exp 64", rdata))

        // Check sticky IN_OVERFLOW flag in INT_STATUS (bit 1)
        reg_model.reg_int_status.read(status, rdata);
        if ((rdata & 32'h02) == 32'h0) begin
            `uvm_error("FIFO_BND_VSEQ", "Expected INT_STATUS[1] (in_overflow) to be asserted!")
        end else begin
            `uvm_info("FIFO_BND_VSEQ", "PASS: IN FIFO Overflow flag asserted correctly!", UVM_LOW)
        end

        // Clear IN_OVERFLOW interrupt flag via RAL (W1C bit 1)
        reg_model.reg_int_status.write(status, 32'h02);
        reg_model.reg_int_status.read(status, rdata);
        if ((rdata & 32'h02) != 32'h0) `uvm_error("FIFO_BND_VSEQ", "Expected INT_STATUS[1] to clear after W1C write!")

        // System Recovery via Soft Reset (CTRL[29] = 1)
        `uvm_info("FIFO_BND_VSEQ", "Executing soft reset (CTRL = 0x2000_0000, bit 29)...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h2000_0000);
        repeat (25) reg_model.reg_status.read(status, rdata); // Drain reset hold (16 cycles)

        // Verify reset state: IN_LEVEL == 0, OUT_LEVEL == 0, STATUS == 0x2A
        reg_model.reg_in_level.read(status, rdata);
        if (rdata != 32'h0) `uvm_error("FIFO_BND_VSEQ", "IN_LEVEL non-zero after soft reset!")

        reg_model.reg_out_level.read(status, rdata);
        if (rdata != 32'h0) `uvm_error("FIFO_BND_VSEQ", "OUT_LEVEL non-zero after soft reset!")

        reg_model.reg_status.read(status, rdata);
        if (rdata != 32'h2A) `uvm_error("FIFO_BND_VSEQ", $sformatf("STATUS mismatch after reset: got 0x%08h, exp 0x2A", rdata))

        // Normal Functional Frame Execution Post-Recovery
        `uvm_info("FIFO_BND_VSEQ", "Running normal functional frame post-recovery...", UVM_LOW)
        reg_model.reg_int_en.write(status, 32'h01);
        reg_model.reg_ctrl.write(status, 32'h01);

        for (int i = 0; i < 32; i++) recov_samples[i] = 32'h4000_0000;
        push_samples_burst(recov_samples, HBURST_INCR);

        wait_for_irq(1'b1);
        handle_frame_done();

        reg_model.reg_ctrl.write(status, 32'h00);

        `uvm_info("FIFO_BND_VSEQ", "FIFO Boundary & Overflow/Underflow Sequence completed successfully!", UVM_LOW)
    endtask

endclass : fft_fifo_boundary_overflow_vseq

`endif // FFT_FIFO_BOUNDARY_OVERFLOW_VSEQ_SVH
