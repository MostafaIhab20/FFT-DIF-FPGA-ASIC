// =============================================================================
// File Name      : fft_dma_handshake_test.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-07
// Version        : 3.0
// Description    : Test bench executing hardware DMA flow control verification
//                  via fft_dma_handshake_vseq.
// =============================================================================

`ifndef FFT_DMA_HANDSHAKE_TEST_SVH
`define FFT_DMA_HANDSHAKE_TEST_SVH

class fft_dma_handshake_test extends fft_base_test;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(fft_dma_handshake_test)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_dma_handshake_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ==================================================
    // UVM Run Phase
    // ==================================================
    virtual task run_phase(uvm_phase phase);
        fft_dma_handshake_vseq seq;

        phase.raise_objection(this, "Starting fft_dma_handshake_vseq");
        `uvm_info("DMA_TEST", "Launching Hardware DMA Handshake Test...", UVM_LOW)

        seq = fft_dma_handshake_vseq::type_id::create("seq");
        seq.start(m_env.m_virtual_sequencer);

        // Allow drain time for final scoreboard and pipeline assertions
        #500ns;

        `uvm_info("DMA_TEST", "Hardware DMA Handshake Test Completed!", UVM_LOW)
        phase.drop_objection(this, "Completed fft_dma_handshake_vseq");
    endtask

endclass : fft_dma_handshake_test

`endif // FFT_DMA_HANDSHAKE_TEST_SVH
