// =============================================================================
// File Name      : fft_fifo_boundary_seq.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-07
// Version        : 3.0 (Virtual Sequence with Reactive Error Interrupt Synchronization)
// Description    : FIFO boundary, overflow, and underflow stimulus sequence.
//                  Validates empty OUT FIFO pop underflow, full IN FIFO push
//                  overflow, sticky interrupt flags, and reactive IRQ assertion.
// =============================================================================

`ifndef FFT_FIFO_BOUNDARY_SEQ_SVH
`define FFT_FIFO_BOUNDARY_SEQ_SVH

class fft_fifo_boundary_seq extends fft_base_vseq;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(fft_fifo_boundary_seq)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_fifo_boundary_seq");
        super.new(name);
    endfunction

    // ==================================================
    // Sequence Body Task
    // ==================================================
    virtual task body();
        uvm_status_e   status;
        uvm_reg_data_t rdata;
        bit [31:0]     sample_val;

        `uvm_info("FIFO_BND_SEQ", "Starting FIFO Boundary & Overflow/Underflow Sequence...", UVM_LOW)

        // ==================================================
        // Configurations
        // ==================================================
        // Peripheral Identification Check via RAL
        reg_model.reg_id.read(status, rdata);
        reg_model.reg_version.read(status, rdata);

        // Enable All Interrupt Sources (Frame Done [0], In Overflow [1], Out Underflow [2]) via RAL
        reg_model.reg_int_en.write(status, 32'h07);
        reg_model.reg_int_en.read(status, rdata);
        if (rdata != 32'h07) begin
            `uvm_error("FIFO_BND_SEQ", $sformatf("INT_EN configuration mismatch: got 0x%08h, exp 0x07", rdata))
        end

        // ==================================================
        // Test Scenario
        // ==================================================
        // OUT FIFO Underflow Verification
        `uvm_info("FIFO_BND_SEQ", "Verifying OUT FIFO Underflow Detection...", UVM_LOW)

        // Verify OUT FIFO is initially empty via RAL
        reg_model.reg_out_level.read(status, rdata);
        if (rdata != 32'h0) begin
            `uvm_error("FIFO_BND_SEQ", $sformatf("Expected OUT_LEVEL == 0 prior to underflow test, got %0d", rdata))
        end

        reg_model.reg_status.read(status, rdata);
        if ((rdata & 32'h08) == 32'h0) begin // STATUS[3] = out_empty
            `uvm_error("FIFO_BND_SEQ", "Expected STATUS[3] (out_empty) to be asserted!")
        end

        // Attempt popping from empty OUT FIFO
        pop_sample(sample_val);
        if (sample_val != 32'h0) begin
            `uvm_error("FIFO_BND_SEQ", $sformatf("Underflow pop returned non-zero value: 0x%08h (exp 0x0)", sample_val))
        end

        // Wait for reactive sideband IRQ assertion due to underflow
        wait_for_irq(1'b1);

        // Check sticky OUT_UNDERFLOW flag in INT_STATUS (bit 2) via RAL
        reg_model.reg_int_status.read(status, rdata);
        if ((rdata & 32'h04) == 32'h0) begin
            `uvm_error("FIFO_BND_SEQ", "Expected INT_STATUS[2] (out_underflow) to be asserted!")
        end else begin
            `uvm_info("FIFO_BND_SEQ", "PASS: OUT FIFO Underflow flag asserted correctly!", UVM_LOW)
        end

        // Clear OUT_UNDERFLOW interrupt flag via RAL (W1C)
        reg_model.reg_int_status.write(status, 32'h04);
        wait_for_irq(1'b0);
        reg_model.reg_int_status.read(status, rdata);
        if ((rdata & 32'h04) != 32'h0) begin
            `uvm_error("FIFO_BND_SEQ", "Expected INT_STATUS[2] to be cleared after W1C write!")
        end

        // IN FIFO Overflow Verification
        `uvm_info("FIFO_BND_SEQ", "Verifying IN FIFO Overflow Detection...", UVM_LOW)

        // Ensure core is disabled to hold samples in IN FIFO
        reg_model.reg_ctrl.write(status, 32'h00);

        // Fill IN FIFO to maximum capacity (64 words)
        `uvm_info("FIFO_BND_SEQ", "Filling IN FIFO with 64 words to reach full capacity...", UVM_LOW)
        for (int i = 0; i < 64; i++) begin
            push_sample(32'h1000_2000 + i);
        end

        // Check IN_LEVEL reaches 64 via RAL
        reg_model.reg_in_level.read(status, rdata);
        if (rdata != 32'd64) begin
            `uvm_error("FIFO_BND_SEQ", $sformatf("Expected IN_LEVEL == 64, got %0d", rdata))
        end

        // Check STATUS[2] (in_full) via RAL
        reg_model.reg_status.read(status, rdata);
        if ((rdata & 32'h04) == 32'h0) begin
            `uvm_error("FIFO_BND_SEQ", "Expected STATUS[2] (in_full) to be asserted!")
        end

        // Attempt 65th write into full IN FIFO
        `uvm_info("FIFO_BND_SEQ", "Pushing 65th word into full IN FIFO to trigger overflow...", UVM_LOW)
        push_sample(32'hDEAD_BEEF);

        // Wait for reactive sideband IRQ assertion due to overflow
        wait_for_irq(1'b1);

        // Verify IN_LEVEL remains 64 (dropped sample) via RAL
        reg_model.reg_in_level.read(status, rdata);
        if (rdata != 32'd64) begin
            `uvm_error("FIFO_BND_SEQ", $sformatf("IN_LEVEL corrupted after overflow write: got %0d (exp 64)", rdata))
        end

        // Check sticky IN_OVERFLOW flag in INT_STATUS (bit 1) via RAL
        reg_model.reg_int_status.read(status, rdata);
        if ((rdata & 32'h02) == 32'h0) begin
            `uvm_error("FIFO_BND_SEQ", "Expected INT_STATUS[1] (in_overflow) to be asserted!")
        end else begin
            `uvm_info("FIFO_BND_SEQ", "PASS: IN FIFO Overflow flag asserted correctly!", UVM_LOW)
        end

        // Clear IN_OVERFLOW interrupt flag via RAL (W1C)
        reg_model.reg_int_status.write(status, 32'h02);
        wait_for_irq(1'b0);
        reg_model.reg_int_status.read(status, rdata);
        if ((rdata & 32'h02) != 32'h0) begin
            `uvm_error("FIFO_BND_SEQ", "Expected INT_STATUS[1] to be cleared after W1C write!")
        end

        // System Recovery via Soft Reset via RAL (CTRL[29] = 1)
        `uvm_info("FIFO_BND_SEQ", "Executing soft reset (CTRL = 0x2000_0000, bit 29) to recover FIFOs...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h2000_0000); // soft_reset = bit 29
        repeat (25) reg_model.reg_status.read(status, rdata); // Drain reset hold (16 cycles)

        // Verify reset state: IN_LEVEL == 0, OUT_LEVEL == 0, STATUS == 0x2A via RAL
        reg_model.reg_in_level.read(status, rdata);
        if (rdata != 32'h0) `uvm_error("FIFO_BND_SEQ", "IN_LEVEL non-zero after soft reset!")

        reg_model.reg_out_level.read(status, rdata);
        if (rdata != 32'h0) `uvm_error("FIFO_BND_SEQ", "OUT_LEVEL non-zero after soft reset!")

        reg_model.reg_status.read(status, rdata);
        if (rdata != 32'h2A) `uvm_error("FIFO_BND_SEQ", $sformatf("STATUS mismatch after reset: got 0x%08h, exp 0x2A", rdata))

        // Normal Functional Frame Execution Post-Recovery
        `uvm_info("FIFO_BND_SEQ", "Running normal functional frame post-recovery...", UVM_LOW)
        reg_model.reg_int_en.write(status, 32'h01);
        reg_model.reg_ctrl.write(status, 32'h01);

        for (int i = 0; i < 32; i++) begin
            push_sample(32'h4000_0000);
        end

        wait_for_irq(1'b1);
        wait_for_out_level(32, 2000);
        wait_for_idle(2000);

        for (int i = 0; i < 32; i++) begin
            pop_sample(sample_val);
        end

        reg_model.reg_int_status.write(status, 32'h01);
        wait_for_irq(1'b0);
        reg_model.reg_ctrl.write(status, 32'h00);

        `uvm_info("FIFO_BND_SEQ", "FIFO Boundary & Overflow/Underflow Sequence completed successfully!", UVM_LOW)
    endtask

endclass : fft_fifo_boundary_seq

`endif // FFT_FIFO_BOUNDARY_SEQ_SVH
