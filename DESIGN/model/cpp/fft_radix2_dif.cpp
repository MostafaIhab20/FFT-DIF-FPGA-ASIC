// =============================================================================
// File Name      : fft_radix2_dif.cpp
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-06
// Version        : 1.0
// Description    : Implementation of bit-accurate 32-point Radix-2 DIF fixed-point
//                  FFT reference model matching hardware RTL and twiddle ROM.
// =============================================================================

#include "fft_radix2_dif.hpp"

namespace fft {

    // ==================================================
    // Constant ROM Tables (Q1.15)
    // ==================================================
    const std::array<int16_t, 16> FftRadix2Dif::TW_RE = {
        0x7FFF, 0x7D8A, 0x7642, 0x6A6E,
        0x5A82, 0x471D, 0x30FC, 0x18F9,
        0x0000, static_cast<int16_t>(0xE707), static_cast<int16_t>(0xCF04), static_cast<int16_t>(0xB8E3),
        static_cast<int16_t>(0xA57E), static_cast<int16_t>(0x9592), static_cast<int16_t>(0x89BE), static_cast<int16_t>(0x8276)
    };

    const std::array<int16_t, 16> FftRadix2Dif::TW_IM = {
        0x0000, static_cast<int16_t>(0xE707), static_cast<int16_t>(0xCF04), static_cast<int16_t>(0xB8E3),
        static_cast<int16_t>(0xA57E), static_cast<int16_t>(0x9592), static_cast<int16_t>(0x89BE), static_cast<int16_t>(0x8276),
        static_cast<int16_t>(0x8000), static_cast<int16_t>(0x8276), static_cast<int16_t>(0x89BE), static_cast<int16_t>(0x9592),
        static_cast<int16_t>(0xA57E), static_cast<int16_t>(0xB8E3), static_cast<int16_t>(0xCF04), static_cast<int16_t>(0xE707)
    };

    const std::array<int, 32> FftRadix2Dif::BIT_REV_TABLE = {
         0, 16,  8, 24,  4, 20, 12, 28,
         2, 18, 10, 26,  6, 22, 14, 30,
         1, 17,  9, 25,  5, 21, 13, 29,
         3, 19, 11, 27,  7, 23, 15, 31
    };

    // ==================================================
    // Hardware-Accurate Complex Multiplier
    // ==================================================
    void FftRadix2Dif::complex_mult_hw(
        int16_t  xr, int16_t  xi,
        int16_t  wr, int16_t  wi,
        int      tw_k,
        int16_t& yr, int16_t& yi
    ) {
        // Trivial Twiddle Bypass 1: W^0 = 1 (Wire pass-through)
        if (tw_k == 0) {
            yr = xr;
            yi = xi;
            return;
        }

        // Trivial Twiddle Bypass 2: W^(N/4) = -j -> (xr + j*xi)(-j) = xi - j*xr
        if (tw_k == (FFT_N / 4)) {
            yr = xi;
            yi = sat_clip(-static_cast<int64_t>(xr));
            return;
        }

        // General Complex Multiplier (4 Real Multiplications)
        int64_t m1 = static_cast<int64_t>(xr) * wr;
        int64_t m2 = static_cast<int64_t>(xi) * wi;
        int64_t m3 = static_cast<int64_t>(xr) * wi;
        int64_t m4 = static_cast<int64_t>(xi) * wr;

        int64_t prod_r = m1 - m2;
        int64_t prod_i = m3 + m4;

        // Round-Half-Up scaling: (+2^14 before arithmetic right-shift by 15)
        int64_t rnd_r = (prod_r + 16384) >> 15;
        int64_t rnd_i = (prod_i + 16384) >> 15;

        yr = sat_clip(rnd_r);
        yi = sat_clip(rnd_i);
    }

    // ==================================================
    // Core FFT Computation (Array Interface)
    // ==================================================
    void FftRadix2Dif::compute(
        const int16_t in_re[FFT_N],
        const int16_t in_im[FFT_N],
        int16_t       out_re[FFT_N],
        int16_t       out_im[FFT_N],
        bool          natural_order
    ) {
        int16_t data_re[FFT_N];
        int16_t data_im[FFT_N];

        for (int i = 0; i < FFT_N; i++) {
            data_re[i] = in_re[i];
            data_im[i] = in_im[i];
        }

        // 5-Stage Radix-2 Decimation-in-Frequency Pipeline
        for (int s = 1; s <= FFT_STAGES; s++) {
            int len     = FFT_N / (1 << s);
            int stride  = 2 * len;
            int tw_step = FFT_N / stride;

            for (int start = 0; start < FFT_N; start += stride) {
                for (int k = 0; k < len; k++) {
                    int idx_a = start + k;
                    int idx_b = start + k + len;

                    int16_t ar = data_re[idx_a];
                    int16_t ai = data_im[idx_a];
                    int16_t br = data_re[idx_b];
                    int16_t bi = data_im[idx_b];

                    // Butterfly Add and Subtract with Round-Half-Up division by 2
                    int32_t s_re = (static_cast<int32_t>(ar) + br + 1) >> 1;
                    int32_t s_im = (static_cast<int32_t>(ai) + bi + 1) >> 1;
                    int32_t d_re = (static_cast<int32_t>(ar) - br + 1) >> 1;
                    int32_t d_im = (static_cast<int32_t>(ai) - bi + 1) >> 1;

                    int16_t sum_re  = sat_clip(s_re);
                    int16_t sum_im  = sat_clip(s_im);
                    int16_t diff_re = sat_clip(d_re);
                    int16_t diff_im = sat_clip(d_im);

                    // Twiddle factor lookup
                    int tw_k = k * tw_step;
                    int16_t wr = TW_RE[tw_k];
                    int16_t wi = TW_IM[tw_k];

                    // Complex multiplication on difference path
                    int16_t prod_re;
                    int16_t prod_im;
                    complex_mult_hw(diff_re, diff_im, wr, wi, tw_k, prod_re, prod_im);

                    // In-place update
                    data_re[idx_a] = sum_re;
                    data_im[idx_a] = sum_im;
                    data_re[idx_b] = prod_re;
                    data_im[idx_b] = prod_im;
                }
            }
        }

        // Output Reordering
        if (natural_order) {
            for (int i = 0; i < FFT_N; i++) {
                int nat_idx = BIT_REV_TABLE[i];
                out_re[nat_idx] = data_re[i];
                out_im[nat_idx] = data_im[i];
            }
        } else {
            for (int i = 0; i < FFT_N; i++) {
                out_re[i] = data_re[i];
                out_im[i] = data_im[i];
            }
        }
    }

    // ==================================================
    // Core FFT Computation (std::array Interface)
    // ==================================================
    void FftRadix2Dif::compute(
        const std::array<Complex16, FFT_N>& input,
        std::array<Complex16, FFT_N>&       output,
        bool                                natural_order
    ) {
        int16_t in_re[FFT_N];
        int16_t in_im[FFT_N];
        int16_t out_re[FFT_N];
        int16_t out_im[FFT_N];

        for (int i = 0; i < FFT_N; i++) {
            in_re[i] = input[i].re;
            in_im[i] = input[i].im;
        }

        compute(in_re, in_im, out_re, out_im, natural_order);

        for (int i = 0; i < FFT_N; i++) {
            output[i].re = out_re[i];
            output[i].im = out_im[i];
        }
    }

} // namespace fft
