// =============================================================================
// File Name      : fft_radix2_dif.hpp
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-06
// Version        : 1.0
// Description    : Header for bit-accurate 32-point Radix-2 Decimation-in-Frequency
//                  (DIF) fixed-point C++ reference model. Matches RTL pipeline,
//                  scaling, trivial twiddle bypasses, and natural output order.
// =============================================================================

#ifndef FFT_RADIX2_DIF_HPP
#define FFT_RADIX2_DIF_HPP

#include <cstdint>
#include <array>
#include <vector>

namespace fft {

    // ==================================================
    // Complex Fixed-Point Sample Structure
    // ==================================================
    struct Complex16 {
        int16_t re;
        int16_t im;

        constexpr Complex16() : re(0), im(0) {}
        constexpr Complex16(int16_t r, int16_t i) : re(r), im(i) {}
    };

    // ==================================================
    // Algorithmic & Hardware Parameters
    // ==================================================
    constexpr int FFT_N      = 32;
    constexpr int FFT_STAGES = 5;
    constexpr int SCALE      = 32768; // 2^15 for Q1.15
    constexpr int MIN_INT    = -32768;
    constexpr int MAX_INT    = 32767;

    // ==================================================
    // C++ Reference Model Class
    // ==================================================
    class FftRadix2Dif {
    public:
        // Precomputed Twiddle Factor ROM Tables (Q1.15)
        static const std::array<int16_t, 16> TW_RE;
        static const std::array<int16_t, 16> TW_IM;

        // Bit-reversal index mapping table (N=32)
        static const std::array<int, 32> BIT_REV_TABLE;

        // Core FFT Computation (C-style array interface)
        static void compute(
            const int16_t in_re[FFT_N],
            const int16_t in_im[FFT_N],
            int16_t       out_re[FFT_N],
            int16_t       out_im[FFT_N],
            bool          natural_order = true
        );

        // Core FFT Computation (C++ std::array interface)
        static void compute(
            const std::array<Complex16, FFT_N>& input,
            std::array<Complex16, FFT_N>&       output,
            bool                                natural_order = true
        );

        // Saturation helper clipping to signed 16-bit range [-32768, 32767]
        static inline int16_t sat_clip(int64_t val) {
            if (val > MAX_INT) return static_cast<int16_t>(MAX_INT);
            if (val < MIN_INT) return static_cast<int16_t>(MIN_INT);
            return static_cast<int16_t>(val);
        }

        // 5-bit index reversal
        static inline int bit_reverse_5(int idx) {
            int rev = 0;
            for (int i = 0; i < 5; i++) {
                if ((idx & (1 << i)) != 0) {
                    rev |= (1 << (4 - i));
                }
            }
            return rev;
        }

        // Hardware-accurate complex multiplication with twiddle bypasses
        static void complex_mult_hw(
            int16_t  xr, int16_t  xi,
            int16_t  wr, int16_t  wi,
            int      tw_k,
            int16_t& yr, int16_t& yi
        );
    };

} // namespace fft

#endif // FFT_RADIX2_DIF_HPP
