// =============================================================================
// File Name      : main.cpp
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-06
// Version        : 1.0
// Description    : Standalone verification testbench for the 32-point Radix-2 DIF
//                  C++ reference model. Validates DC, impulse, and multi-tone test cases.
// =============================================================================

#define _USE_MATH_DEFINES
#include <iostream>
#include <iomanip>
#include <cmath>
#include <cassert>
#include "fft_radix2_dif.hpp"

using namespace fft;

constexpr double PI = 3.14159265358979323846;

// ==================================================
// Verification Helper
// ==================================================
[[maybe_unused]] static void print_frame(const std::string& name, const std::array<Complex16, FFT_N>& frame) {
    std::cout << "--- " << name << " ---" << std::endl;
    for (int i = 0; i < FFT_N; i++) {
        std::cout << "  Bin[" << std::setw(2) << i << "]: "
                  << "Re=" << std::setw(6) << frame[i].re
                  << " | Im=" << std::setw(6) << frame[i].im << std::endl;
    }
}

// ==================================================
// Test Cases
// ==================================================
// Test DC constant signal
static bool test_dc_signal() {
    std::cout << "[TEST] Running DC constant signal test..." << std::endl;

    std::array<Complex16, FFT_N> in{};
    std::array<Complex16, FFT_N> out{};

    // Constant DC value: Re = 16384, Im = 0
    for (int i = 0; i < FFT_N; i++) {
        in[i].re = 16384;
        in[i].im = 0;
    }

    FftRadix2Dif::compute(in, out, true);

    // In a scaled DIF FFT, DC bin (bin 0) collects the energy:
    // With 5 stages of /2, sum of 32 identical inputs scaled by (1/2)^5 = 1.0 * in
    bool pass = true;
    if (out[0].re != 16384 || out[0].im != 0) {
        std::cerr << "[FAIL] DC bin mismatch: expected (16384, 0), got ("
                  << out[0].re << ", " << out[0].im << ")" << std::endl;
        pass = false;
    }

    for (int i = 1; i < FFT_N; i++) {
        if (out[i].re != 0 || out[i].im != 0) {
            std::cerr << "[FAIL] Non-DC bin[" << i << "] is non-zero: ("
                      << out[i].re << ", " << out[i].im << ")" << std::endl;
            pass = false;
        }
    }

    if (pass) {
        std::cout << "[PASS] DC constant signal test passed successfully." << std::endl;
    }
    return pass;
}

// Test unit impulse signal (delta at n=0)
static bool test_unit_impulse() {
    std::cout << "[TEST] Running unit impulse test..." << std::endl;

    std::array<Complex16, FFT_N> in{};
    std::array<Complex16, FFT_N> out{};

    // Delta at n=0: Re = 32767, Im = 0
    in[0].re = 32767;
    in[0].im = 0;

    FftRadix2Dif::compute(in, out, true);

    // Flat spectrum: each bin receives 32767 / 32 = 1024 (with round-half-up)
    bool pass = true;
    for (int i = 0; i < FFT_N; i++) {
        int diff = std::abs(out[i].re - 1024);
        if (diff > 1 || std::abs(out[i].im) > 1) {
            std::cerr << "[FAIL] Flat bin[" << i << "] deviation: got ("
                      << out[i].re << ", " << out[i].im << ")" << std::endl;
            pass = false;
        }
    }

    if (pass) {
        std::cout << "[PASS] Unit impulse test passed successfully." << std::endl;
    }
    return pass;
}

// Test single pure tone
static bool test_single_tone() {
    std::cout << "[TEST] Running single tone test (f0 = 4)..." << std::endl;

    std::array<Complex16, FFT_N> in{};
    std::array<Complex16, FFT_N> out{};

    int f0 = 4;
    double amp = 24000.0;
    for (int n = 0; n < FFT_N; n++) {
        double theta = 2.0 * PI * f0 * n / FFT_N;
        in[n].re = static_cast<int16_t>(std::round(amp * std::cos(theta)));
        in[n].im = static_cast<int16_t>(std::round(amp * std::sin(theta)));
    }

    FftRadix2Dif::compute(in, out, true);

    // Peak energy should reside at bin f0 = 4
    int peak_bin = 0;
    int max_mag = 0;
    for (int i = 0; i < FFT_N; i++) {
        int mag = static_cast<int>(std::sqrt(out[i].re * out[i].re + out[i].im * out[i].im));
        if (mag > max_mag) {
            max_mag = mag;
            peak_bin = i;
        }
    }

    bool pass = (peak_bin == f0);
    if (pass) {
        std::cout << "[PASS] Single tone peak detected at expected bin " << peak_bin << "." << std::endl;
    } else {
        std::cerr << "[FAIL] Single tone peak at bin " << peak_bin << " (expected " << f0 << ")" << std::endl;
    }
    return pass;
}

// ==================================================
// Main Execution
// ==================================================
int main() {
    std::cout << "==================================================" << std::endl;
    std::cout << "   32-Point Radix-2 DIF FFT C++ Model Verification" << std::endl;
    std::cout << "==================================================" << std::endl;

    bool all_passed = true;
    all_passed &= test_dc_signal();
    all_passed &= test_unit_impulse();
    all_passed &= test_single_tone();

    std::cout << "==================================================" << std::endl;
    if (all_passed) {
        std::cout << "   ALL TESTS PASSED: 100% SUCCESS" << std::endl;
    } else {
        std::cout << "   VERIFICATION FAILED: See errors above" << std::endl;
    }
    std::cout << "==================================================" << std::endl;

    return all_passed ? 0 : 1;
}
