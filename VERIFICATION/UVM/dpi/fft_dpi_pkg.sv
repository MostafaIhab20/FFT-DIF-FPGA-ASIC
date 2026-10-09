// =============================================================================
// File Name      : fft_dpi_pkg.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-06
// Version        : 2.0 (Direct 32-bit Packed Pure DPI-C Interface)
// Description    : Package declaring DPI-C foreign function imports for the
//                  handwritten C++ 32-point DIF FFT reference model.
// =============================================================================

`ifndef FFT_DPI_PKG_SV
`define FFT_DPI_PKG_SV

package fft_dpi_pkg;

    // ==================================================
    // Package Imports & Macros
    // ==================================================
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // ==================================================
    // DPI-C Foreign Function Import
    // ==================================================
    // Direct call with pure attribute (no simulation context switch overhead)
    import "DPI-C" pure function void fft_radix2_dif_32(
        input  int in_samples[32],
        output int out_samples[32]
    );

    // ==================================================
    // Helper Function
    // ==================================================
    // Type-compatibility wrapper for logic [31:0] arrays
    function automatic void compute_fft_dpi_32(
        input  logic [31:0] in_samples[32],
        output logic [31:0] out_samples[32]
    );
        int in_i[32];
        int out_i[32];

        for (int i = 0; i < 32; i++) begin
            in_i[i] = int'(in_samples[i]);
        end

        fft_radix2_dif_32(in_i, out_i);

        for (int i = 0; i < 32; i++) begin
            out_samples[i] = out_i[i];
        end
    endfunction

endpackage : fft_dpi_pkg

`endif // FFT_DPI_PKG_SV
