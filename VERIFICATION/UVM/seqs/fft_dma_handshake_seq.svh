// =============================================================================
// File Name      : fft_dma_handshake_seq.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-07
// Version        : 3.0 (Virtual Sequence with Reactive Sideband Verification)
// Description    : Hardware DMA request and watermark threshold verification.
//                  Validates dynamic assertion and gating of dma_rx_req and dma_tx_req
//                  across configurable watermark boundaries using sideband reactive seqs.
// =============================================================================

`ifndef FFT_DMA_HANDSHAKE_SEQ_SVH
`define FFT_DMA_HANDSHAKE_SEQ_SVH

class fft_dma_handshake_seq extends fft_base_vseq;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(fft_dma_handshake_seq)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_dma_handshake_seq");
        super.new(name);
    endfunction

    // ==================================================
    // Sequence Body Task
    // ==================================================
    virtual task body();
        uvm_status_e      status;
        uvm_reg_data_t    rdata;
        bit [31:0]        sample_val;

        `uvm_info("DMA_SEQ", "Starting Hardware DMA Handshake Verification Sequence...", UVM_LOW)

        // ==================================================
        // Configurations
        // ==================================================
        // Peripheral Identification Check via RAL
        reg_model.reg_id.read(status, rdata);
        reg_model.reg_version.read(status, rdata);

        // Verify initial state: DMA disabled, RX/TX requests inactive
        reg_model.reg_ctrl.read(status, rdata);
        if (rdata != 32'h0) `uvm_error("DMA_SEQ", $sformatf("Initial CTRL non-zero: 0x%08h", rdata))

        wait_for_dma_rx(1'b0);
        wait_for_dma_tx(1'b0);

        // Program Custom Watermarks (IN_THRESH = 8, OUT_THRESH = 16) via RAL
        `uvm_info("DMA_SEQ", "Programming watermarks: IN_THRESH = 8, OUT_THRESH = 16...", UVM_LOW)
        reg_model.reg_in_thresh.write(status, 32'd8);
        reg_model.reg_out_thresh.write(status, 32'd16);

        reg_model.reg_in_thresh.read(status, rdata);
        if (rdata != 32'd8) `uvm_error("DMA_SEQ", $sformatf("IN_THRESH mismatch: got %0d, exp 8", rdata))

        reg_model.reg_out_thresh.read(status, rdata);
        if (rdata != 32'd16) `uvm_error("DMA_SEQ", $sformatf("OUT_THRESH mismatch: got %0d, exp 16", rdata))

        // ==================================================
        // Test Scenario
        // ==================================================
        // Verify dma_rx_req is gated by enable (dma_en=1, enable=0) via RAL
        `uvm_info("DMA_SEQ", "Testing DMA RX gating: Setting dma_en=1 with enable=0 (CTRL = 0x02)...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h02); // dma_en = 1 (bit 1), enable = 0 (bit 0)

        reg_model.reg_status.read(status, rdata);
        if ((rdata & 32'h20) == 32'h0) `uvm_error("DMA_SEQ", "Expected in_almost_empty to be set")

        wait_for_dma_rx(1'b0);
        `uvm_info("DMA_SEQ", "PASS: dma_rx_req correctly gated by core enable", UVM_MEDIUM)

        // Enable Core with DMA Mode (dma_en=1, enable=1) via RAL
        `uvm_info("DMA_SEQ", "Enabling DMA mode with core active (CTRL = 0x03)...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h03); // dma_en = 1 (bit 1), enable = 1 (bit 0)

        reg_model.reg_status.read(status, rdata);
        wait_for_dma_rx(1'b1);
        `uvm_info("DMA_SEQ", "PASS: dma_rx_req asserted as expected for empty IN FIFO", UVM_MEDIUM)

        // Disable core temporarily via RAL to load samples into IN FIFO without immediate consumption
        reg_model.reg_ctrl.write(status, 32'h00);

        // Load 10 samples into IN FIFO (in_level = 10 > IN_THRESH = 8)
        `uvm_info("DMA_SEQ", "Streaming 10 samples with core stopped to cross IN_THRESH = 8...", UVM_LOW)
        for (int i = 0; i < 10; i++) begin
            push_sample(32'h2000_1000);
        end

        reg_model.reg_in_level.read(status, rdata);
        if (rdata != 32'd10) `uvm_error("DMA_SEQ", $sformatf("IN_LEVEL mismatch: got %0d, exp 10", rdata))

        // Check in_almost_empty deasserted (10 > 8) via RAL
        reg_model.reg_status.read(status, rdata);
        if ((rdata & 32'h20) != 32'h0) begin
            `uvm_error("DMA_SEQ", "FAIL: Expected in_almost_empty to deassert (STATUS[5]=0 when 10 > 8)")
        end else begin
            `uvm_info("DMA_SEQ", "PASS: in_almost_empty deasserted correctly when in_level > in_thresh", UVM_MEDIUM)
        end

        // Reconfigure IN_THRESH dynamically to 15 (10 <= 15) -> in_almost_empty must reassert via RAL
        `uvm_info("DMA_SEQ", "Dynamically increasing IN_THRESH to 15 (10 <= 15)...", UVM_LOW)
        reg_model.reg_in_thresh.write(status, 32'd15);

        reg_model.reg_status.read(status, rdata);
        if ((rdata & 32'h20) == 32'h0) begin
            `uvm_error("DMA_SEQ", "FAIL: Expected in_almost_empty to reassert (STATUS[5]=1 when 10 <= 15)")
        end else begin
            `uvm_info("DMA_SEQ", "PASS: in_almost_empty reasserted correctly after threshold expansion", UVM_MEDIUM)
        end

        // Reconfigure IN_THRESH back to 8 (10 > 8) -> in_almost_empty must deassert via RAL
        reg_model.reg_in_thresh.write(status, 32'd8);
        reg_model.reg_status.read(status, rdata);
        if ((rdata & 32'h20) != 32'h0) begin
            `uvm_error("DMA_SEQ", "FAIL: Expected in_almost_empty to deassert when threshold reduced back to 8")
        end

        // Push remaining 22 samples to form a complete 32-sample frame
        `uvm_info("DMA_SEQ", "Pushing remaining 22 samples to complete 32-sample frame...", UVM_LOW)
        for (int i = 0; i < 22; i++) begin
            push_sample(32'h2000_1000);
        end

        // Enable core and DMA mode to process frame via RAL
        `uvm_info("DMA_SEQ", "Enabling core and DMA mode (CTRL = 0x03) to process full frame...", UVM_LOW)
        reg_model.reg_ctrl.write(status, 32'h03);

        // Await frame processing completion
        wait_for_out_level(32, 2000);
        wait_for_idle(2000);

        // Verify out_level >= 16 (out_level is 32) -> dma_tx_req must assert to 1 via RAL
        reg_model.reg_out_level.read(status, rdata);
        `uvm_info("DMA_SEQ", $sformatf("OUT_LEVEL after frame computation: %0d", rdata), UVM_MEDIUM)

        reg_model.reg_status.read(status, rdata);
        if ((rdata & 32'h40) == 32'h0) `uvm_error("DMA_SEQ", "Expected out_almost_full to be set (STATUS[6]=1)")

        wait_for_dma_tx(1'b1);
        `uvm_info("DMA_SEQ", "PASS: dma_tx_req asserted correctly for full output buffer", UVM_MEDIUM)

        // Drain 20 samples from OUT FIFO (out_level drops to 12 < 16) -> dma_tx_req must deassert
        `uvm_info("DMA_SEQ", "Popping 20 samples to drain OUT FIFO below watermark (level drops to 12)...", UVM_LOW)
        for (int i = 0; i < 20; i++) begin
            pop_sample(sample_val);
        end

        reg_model.reg_out_level.read(status, rdata);
        `uvm_info("DMA_SEQ", $sformatf("OUT_LEVEL after partial drain: %0d", rdata), UVM_MEDIUM)

        reg_model.reg_status.read(status, rdata);
        if ((rdata & 32'h40) != 32'h0) `uvm_error("DMA_SEQ", "Expected out_almost_full to deassert (STATUS[6]=0)")

        wait_for_dma_tx(1'b0);
        `uvm_info("DMA_SEQ", "PASS: dma_tx_req successfully deasserted when out_level < out_thresh", UVM_MEDIUM)

        // Pop remaining 12 samples to completely empty OUT FIFO
        for (int i = 0; i < 12; i++) begin
            pop_sample(sample_val);
        end

        // Disable DMA mode & core via RAL
        reg_model.reg_ctrl.write(status, 32'h00);
        reg_model.reg_int_status.write(status, 32'h01); // Clear FRAME_DONE

        wait_for_dma_rx(1'b0);
        wait_for_dma_tx(1'b0);

        `uvm_info("DMA_SEQ", "Hardware DMA Handshake Sequence completed successfully!", UVM_LOW)
    endtask

endclass : fft_dma_handshake_seq

`endif // FFT_DMA_HANDSHAKE_SEQ_SVH
