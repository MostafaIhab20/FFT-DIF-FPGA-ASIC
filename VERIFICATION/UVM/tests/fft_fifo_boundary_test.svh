// =============================================================================
// File Name      : fft_fifo_boundary_test.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-07
// Version        : 1.0
// Description    : Test bench executing FIFO boundary, overflow, and underflow
//                  verification scenarios for the FFT peripheral.
// =============================================================================

`ifndef FFT_FIFO_BOUNDARY_TEST_SVH
`define FFT_FIFO_BOUNDARY_TEST_SVH

class fft_fifo_boundary_test extends fft_base_test;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(fft_fifo_boundary_test)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_fifo_boundary_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ==================================================
    // UVM Run Phase
    // ==================================================
    virtual task run_phase(uvm_phase phase);
        fft_fifo_boundary_seq seq;

        phase.raise_objection(this, "Starting fft_fifo_boundary_seq");
        `uvm_info("FIFO_BND_TEST", "Launching FIFO Boundary Verification Test...", UVM_LOW)

        seq = fft_fifo_boundary_seq::type_id::create("seq");
        seq.start(m_env.m_virtual_sequencer);

        // Allow drain time for final scoreboard and pipeline assertions
        #500ns;

        `uvm_info("FIFO_BND_TEST", "FIFO Boundary Verification Test Completed!", UVM_LOW)
        phase.drop_objection(this, "Completed fft_fifo_boundary_seq");
    endtask

endclass : fft_fifo_boundary_test

`endif // FFT_FIFO_BOUNDARY_TEST_SVH
