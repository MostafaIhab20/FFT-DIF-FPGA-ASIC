// =============================================================================
// File Name      : ahb_sequencer.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Sequencer component for routing AHB-Lite sequence items.
// =============================================================================

`ifndef AHB_SEQUENCER_SVH
`define AHB_SEQUENCER_SVH

class ahb_sequencer extends uvm_sequencer #(ahb_seq_item);

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(ahb_sequencer)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "ahb_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass : ahb_sequencer

`endif // AHB_SEQUENCER_SVH
