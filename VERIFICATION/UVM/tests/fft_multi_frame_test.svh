// =============================================================================
// File Name      : fft_multi_frame_test.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-07
// Version        : 2.0
// Description    : Test bench executing continuous multi-frame random streaming
//                  via fft_multi_frame_vseq.
// =============================================================================

`ifndef FFT_MULTI_FRAME_TEST_SVH
`define FFT_MULTI_FRAME_TEST_SVH

class fft_multi_frame_test extends fft_base_test;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(fft_multi_frame_test)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_multi_frame_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ==================================================
    // UVM Run Phase
    // ==================================================
    virtual task run_phase(uvm_phase phase);
        fft_multi_frame_vseq seq;

        phase.raise_objection(this, "Starting fft_multi_frame_vseq");
        `uvm_info("MULTI_FRAME_TEST", "Launching Multi-Frame Random Streaming Test...", UVM_LOW)

        seq = fft_multi_frame_vseq::type_id::create("seq");
        if (!seq.randomize()) begin
            `uvm_fatal("MULTI_FRAME_TEST", "Randomization failed for fft_multi_frame_vseq")
        end
        seq.start(m_env.m_virtual_sequencer);

        // Allow drain time for final scoreboard and pipeline assertions
        #500ns;

        `uvm_info("MULTI_FRAME_TEST", "Multi-Frame Random Streaming Test Completed!", UVM_LOW)
        phase.drop_objection(this, "Completed fft_multi_frame_vseq");
    endtask

endclass : fft_multi_frame_test

`endif // FFT_MULTI_FRAME_TEST_SVH
