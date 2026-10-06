// =============================================================================
// File Name      : ahb_agent_pkg.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Package compiling all AHB-Lite agent classes and definitions.
// =============================================================================

`ifndef AHB_AGENT_PKG_SV
`define AHB_AGENT_PKG_SV

package ahb_agent_pkg;

    // ==================================================
    // Package Imports & Macros
    // ==================================================
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import ahb_types_pkg::*;

    // ==================================================
    // Component Includes
    // ==================================================
    `include "ahb_seq_item.svh"
    `include "ahb_agent_config.svh"
    `include "ahb_sequencer.svh"
    `include "ahb_driver.svh"
    `include "ahb_monitor.svh"
    `include "ahb_agent.svh"

endpackage : ahb_agent_pkg

`endif // AHB_AGENT_PKG_SV
