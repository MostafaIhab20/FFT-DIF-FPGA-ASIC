// =============================================================================
// File Name      : fft_test_pkg.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Package compiling test library for the FFT subsystem.
// =============================================================================

`ifndef FFT_TEST_PKG_SV
`define FFT_TEST_PKG_SV

package fft_test_pkg;

    // ==================================================
    // Package Imports & Macros
    // ==================================================
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import ahb_types_pkg::*;
    import ahb_agent_pkg::*;
    import sideband_agent_pkg::*;
    import fft_env_pkg::*;
    import fft_seq_pkg::*;

    // ==================================================
    // Test Includes
    // ==================================================
    `include "fft_base_test.svh"
    `include "fft_sanity_test.svh"

endpackage : fft_test_pkg

`endif // FFT_TEST_PKG_SV
