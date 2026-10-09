// =============================================================================
// File Name      : fft_coverage_closure_test.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-07
// Version        : 1.0
// Description    : Specialized UVM test executing the coverage closure sequence
//                  to close remaining branch, condition, and assertion coverage gaps.
// =============================================================================

`ifndef FFT_COVERAGE_CLOSURE_TEST_SVH
`define FFT_COVERAGE_CLOSURE_TEST_SVH

class fft_coverage_closure_test extends fft_base_test;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(fft_coverage_closure_test)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_coverage_closure_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ==================================================
    // UVM Run Phase
    // ==================================================
    virtual task run_phase(uvm_phase phase);
        fft_coverage_closure_seq seq;

        phase.raise_objection(this, "Starting fft_coverage_closure_seq");
        `uvm_info("COV_CLOSURE_TEST", "Launching FFT Coverage Closure Verification Test...", UVM_LOW)

        // Temporarily disable master-side word alignment SVA during intentional negative fault injection
        if (m_env_cfg.vif_ahb != null) begin
            m_env_cfg.vif_ahb.enable_alignment_check = 1'b0;
        end

        seq = fft_coverage_closure_seq::type_id::create("seq");
        seq.start(m_env.m_virtual_sequencer);

        if (m_env_cfg.vif_ahb != null) begin
            m_env_cfg.vif_ahb.enable_alignment_check = 1'b1;
        end

        // Allow drain time for final scoreboard and pipeline checks
        #500ns;

        `uvm_info("COV_CLOSURE_TEST", "FFT Coverage Closure Verification Test Completed!", UVM_LOW)
        phase.drop_objection(this, "Completed fft_coverage_closure_seq");
    endtask

endclass : fft_coverage_closure_test

`endif // FFT_COVERAGE_CLOSURE_TEST_SVH
