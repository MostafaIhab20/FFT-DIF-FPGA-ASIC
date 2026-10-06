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
    sideband_agent_config                   cfg;

    // ==================================================
    // TLM Ports
    // ==================================================
    uvm_analysis_port #(sideband_seq_item) sb_agt_ap;

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

        // Build passive monitor component
        uvm_config_db#(virtual sideband_if)::set(this, "sb_mon", "vif", cfg.vif);
        sb_mon = sideband_monitor::type_id::create("sb_mon", this);
        sb_agt_ap = new("sb_agt_ap", this);
    endfunction

    // ==================================================
    // UVM Connect Phase
    // ==================================================
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect Passive Components
        sb_mon.sb_mon_ap.connect(sb_agt_ap);
    endfunction

endclass : sideband_agent

`endif // SIDEBAND_AGENT_SVH
