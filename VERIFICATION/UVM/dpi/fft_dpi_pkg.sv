// =============================================================================
// File Name      : fft_dpi_pkg.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-06
// Version        : 2.0 
// Description    : Package declaring DPI-C foreign function imports for the
//                  handwritten C++ 32-point DIF FFT reference model.
// =============================================================================

`ifndef FFT_DPI_PKG_SV
`define FFT_DPI_PKG_SV

package fft_dpi_pkg;

    // ==================================================
    // DPI-C Foreign Function Import
    // ==================================================
    // Direct call with pure attribute (no simulation context switch overhead)
    import "DPI-C" pure function void fft_radix2_dif_32(
        input  int in_samples[32],
        output int out_samples[32]
    );

endpackage : fft_dpi_pkg

`endif // FFT_DPI_PKG_SV
