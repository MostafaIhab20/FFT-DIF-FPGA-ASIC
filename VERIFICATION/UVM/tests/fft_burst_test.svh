// =============================================================================
// File Name      : fft_burst_test.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-06
// Version        : 2.0
// Description    : Burst verification test executing pipelined multi-beat AHB
//                  burst transfers into the FIFO window and through the FFT pipeline
//                  via fft_burst_transfer_vseq.
// =============================================================================

`ifndef FFT_BURST_TEST_SVH
`define FFT_BURST_TEST_SVH

class fft_burst_test extends fft_base_test;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(fft_burst_test)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_burst_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ==================================================
    // UVM Run Phase
    // ==================================================
    virtual task run_phase(uvm_phase phase);
        fft_burst_transfer_vseq seq;

        phase.raise_objection(this, "Starting fft_burst_transfer_vseq");
        `uvm_info("BURST_TEST", "Launching AHB Burst Verification Test...", UVM_LOW)

        seq = fft_burst_transfer_vseq::type_id::create("seq");
        seq.start(m_env.m_virtual_sequencer);

        // Allow drain time for final scoreboard and pipeline assertions
        #500ns;

        `uvm_info("BURST_TEST", "AHB Burst Verification Test Completed!", UVM_LOW)
        phase.drop_objection(this, "Completed fft_burst_transfer_vseq");
    endtask

endclass : fft_burst_test

`endif // FFT_BURST_TEST_SVH
