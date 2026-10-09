// =============================================================================
// File Name      : sideband_agent_pkg.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Package compiling sideband agent components.
// =============================================================================

`ifndef SIDEBAND_AGENT_PKG_SV
`define SIDEBAND_AGENT_PKG_SV

package sideband_agent_pkg;

    // ==================================================
    // Package Imports & Macros
    // ==================================================
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // ==================================================
    // Component Includes
    // ==================================================
    `include "sideband_seq_item.svh"
    `include "sideband_agent_config.svh"
    `include "sideband_monitor.svh"
    `include "sideband_sequencer.svh"
    `include "sideband_agent.svh"
    `include "sideband_reactive_seqs.svh"

endpackage : sideband_agent_pkg

`endif // SIDEBAND_AGENT_PKG_SV
