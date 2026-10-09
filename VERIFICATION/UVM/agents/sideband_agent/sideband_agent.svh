// =============================================================================
// File Name      : sideband_agent.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Passive agent encapsulating the sideband monitor.
//                  Monitors interrupt and DMA handshake events from the DUT.
// =============================================================================

`ifndef SIDEBAND_AGENT_SVH
`define SIDEBAND_AGENT_SVH

class sideband_agent extends uvm_agent;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(sideband_agent)

    // ==================================================
    // Configuration & Component Handles
    // ==================================================
    sideband_monitor                        sb_mon;
    sideband_sequencer                      sb_sqr;
    sideband_agent_config                   cfg;

    // ==================================================
    // TLM Ports
    // ==================================================
    uvm_analysis_port #(sideband_seq_item) sb_agt_irq_ap;
    uvm_analysis_port #(sideband_seq_item) sb_agt_dma_rx_ap;
    uvm_analysis_port #(sideband_seq_item) sb_agt_dma_tx_ap;

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "sideband_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ==================================================
    // UVM Build Phase
    // ==================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(sideband_agent_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("SB_AGT", "Unable to get sideband_agent_config from uvm_config_db!")
        end

        // Build monitor and reactive sequencer components
        uvm_config_db#(virtual sideband_if)::set(this, "sb_mon", "vif", cfg.vif);
        sb_mon = sideband_monitor::type_id::create("sb_mon", this);
        sb_sqr = sideband_sequencer::type_id::create("sb_sqr", this);
        sb_agt_irq_ap = new("sb_agt_irq_ap", this);
        sb_agt_dma_rx_ap = new("sb_agt_dma_rx_ap", this);
        sb_agt_dma_tx_ap = new("sb_agt_dma_tx_ap", this);
    endfunction

    // ==================================================
    // UVM Connect Phase
    // ==================================================
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect monitor to reactive sequencer export and agent analysis port
        sb_mon.sb_mon_irq_ap.connect(sb_sqr.sb_irq_export);
        sb_mon.sb_mon_dma_rx_ap.connect(sb_sqr.sb_dma_rx_export);
        sb_mon.sb_mon_dma_tx_ap.connect(sb_sqr.sb_dma_tx_export);

        // Connect monitor to agt analysis ports for scoreboard 
        sb_mon.sb_mon_irq_ap.connect(sb_agt_irq_ap);
        sb_mon.sb_mon_dma_rx_ap.connect(sb_agt_dma_rx_ap);
        sb_mon.sb_mon_dma_tx_ap.connect(sb_agt_dma_tx_ap);
    endfunction

endclass : sideband_agent

`endif // SIDEBAND_AGENT_SVH
