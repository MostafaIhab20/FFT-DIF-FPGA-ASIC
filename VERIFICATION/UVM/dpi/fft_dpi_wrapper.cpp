// =============================================================================
// File Name      : fft_dpi_wrapper.cpp
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-07
// Version        : 2.0
// Description    : SystemVerilog DPI-C interface wrapper exporting the
//                  handwritten C++ 32-point Radix-2 DIF reference model to UVM.
//                  Directly receives packed 32-bit complex words {re[15:0], im[15:0]}.
// =============================================================================

#include "svdpi.h"
#include "fft_radix2_dif.hpp"
#include <cstdint>

// ==================================================
// DPI-C Exported Function Interface
// ==================================================
extern "C" {

DPI_DLLESPEC void fft_radix2_dif_32(
    const uint32_t in_samples[32],
    uint32_t       out_samples[32]
) {
    int16_t in_re[32];
    int16_t in_im[32];
    int16_t out_re[32];
    int16_t out_im[32];

    // Unpack {re[31:16], im[15:0]}
    for (int i = 0; i < 32; i++) {
        in_re[i] = static_cast<int16_t>(in_samples[i] >> 16);
        in_im[i] = static_cast<int16_t>(in_samples[i] & 0xFFFF);
    }

    // Execute bit-accurate C++ Radix-2 DIF FFT
    fft::FftRadix2Dif::compute(in_re, in_im, out_re, out_im, true);

    // Pack into {re[31:16], im[15:0]}
    for (int i = 0; i < 32; i++) {
        out_samples[i] = (static_cast<uint32_t>(static_cast<uint16_t>(out_re[i])) << 16) |
                         (static_cast<uint32_t>(static_cast<uint16_t>(out_im[i])));
    }
}

} // extern "C"
