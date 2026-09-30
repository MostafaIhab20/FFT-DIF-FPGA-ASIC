# =============================================================================
# File Name      : add_files.tcl
# Author         : Mostafa Ihab
# Creation Date  : 2026-09-28
# Version        : 1.0
# Description    : Vivado synthesis file loader script for Parameterized
#                  Radix-2 DIF R2SDF FFT core.
# =============================================================================

set script_dir [file normalize [file dirname [info script]]]
set rtl_dir    [file normalize [file join $script_dir "../DESIGN/RTL"]]

# Add all synthesizable RTL files
add_files [list \
    [file join $rtl_dir "fft_pkg.sv"] \
    [file join $rtl_dir "adder_subtractor_bk.sv"] \
    [file join $rtl_dir "booth_radix4_multiplier.sv"] \
    [file join $rtl_dir "butterfly_radix2.sv"] \
    [file join $rtl_dir "complex_multiplier.sv"] \
    [file join $rtl_dir "delay_feedback_line.sv"] \
    [file join $rtl_dir "fft_controller.sv"] \
    [file join $rtl_dir "fft_stage.sv"] \
    [file join $rtl_dir "twiddle_rom.sv"] \
    [file join $rtl_dir "fft_top.sv"] \
]

# Set parameterized top module and update compile order
set_property top fft_top [current_fileset]
update_compile_order -fileset sources_1
