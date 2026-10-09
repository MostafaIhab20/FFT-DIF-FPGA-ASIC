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
    fft_env_config                    m_cfg;
    ahb_agent                         m_ahb_agent;
    sideband_agent                    m_sideband_agent;
    fft_scoreboard                    m_scoreboard;
    fft_coverage                      m_coverage;
    fft_reg_block                     m_reg_model;
    ahb_reg_adapter                   m_reg_adapter;
    uvm_reg_predictor #(ahb_seq_item) m_reg_predictor;
    fft_virtual_sequencer             m_virtual_sequencer;

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

        // Conditionally build Register Model, Adapter, and Explicit Predictor
        if (m_cfg.has_reg_model) begin
            m_reg_model = fft_reg_block::type_id::create("m_reg_model");
            m_reg_model.build();
            m_cfg.reg_model = m_reg_model;

            m_reg_adapter   = ahb_reg_adapter::type_id::create("m_reg_adapter");
            m_reg_predictor = uvm_reg_predictor#(ahb_seq_item)::type_id::create("m_reg_predictor", this);
        end

        // Build Virtual Sequencer
        m_virtual_sequencer = fft_virtual_sequencer::type_id::create("m_virtual_sequencer", this);
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
                m_sideband_agent.sb_agt_irq_ap.connect(m_scoreboard.irq_export);
                m_sideband_agent.sb_agt_dma_rx_ap.connect(m_scoreboard.dma_rx_export);
                m_sideband_agent.sb_agt_dma_tx_ap.connect(m_scoreboard.dma_tx_export);
            end
        end

        // Coverage connections
        if (m_cfg.has_coverage) begin
            if (m_cfg.has_ahb_agent) begin
                m_ahb_agent.ahb_agt_ap.connect(m_coverage.analysis_export);
            end
            if (m_cfg.has_sideband_agent) begin
                m_sideband_agent.sb_agt_irq_ap.connect(m_coverage.irq_export);
                m_sideband_agent.sb_agt_dma_rx_ap.connect(m_coverage.dma_rx_export);
                m_sideband_agent.sb_agt_dma_tx_ap.connect(m_coverage.dma_tx_export);
            end
        end

        // Register Model and Predictor connections
        if (m_cfg.has_reg_model) begin
            if (m_cfg.has_ahb_agent && m_cfg.is_active_ahb == UVM_ACTIVE) begin
                m_reg_model.ahb_map.set_sequencer(m_ahb_agent.ahb_sqr, m_reg_adapter);
            end
            m_reg_model.ahb_map.set_auto_predict(0);
            m_reg_predictor.map     = m_reg_model.ahb_map;
            m_reg_predictor.adapter = m_reg_adapter;
            if (m_cfg.has_ahb_agent) begin
                m_ahb_agent.ahb_agt_ap.connect(m_reg_predictor.bus_in);
            end
        end

        // Virtual Sequencer sub-sequencer connections
        if (m_cfg.has_ahb_agent) begin
            m_virtual_sequencer.ahb_sqr = m_ahb_agent.ahb_sqr;
        end
        if (m_cfg.has_sideband_agent) begin
            m_virtual_sequencer.sb_sqr = m_sideband_agent.sb_sqr;
        end
        if (m_cfg.has_reg_model) begin
            m_virtual_sequencer.reg_model = m_reg_model;
        end
    endfunction

endclass : fft_env

`endif // FFT_ENV_SVH
