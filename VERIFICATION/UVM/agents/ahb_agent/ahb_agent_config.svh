// =============================================================================
// File Name      : ahb_agent_config.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Configuration object for AHB-Lite UVC agent.
//                  Specifies virtual interface handle and active/passive mode.
// =============================================================================

`ifndef AHB_AGENT_CONFIG_SVH
`define AHB_AGENT_CONFIG_SVH

class ahb_agent_config extends uvm_object;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(ahb_agent_config)
    
    // ==================================================
    // Configuration Parameters
    // ==================================================
    uvm_active_passive_enum is_active = UVM_ACTIVE;
    virtual ahb_if          vif;

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "ahb_agent_config");
        super.new(name);
    endfunction

endclass : ahb_agent_config

`endif // AHB_AGENT_CONFIG_SVH
