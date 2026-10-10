// =============================================================================
// File Name      : fft_sanity_test.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 2.0
// Description    : Sanity test executing peripheral discovery and DC FFT computation
//                  via fft_single_frame_vseq.
// =============================================================================

`ifndef FFT_SANITY_TEST_SVH
`define FFT_SANITY_TEST_SVH

class fft_sanity_test extends fft_base_test;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(fft_sanity_test)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_sanity_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ==================================================
    // UVM Run Phase
    // ==================================================
    virtual task run_phase(uvm_phase phase);
        fft_single_frame_vseq seq;

        phase.raise_objection(this, "Starting fft_single_frame_vseq");
        `uvm_info("SANITY_TEST", "Launching Single-Frame Sanity Verification Test...", UVM_LOW)

        seq = fft_single_frame_vseq::type_id::create("seq");
        seq.start(m_env.m_virtual_sequencer);

        // Allow drain time for final scoreboard and pipeline assertions
        #500ns;

        `uvm_info("SANITY_TEST", "Single-Frame Sanity Verification Test Completed!", UVM_LOW)
        phase.drop_objection(this, "Completed fft_single_frame_vseq");
    endtask

endclass : fft_sanity_test

`endif // FFT_SANITY_TEST_SVH
