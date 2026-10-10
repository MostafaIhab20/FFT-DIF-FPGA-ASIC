// =============================================================================
// File Name      : fft_reset_flush_test.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-07
// Version        : 2.0
// Description    : Test bench executing reset and FIFO flush strobe verification
//                  via fft_control_reset_flush_vseq.
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
        fft_control_reset_flush_vseq seq;

        phase.raise_objection(this, "Starting fft_control_reset_flush_vseq");
        `uvm_info("RST_FLUSH_TEST", "Launching Reset & FIFO Flush Strobe Verification Test...", UVM_LOW)

        seq = fft_control_reset_flush_vseq::type_id::create("seq");
        seq.start(m_env.m_virtual_sequencer);

        // Allow drain time for final scoreboard and pipeline assertions
        #500ns;

        `uvm_info("RST_FLUSH_TEST", "Reset & FIFO Flush Strobe Verification Test Completed!", UVM_LOW)
        phase.drop_objection(this, "Completed fft_control_reset_flush_vseq");
    endtask

endclass : fft_reset_flush_test

`endif // FFT_RESET_FLUSH_TEST_SVH
