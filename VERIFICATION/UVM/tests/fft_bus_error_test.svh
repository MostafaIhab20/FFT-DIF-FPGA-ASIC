// =============================================================================
// File Name      : fft_bus_error_test.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-07
// Version        : 2.0
// Description    : Test bench executing bus error and negative protocol stimulus
//                  via fft_bus_protocol_error_vseq.
// =============================================================================

`ifndef FFT_BUS_ERROR_TEST_SVH
`define FFT_BUS_ERROR_TEST_SVH

class fft_bus_error_test extends fft_base_test;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(fft_bus_error_test)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_bus_error_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ==================================================
    // UVM Run Phase
    // ==================================================
    virtual task run_phase(uvm_phase phase);
        fft_bus_protocol_error_vseq seq;

        phase.raise_objection(this, "Starting fft_bus_protocol_error_vseq");
        `uvm_info("BUS_ERROR_TEST", "Launching Bus Error & Negative Protocol Test...", UVM_LOW)

        // Temporarily disable master-side word alignment SVA during intentional negative fault injection
        if (m_env_cfg.vif_ahb != null) begin
            m_env_cfg.vif_ahb.enable_alignment_check = 1'b0;
        end

        seq = fft_bus_protocol_error_vseq::type_id::create("seq");
        seq.start(m_env.m_virtual_sequencer);

        if (m_env_cfg.vif_ahb != null) begin
            m_env_cfg.vif_ahb.enable_alignment_check = 1'b1;
        end

        // Allow drain time for final scoreboard and pipeline assertions
        #500ns;

        `uvm_info("BUS_ERROR_TEST", "Bus Error & Negative Protocol Test Completed!", UVM_LOW)
        phase.drop_objection(this, "Completed fft_bus_protocol_error_vseq");
    endtask

endclass : fft_bus_error_test

`endif // FFT_BUS_ERROR_TEST_SVH
