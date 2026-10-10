// =============================================================================
// File Name      : fft_seq_pkg.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 2.0
// Description    : Package compiling all stimulus sequences for the FFT subsystem.
// =============================================================================

`ifndef FFT_SEQ_PKG_SV
`define FFT_SEQ_PKG_SV

package fft_seq_pkg;

    // ==================================================
    // Package Imports & Macros
    // ==================================================
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import ahb_types_pkg::*;
    import ahb_agent_pkg::*;
    import sideband_agent_pkg::*;
    import fft_reg_pkg::*;
    import fft_env_pkg::*;

    // ==================================================
    // Scenario Configuration
    // ==================================================
    `include "fft_scenario_cfg.svh"

    // ==================================================
    // Virtual Base Sequence
    // ==================================================
    `include "fft_base_vseq.svh"

    // ==================================================
    // Concrete Virtual Sequences
    // ==================================================
    `include "fft_single_frame_vseq.svh"
    `include "fft_burst_transfer_vseq.svh"
    `include "fft_multi_frame_vseq.svh"
    `include "fft_bus_protocol_error_vseq.svh"
    `include "fft_fifo_boundary_overflow_vseq.svh"
    `include "fft_dma_handshake_vseq.svh"
    `include "fft_control_reset_flush_vseq.svh"
    `include "fft_stress_vseq.svh"

endpackage : fft_seq_pkg

`endif // FFT_SEQ_PKG_SV
