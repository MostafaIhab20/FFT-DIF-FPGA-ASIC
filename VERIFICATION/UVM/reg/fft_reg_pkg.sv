// =============================================================================
// File Name      : fft_reg_pkg.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-06
// Version        : 1.0
// Description    : Register package encapsulating AHB register adapter and
//                  Register Abstraction Layer (RAL) model for the FFT subsystem.
// =============================================================================

`ifndef FFT_REG_PKG_SV
`define FFT_REG_PKG_SV

package fft_reg_pkg;

    // ==================================================
    // Package Imports & Macros
    // ==================================================
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import ahb_types_pkg::*;
    import ahb_agent_pkg::*;

    // ==================================================
    // Component Includes
    // ==================================================
    `include "ahb_reg_adapter.svh"
    `include "fft_reg_block.svh"

endpackage : fft_reg_pkg

`endif // FFT_REG_PKG_SV
