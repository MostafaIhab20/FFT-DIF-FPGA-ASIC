// =============================================================================
// File Name      : sideband_reactive_seqs.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-09
// Version        : 2.0 (Drain Queue + Immediate Level Check + Fork Isolation)
// Description    : Reactive event-driven sequences for sideband signals.
//                  Provides dedicated sequences blocking on IRQ, DMA RX, and DMA TX
//                  analysis FIFOs inside sideband_sequencer.
// =============================================================================

`ifndef SIDEBAND_REACTIVE_SEQS_SVH
`define SIDEBAND_REACTIVE_SEQS_SVH

// =============================================================================
// Wait for Interrupt sequence
// =============================================================================
class sideband_wait_irq_seq extends uvm_sequence #(sideband_seq_item);

    // ==================================================
    // Factory Registration & P_SEQUENCER Hook
    // ==================================================
    `uvm_object_utils(sideband_wait_irq_seq)
    `uvm_declare_p_sequencer(sideband_sequencer)

    // ==================================================
    // Configuration Fields
    // ==================================================
    rand bit  expected_val; // Target state (1'b1: assert, 1'b0: deassert)
    time      timeout;      // Watchdog timeout limit
    sideband_seq_item item; // Captured transaction

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "sideband_wait_irq_seq");
        super.new(name);
        expected_val = 1'b1;
        timeout      = 100us;
    endfunction

    // ==================================================
    // Sequence Body Task
    // ==================================================
    virtual task body();
        bit timed_out = 1'b0;

        `uvm_info("WAIT_IRQ_SEQ", $sformatf("Checking/waiting for IRQ == %0b...", expected_val), UVM_HIGH)

        // 1. Drain FIFO to process latest queued updates
        while (p_sequencer.irq_fifo.try_get(item)) begin
            if (item.irq === expected_val) begin
                `uvm_info("WAIT_IRQ_SEQ", $sformatf("Detected IRQ == %0b from queued item at %0t", item.irq, $time), UVM_HIGH)
                return;
            end
        end

        // 2. If current state is already satisfied, return immediately
        if (p_sequencer.cur_irq === expected_val) begin
            `uvm_info("WAIT_IRQ_SEQ", $sformatf("Confirmed IRQ is already %0b at %0t", expected_val, $time), UVM_HIGH)
            return;
        end

        // 3. Otherwise, block until the expected transition occurs or timeout
        fork
            begin : timeout_guard
                fork
                    begin
                        do begin
                            p_sequencer.irq_fifo.get(item);
                        end while (item.irq !== expected_val);
                    end
                    begin
                        #timeout;
                        timed_out = 1'b1;
                    end
                join_any
                disable fork;
            end
        join

        if (timed_out) begin
            `uvm_error("WAIT_IRQ_SEQ", $sformatf("Timeout (%0t) exceeded waiting for IRQ == %0b!", timeout, expected_val))
        end else begin
            `uvm_info("WAIT_IRQ_SEQ", $sformatf("Successfully detected IRQ == %0b at %0t", item.irq, $time), UVM_HIGH)
        end
    endtask

endclass : sideband_wait_irq_seq


// =============================================================================
// Wait for DMA RX Request sequence
// =============================================================================
class sideband_wait_dma_rx_seq extends uvm_sequence #(sideband_seq_item);

    // ==================================================
    // Factory Registration & P_SEQUENCER Hook
    // ==================================================
    `uvm_object_utils(sideband_wait_dma_rx_seq)
    `uvm_declare_p_sequencer(sideband_sequencer)

    // ==================================================
    // Configuration Fields
    // ==================================================
    rand bit  expected_val; // Target state (1'b1: assert, 1'b0: deassert)
    time      timeout;      // Watchdog timeout limit
    sideband_seq_item item; // Captured transaction

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "sideband_wait_dma_rx_seq");
        super.new(name);
        expected_val = 1'b1;
        timeout      = 100us;
    endfunction

    // ==================================================
    // Sequence Body Task
    // ==================================================
    virtual task body();
        bit timed_out = 1'b0;

        `uvm_info("WAIT_DMA_RX_SEQ", $sformatf("Checking/waiting for dma_rx_req == %0b...", expected_val), UVM_HIGH)

        // 1. Drain FIFO to process latest queued updates
        while (p_sequencer.dma_rx_fifo.try_get(item)) begin
            if (item.dma_rx_req === expected_val) begin
                `uvm_info("WAIT_DMA_RX_SEQ", $sformatf("Detected dma_rx_req == %0b from queued item at %0t", item.dma_rx_req, $time), UVM_HIGH)
                return;
            end
        end

        // 2. If current state is already satisfied, return immediately
        if (p_sequencer.cur_dma_rx === expected_val) begin
            `uvm_info("WAIT_DMA_RX_SEQ", $sformatf("Confirmed dma_rx_req is already %0b at %0t", expected_val, $time), UVM_HIGH)
            return;
        end

        // 3. Otherwise, block until the expected transition occurs or timeout
        fork
            begin : timeout_guard
                fork
                    begin
                        do begin
                            p_sequencer.dma_rx_fifo.get(item);
                        end while (item.dma_rx_req !== expected_val);
                    end
                    begin
                        #timeout;
                        timed_out = 1'b1;
                    end
                join_any
                disable fork;
            end
        join

        if (timed_out) begin
            `uvm_error("WAIT_DMA_RX_SEQ", $sformatf("Timeout (%0t) exceeded waiting for dma_rx_req == %0b!", timeout, expected_val))
        end else begin
            `uvm_info("WAIT_DMA_RX_SEQ", $sformatf("Successfully detected dma_rx_req == %0b at %0t", item.dma_rx_req, $time), UVM_HIGH)
        end
    endtask

endclass : sideband_wait_dma_rx_seq


// =============================================================================
// Wait for DMA TX Request sequence
// =============================================================================
class sideband_wait_dma_tx_seq extends uvm_sequence #(sideband_seq_item);

    // ==================================================
    // Factory Registration & P_SEQUENCER Hook
    // ==================================================
    `uvm_object_utils(sideband_wait_dma_tx_seq)
    `uvm_declare_p_sequencer(sideband_sequencer)

    // ==================================================
    // Configuration Fields
    // ==================================================
    rand bit  expected_val; // Target state (1'b1: assert, 1'b0: deassert)
    time      timeout;      // Watchdog timeout limit
    sideband_seq_item item; // Captured transaction

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "sideband_wait_dma_tx_seq");
        super.new(name);
        expected_val = 1'b1;
        timeout      = 100us;
    endfunction

    // ==================================================
    // Sequence Body Task
    // ==================================================
    virtual task body();
        bit timed_out = 1'b0;

        `uvm_info("WAIT_DMA_TX_SEQ", $sformatf("Checking/waiting for dma_tx_req == %0b...", expected_val), UVM_HIGH)

        // 1. Drain FIFO to process latest queued updates
        while (p_sequencer.dma_tx_fifo.try_get(item)) begin
            if (item.dma_tx_req === expected_val) begin
                `uvm_info("WAIT_DMA_TX_SEQ", $sformatf("Detected dma_tx_req == %0b from queued item at %0t", item.dma_tx_req, $time), UVM_HIGH)
                return;
            end
        end

        // 2. If current state is already satisfied, return immediately
        if (p_sequencer.cur_dma_tx === expected_val) begin
            `uvm_info("WAIT_DMA_TX_SEQ", $sformatf("Confirmed dma_tx_req is already %0b at %0t", expected_val, $time), UVM_HIGH)
            return;
        end

        // 3. Otherwise, block until the expected transition occurs or timeout
        fork
            begin : timeout_guard
                fork
                    begin
                        do begin
                            p_sequencer.dma_tx_fifo.get(item);
                        end while (item.dma_tx_req !== expected_val);
                    end
                    begin
                        #timeout;
                        timed_out = 1'b1;
                    end
                join_any
                disable fork;
            end
        join

        if (timed_out) begin
            `uvm_error("WAIT_DMA_TX_SEQ", $sformatf("Timeout (%0t) exceeded waiting for dma_tx_req == %0b!", timeout, expected_val))
        end else begin
            `uvm_info("WAIT_DMA_TX_SEQ", $sformatf("Successfully detected dma_tx_req == %0b at %0t", item.dma_tx_req, $time), UVM_HIGH)
        end
    endtask

endclass : sideband_wait_dma_tx_seq

`endif // SIDEBAND_REACTIVE_SEQS_SVH
