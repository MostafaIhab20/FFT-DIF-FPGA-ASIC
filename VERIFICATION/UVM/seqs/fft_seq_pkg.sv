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

    // ==================================================
    // Sequence Includes
    // ==================================================
    `include "fft_base_seq.svh"
    `include "fft_sanity_seq.svh"
    `include "fft_burst_seq.svh"

endpackage : fft_seq_pkg

`endif // FFT_SEQ_PKG_SV
