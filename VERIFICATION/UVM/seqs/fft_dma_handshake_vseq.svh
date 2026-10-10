// =============================================================================
// File Name      : fft_dma_handshake_vseq.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-07
// Version        : 4.0
// Description    : Hardware DMA handshake and watermark flow control virtual sequence.
//                  Validates dynamic assertion, deassertion, and gating of dma_rx_req
//                  and dma_tx_req across configurable watermark boundaries (IN_THRESH
//                  and OUT_THRESH) with reactive sideband synchronization.
// =============================================================================

`ifndef FFT_DMA_HANDSHAKE_VSEQ_SVH
`define FFT_DMA_HANDSHAKE_VSEQ_SVH

class fft_dma_handshake_vseq extends fft_base_vseq;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(fft_dma_handshake_vseq)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_dma_handshake_vseq");
        super.new(name);
    endfunction

    // ==================================================
    // Sequence Body Task
    // ==================================================
    virtual task body();
        uvm_status_e   status;
        uvm_reg_data_t rdata;
        bit [31:0]     samples_10[10];
        bit [31:0]     samples_22[22];
        bit [31:0]     drain_samples[];

        `uvm_info("DMA_HANDSHAKE_VSEQ", "Starting Hardware DMA Handshake Sequence...", UVM_LOW)

        // ==================================================
        // Configurations
        // ==================================================
        // Identification Check via RAL
        reg_model.reg_id.read(status, rdata);
        reg_model.reg_version.read(status, rdata);

        // Verify initial state: DMA disabled, RX/TX requests inactive
        reg_model.reg_ctrl.read(status, rdata);
        if (rdata != 32'h0) `uvm_error("DMA_HANDSHAKE_VSEQ", $sformatf("Initial CTRL non-zero: 0x%08h", rdata))

        wait_for_dma_rx(1'b0);
        wait_for_dma_tx(1'b0);

        // Program Custom Watermarks (IN_THRESH = 8, OUT_THRESH = 16) via RAL
        `uvm_info("DMA_HANDSHAKE_VSEQ", "Programming watermarks: IN_THRESH = 8, OUT_THRESH = 16...", UVM_LOW)
        reg_model.reg_in_thresh.write(status, 32'd8);
        reg_model.reg_out_thresh.write(status, 32'd16);

        reg_model.reg_in_thresh.read(status, rdata);
        if (rdata != 32'd8) `uvm_error("DMA_HANDSHAKE_VSEQ", $sformatf("IN_THRESH mismatch: got %0d, exp 8", rdata))

        reg_model.reg_out_thresh.read(status, rdata);
        if (rdata != 32'd16) `uvm_error("DMA_HANDSHAKE_VSEQ", $sformatf("OUT_THRESH mismatch: got %0d, exp 16", rdata))

        // ==================================================
        // Test Scenario
        // ==================================================
        // Testing DMA RX gating: Setting dma_en=1 with enable=0 (CTRL = 0x02)
        `uvm_info("DMA_HANDSHAKE_VSEQ", "Testing DMA RX gating: Setting dma_en=1 with enable=0 (CTRL = 0x02)...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h02); // dma_en = 1 (bit 1), enable = 0 (bit 0)
        wait_for_dma_rx(1'b0);
        `uvm_info("DMA_HANDSHAKE_VSEQ", "PASS: dma_rx_req correctly gated by core enable", UVM_MEDIUM)

        // Enabling DMA mode with core active (CTRL = 0x03)
        `uvm_info("DMA_HANDSHAKE_VSEQ", "Enabling DMA mode with core active (CTRL = 0x03)...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h03);
        wait_for_dma_rx(1'b1);
        `uvm_info("DMA_HANDSHAKE_VSEQ", "PASS: dma_rx_req asserted for empty IN FIFO", UVM_MEDIUM)

        // Stop core temporarily to stage samples without immediate processing
        reg_model.reg_ctrl.write(status, 32'h00);

        // Streaming 10 samples via burst to cross IN_THRESH = 8
        for (int i = 0; i < 10; i++) samples_10[i] = 32'h2000_1000;
        `uvm_info("DMA_HANDSHAKE_VSEQ", "Streaming 10 samples via burst to cross IN_THRESH = 8...", UVM_LOW)
        push_samples_burst(samples_10, HBURST_INCR);

        reg_model.reg_in_level.read(status, rdata);
        if (rdata != 32'd10) `uvm_error("DMA_HANDSHAKE_VSEQ", $sformatf("IN_LEVEL mismatch: got %0d, exp 10", rdata))

        // Confirm in_almost_empty is deasserted (10 > 8)
        reg_model.reg_status.read(status, rdata);
        if ((rdata & 32'h20) != 32'h0) `uvm_error("DMA_HANDSHAKE_VSEQ", "Expected in_almost_empty to deassert (STATUS[5]=0)")
        else `uvm_info("DMA_HANDSHAKE_VSEQ", "PASS: in_almost_empty deasserted when in_level > in_thresh", UVM_MEDIUM)

        // Dynamically increasing IN_THRESH to 15 (10 <= 15)
        `uvm_info("DMA_HANDSHAKE_VSEQ", "Dynamically increasing IN_THRESH to 15 (10 <= 15)...", UVM_LOW)
        reg_model.reg_in_thresh.write(status, 32'd15);
        reg_model.reg_status.read(status, rdata);
        if ((rdata & 32'h20) == 32'h0) `uvm_error("DMA_HANDSHAKE_VSEQ", "Expected in_almost_empty to reassert (STATUS[5]=1)")
        else `uvm_info("DMA_HANDSHAKE_VSEQ", "PASS: in_almost_empty reasserted after threshold increase", UVM_MEDIUM)

        // Return IN_THRESH back to 8 (10 > 8)
        reg_model.reg_in_thresh.write(status, 32'd8);
        reg_model.reg_status.read(status, rdata);
        if ((rdata & 32'h20) != 32'h0) `uvm_error("DMA_HANDSHAKE_VSEQ", "Expected in_almost_empty to deassert when reset to 8")

        // Streaming remaining 22 samples via burst to complete frame
        for (int i = 0; i < 22; i++) samples_22[i] = 32'h2000_1000;
        `uvm_info("DMA_HANDSHAKE_VSEQ", "Streaming remaining 22 samples via burst to complete frame...", UVM_LOW)
        push_samples_burst(samples_22, HBURST_INCR);

        // Enable core and DMA mode to compute frame
        reg_model.reg_ctrl.write(status, 32'h03);

        // Await frame completion: OUT_LEVEL reaches 32 (> OUT_THRESH = 16)
        wait_for_out_level(32, 2000);
        wait_for_idle(2000);

        reg_model.reg_status.read(status, rdata);
        if ((rdata & 32'h40) == 32'h0) `uvm_error("DMA_HANDSHAKE_VSEQ", "Expected out_almost_full to be asserted (STATUS[6]=1)")

        wait_for_dma_tx(1'b1);
        `uvm_info("DMA_HANDSHAKE_VSEQ", "PASS: dma_tx_req asserted correctly for full output buffer", UVM_MEDIUM)

        // Drain 20 samples from OUT FIFO (level drops from 32 to 12 < 16) -> dma_tx_req deasserts
        `uvm_info("DMA_HANDSHAKE_VSEQ", "Popping 20 samples to drain OUT FIFO below watermark (level drops to 12)...", UVM_LOW)
        pop_samples_burst(drain_samples, 20, HBURST_INCR);

        reg_model.reg_out_level.read(status, rdata);
        `uvm_info("DMA_HANDSHAKE_VSEQ", $sformatf("OUT_LEVEL after partial drain: %0d", rdata), UVM_MEDIUM)

        reg_model.reg_status.read(status, rdata);
        if ((rdata & 32'h40) != 32'h0) `uvm_error("DMA_HANDSHAKE_VSEQ", "Expected out_almost_full to deassert (STATUS[6]=0)")

        wait_for_dma_tx(1'b0);
        `uvm_info("DMA_HANDSHAKE_VSEQ", "PASS: dma_tx_req successfully deasserted when out_level < out_thresh", UVM_MEDIUM)

        // Drain remaining 12 samples to empty OUT FIFO
        pop_samples_burst(drain_samples, 12, HBURST_INCR);

        // Disable DMA mode & core via RAL, and clear FRAME_DONE
        reg_model.reg_ctrl.write(status, 32'h00);
        reg_model.reg_int_status.write(status, 32'h01);

        wait_for_dma_rx(1'b0);
        wait_for_dma_tx(1'b0);

        `uvm_info("DMA_HANDSHAKE_VSEQ", "Hardware DMA Handshake Sequence completed successfully!", UVM_LOW)
    endtask

endclass : fft_dma_handshake_vseq

`endif // FFT_DMA_HANDSHAKE_VSEQ_SVH
