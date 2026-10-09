// =============================================================================
// File Name      : fft_virtual_sequencer.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-09
// Version        : 1.0
// Description    : Virtual sequencer coordinating the AHB sequencer,
//                  reactive sideband sequencer, and register model.
// =============================================================================

`ifndef FFT_VIRTUAL_SEQUENCER_SVH
`define FFT_VIRTUAL_SEQUENCER_SVH

class fft_virtual_sequencer extends uvm_sequencer;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(fft_virtual_sequencer)

    // ==================================================
    // Sub-sequencer & RAL Handles
    // ==================================================
    ahb_sequencer       ahb_sqr;
    sideband_sequencer  sb_sqr;
    fft_reg_block       reg_model;

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_virtual_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass : fft_virtual_sequencer

`endif // FFT_VIRTUAL_SEQUENCER_SVH
