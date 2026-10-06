// =============================================================================
// File Name      : sideband_agent_config.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Configuration object for the sideband monitor agent.
//                  Encapsulates virtual interface handle for top-level sidebands.
// =============================================================================

`ifndef SIDEBAND_AGENT_CONFIG_SVH
`define SIDEBAND_AGENT_CONFIG_SVH

class sideband_agent_config extends uvm_object;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(sideband_agent_config)

    // ==================================================
    // Configuration Parameters
    // ==================================================
    virtual sideband_if vif;

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "sideband_agent_config");
        super.new(name);
    endfunction

endclass : sideband_agent_config

`endif // SIDEBAND_AGENT_CONFIG_SVH
