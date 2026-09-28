// =============================================================================
// File Name      : fft_pkg.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-09-28
// Version        : 1.1
// Description    : Global SystemVerilog package defining architectural types,
//                  Q1.15 fixed-point complex data type, saturation boundaries,
//                  and FPGA/ASIC hardware target switches for parameterized FFT.
// =============================================================================

package fft_pkg;

    localparam int DATA_WIDTH = 16;

    // Platform Target Selection:
    // 0: ASIC (Custom Brent-Kung Adders & Radix-4 Booth Multipliers)
    // 1: FPGA (Inferred DSP48 hard slices & dedicated fast carry chains)
`ifdef TARGET_FPGA
    localparam bit TARGET_FPGA = 1'b1;
`else
    localparam bit TARGET_FPGA = 1'b0;
`endif

    // 16-bit Q1.15 Complex Data Type
    typedef struct packed {
        logic signed [DATA_WIDTH-1:0] re;
        logic signed [DATA_WIDTH-1:0] im;
    } complex_t;

    // Saturation Boundaries for 16-bit Signed Integers
    localparam logic signed [DATA_WIDTH-1:0] MAX_POS = 16'sh7FFF; // +32767
    localparam logic signed [DATA_WIDTH-1:0] MIN_NEG = 16'sh8000; // -32768

endpackage : fft_pkg
