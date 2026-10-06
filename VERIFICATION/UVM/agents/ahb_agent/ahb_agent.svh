// =============================================================================
// File Name      : ahb_agent.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : UVC agent encapsulating AHB-Lite sequencer, driver,
//                  and monitor. Supports active master and passive monitor modes.
// =============================================================================

`ifndef AHB_AGENT_SVH
`define AHB_AGENT_SVH

class ahb_agent extends uvm_agent;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(ahb_agent)

    // ==================================================
    // Configuration & Component Handles
    // ==================================================
    ahb_sequencer                     ahb_sqr;
    ahb_driver                        ahb_drv;
    ahb_monitor                       ahb_mon;
    ahb_agent_config                  cfg;

    // ==================================================
    // TLM Ports
    // ==================================================
    uvm_analysis_port #(ahb_seq_item) ahb_agt_ap;

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "ahb_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ==================================================
    // UVM Build Phase
    // ==================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(ahb_agent_config)::get(this, "", "cfg", cfg)) begin
            `uvm_fatal("AHB_AGT", "Unable to get ahb_agent_config from uvm_config_db!")
        end

        // Build passive component
        uvm_config_db#(virtual ahb_if)::set(this, "ahb_mon", "vif", cfg.vif);
        ahb_mon = ahb_monitor::type_id::create("ahb_mon", this);
        ahb_agt_ap = new("ahb_agt_ap", this);

        // Build active components
        if (cfg.is_active == UVM_ACTIVE) begin
            uvm_config_db#(virtual ahb_if)::set(this, "*", "vif", cfg.vif);
            ahb_drv = ahb_driver::type_id::create("ahb_drv", this);
            ahb_sqr = ahb_sequencer::type_id::create("ahb_sqr", this);
        end

    endfunction

    // ==================================================
    // UVM Connect Phase
    // ==================================================
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (cfg.is_active == UVM_ACTIVE) begin
            ahb_drv.seq_item_port.connect(ahb_sqr.seq_item_export);
        end

        // Connect Passive Components
        ahb_mon.ahb_mon_ap.connect(ahb_agt_ap);
    endfunction

endclass : ahb_agent

`endif // AHB_AGENT_SVH
