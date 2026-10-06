// =============================================================================
// File Name      : fft_env_pkg.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Package compiling reference model, scoreboard, coverage,
//                  and environment components.
// =============================================================================

`ifndef FFT_ENV_PKG_SV
`define FFT_ENV_PKG_SV

package fft_env_pkg;

    // ==================================================
    // Package Imports & Macros
    // ==================================================
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import ahb_types_pkg::*;
    import ahb_agent_pkg::*;
    import sideband_agent_pkg::*;

    // ==================================================
    // Component Includes
    // ==================================================
    `include "fft_env_config.svh"
    `include "fft_golden_model.svh"
    `include "fft_scoreboard.svh"
    `include "fft_coverage.svh"
    `include "fft_env.svh"

endpackage : fft_env_pkg

`endif // FFT_ENV_PKG_SV
