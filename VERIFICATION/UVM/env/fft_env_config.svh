// =============================================================================
// File Name      : fft_env_config.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-06
// Version        : 1.0
// Description    : Configuration object for the top-level FFT verification environment.
//                  Encapsulates virtual interfaces, agent active/passive modes,
//                  and enable switches for agents, scoreboard, and coverage.
// =============================================================================

`ifndef FFT_ENV_CONFIG_SVH
`define FFT_ENV_CONFIG_SVH

class fft_env_config extends uvm_object;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(fft_env_config)

    // ==================================================
    // Virtual Interface Handles
    // ==================================================
    virtual ahb_if      vif_ahb;
    virtual sideband_if vif_sb;

    // ==================================================
    // Agent Operating Modes
    // ==================================================
    uvm_active_passive_enum is_active_ahb = UVM_ACTIVE;
    uvm_active_passive_enum is_active_sb  = UVM_PASSIVE;

    // ==================================================
    // Subsystem Component Enable Switches
    // ==================================================
    bit has_ahb_agent      = 1'b1;
    bit has_sideband_agent = 1'b1;
    bit has_scoreboard     = 1'b1;
    bit has_coverage       = 1'b1;
    bit has_reg_model      = 1'b1;

    // ==================================================
    // Register Model Handle
    // ==================================================
    fft_reg_block reg_model;

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_env_config");
        super.new(name);
    endfunction

endclass : fft_env_config

`endif // FFT_ENV_CONFIG_SVH
