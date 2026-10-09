// =============================================================================
// File Name      : fft_seq_pkg.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
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
    // Sequence Includes
    // ==================================================
    `include "fft_scenario_cfg.svh"
    `include "fft_base_vseq.svh"
    `include "fft_sanity_seq.svh"
    `include "fft_burst_seq.svh"
    `include "fft_multi_frame_seq.svh"
    `include "fft_bus_error_seq.svh"
    `include "fft_fifo_boundary_seq.svh"
    `include "fft_dma_handshake_seq.svh"
    `include "fft_reset_flush_seq.svh"
    `include "fft_coverage_closure_seq.svh"

endpackage : fft_seq_pkg

`endif // FFT_SEQ_PKG_SV
