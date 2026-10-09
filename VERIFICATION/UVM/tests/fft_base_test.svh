// =============================================================================
// File Name      : fft_base_test.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Base UVM test setting up environment configuration,
//                  objection handling, and simulation timeouts.
// =============================================================================

`ifndef FFT_BASE_TEST_SVH
`define FFT_BASE_TEST_SVH

class fft_base_test extends uvm_test;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(fft_base_test)

    // ==================================================
    // Environment & Configuration Handles
    // ==================================================
    fft_env        m_env;
    fft_env_config m_env_cfg;

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ==================================================
    // UVM Build Phase
    // ==================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        m_env_cfg = fft_env_config::type_id::create("m_env_cfg");

        // Configure environment topology and feature switches
        m_env_cfg.has_ahb_agent      = 1'b1;
        m_env_cfg.has_sideband_agent = 1'b1;
        m_env_cfg.is_active_ahb      = UVM_ACTIVE;
        m_env_cfg.is_active_sb       = UVM_PASSIVE;
        m_env_cfg.has_scoreboard     = 1'b1;
        m_env_cfg.has_coverage       = 1'b1;
        m_env_cfg.has_reg_model      = 1'b1;

        // Retrieve physical interface handles from top-level testbench
        if (m_env_cfg.has_ahb_agent) begin
            if (!uvm_config_db#(virtual ahb_if)::get(this, "", "vif", m_env_cfg.vif_ahb)) begin
                `uvm_fatal("BASE_TEST", "Virtual interface 'vif' (AHB) not found in config_db")
            end
        end
        if (m_env_cfg.has_sideband_agent) begin
            if (!uvm_config_db#(virtual sideband_if)::get(this, "", "vif", m_env_cfg.vif_sb)) begin
                `uvm_fatal("BASE_TEST", "Virtual interface 'vif' (Sideband) not found in config_db")
            end
        end

        // Publish environment configuration to UVM config database
        uvm_config_db#(fft_env_config)::set(this, "m_env", "cfg", m_env_cfg);

        // Instantiate verification environment
        m_env = fft_env::type_id::create("m_env", this);
    endfunction

    // ==================================================
    // UVM Connect Phase
    // ==================================================
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (m_env.m_reg_model != null) begin
            uvm_config_db#(fft_reg_block)::set(this, "*", "reg_model", m_env.m_reg_model);
            uvm_config_db#(fft_reg_block)::set(null, "*", "reg_model", m_env.m_reg_model);
        end
    endfunction

    // ==================================================
    // UVM End of Elaboration Phase
    // ==================================================
    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction

    // ==================================================
    // UVM Run Phase
    // ==================================================
    virtual task run_phase(uvm_phase phase);
        super.run_phase(phase);
    endtask

endclass : fft_base_test

`endif // FFT_BASE_TEST_SVH
