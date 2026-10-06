// =============================================================================
// File Name      : fft_env.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Top-level UVM verification environment encapsulating
//                  agents, scoreboard, and functional coverage subscribers.
// =============================================================================

`ifndef FFT_ENV_SVH
`define FFT_ENV_SVH

class fft_env extends uvm_env;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(fft_env)

    // ==================================================
    // Component & Configuration Handles
    // ==================================================
    fft_env_config m_cfg;
    ahb_agent      m_ahb_agent;
    sideband_agent m_sideband_agent;
    fft_scoreboard m_scoreboard;
    fft_coverage   m_coverage;

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ==================================================
    // UVM Build Phase
    // ==================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(fft_env_config)::get(this, "", "cfg", m_cfg)) begin
            `uvm_fatal("FFT_ENV", "Unable to get fft_env_config from uvm_config_db!")
        end

        // Configure and instantiate AHB Agent
        if (m_cfg.has_ahb_agent) begin
            ahb_agent_config ahb_cfg = ahb_agent_config::type_id::create("ahb_cfg");
            ahb_cfg.vif       = m_cfg.vif_ahb;
            ahb_cfg.is_active = m_cfg.is_active_ahb;
            uvm_config_db#(ahb_agent_config)::set(this, "m_ahb_agent", "cfg", ahb_cfg);
            m_ahb_agent = ahb_agent::type_id::create("m_ahb_agent", this);
        end

        // Configure and instantiate Sideband Agent
        if (m_cfg.has_sideband_agent) begin
            sideband_agent_config sb_cfg = sideband_agent_config::type_id::create("sb_cfg");
            sb_cfg.vif = m_cfg.vif_sb;
            uvm_config_db#(sideband_agent_config)::set(this, "m_sideband_agent", "cfg", sb_cfg);
            m_sideband_agent = sideband_agent::type_id::create("m_sideband_agent", this);
        end

        // Conditionally build Scoreboard
        if (m_cfg.has_scoreboard) begin
            m_scoreboard = fft_scoreboard::type_id::create("m_scoreboard", this);
        end

        // Conditionally build Functional Coverage
        if (m_cfg.has_coverage) begin
            m_coverage = fft_coverage::type_id::create("m_coverage", this);
        end
    endfunction

    // ==================================================
    // UVM Connect Phase
    // ==================================================
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Scoreboard connections
        if (m_cfg.has_scoreboard) begin
            if (m_cfg.has_ahb_agent) begin
                m_ahb_agent.ahb_agt_ap.connect(m_scoreboard.ahb_export);
            end
            if (m_cfg.has_sideband_agent) begin
                m_sideband_agent.sb_agt_ap.connect(m_scoreboard.sideband_export);
            end
        end

        // Coverage connections
        if (m_cfg.has_coverage) begin
            if (m_cfg.has_ahb_agent) begin
                m_ahb_agent.ahb_agt_ap.connect(m_coverage.analysis_export);
            end
            if (m_cfg.has_sideband_agent) begin
                m_sideband_agent.sb_agt_ap.connect(m_coverage.sideband_export);
            end
        end
    endfunction

endclass : fft_env

`endif // FFT_ENV_SVH
