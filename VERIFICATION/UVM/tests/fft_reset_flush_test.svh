// =============================================================================
// File Name      : fft_reset_flush_test.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-07
// Version        : 1.0
// Description    : Test bench executing reset and FIFO flush strobe verification.
//                  Validates soft_reset, flush_in, and flush_out control strobes.
// =============================================================================

`ifndef FFT_RESET_FLUSH_TEST_SVH
`define FFT_RESET_FLUSH_TEST_SVH

class fft_reset_flush_test extends fft_base_test;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(fft_reset_flush_test)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_reset_flush_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ==================================================
    // UVM Run Phase
    // ==================================================
    virtual task run_phase(uvm_phase phase);
        fft_reset_flush_seq seq;

        phase.raise_objection(this, "Starting fft_reset_flush_seq");
        `uvm_info("RST_FLUSH_TEST", "Launching Reset & FIFO Flush Strobe Verification Test...", UVM_LOW)

        seq = fft_reset_flush_seq::type_id::create("seq");
        seq.start(m_env.m_virtual_sequencer);

        // Allow drain time for final scoreboard and pipeline assertions
        #500ns;

        `uvm_info("RST_FLUSH_TEST", "Reset & FIFO Flush Strobe Verification Test Completed!", UVM_LOW)
        phase.drop_objection(this, "Completed fft_reset_flush_seq");
    endtask

endclass : fft_reset_flush_test

`endif // FFT_RESET_FLUSH_TEST_SVH
