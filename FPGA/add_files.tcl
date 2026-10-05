# =============================================================================
# File Name      : add_files.tcl
# Author         : Mostafa Ihab
# Creation Date  : 2026-10-01
# Version        : 1.0
# Description    : Vivado synthesis file loader script for the complete
#                  AHB-Lite FFT Subsystem (top_wrapper). Loads all packages,
#                  core math/control modules, FIFOs, synchronizers, register
#                  file, AHB slave, and top-level wrapper.
# =============================================================================

# =============================================================================
# 1. Base Directory Setup
# =============================================================================
set script_dir [file normalize [file dirname [info script]]]
set rtl_dir    [file normalize [file join $script_dir "../DESIGN/RTL"]]

# =============================================================================
# 2. Add Synthesizable RTL Modules by Subsystem
# =============================================================================

# -----------------------------------------------------------------------------
# 2.1 Core FFT Pipelined Processing Elements & Controller
# -----------------------------------------------------------------------------
add_files [list \
    [file join $rtl_dir "FFT_CORE/fft_pkg.sv"] \
    [file join $rtl_dir "FFT_CORE/adder_subtractor_bk.sv"] \
    [file join $rtl_dir "FFT_CORE/booth_radix4_multiplier.sv"] \
    [file join $rtl_dir "FFT_CORE/delay_feedback_line.sv"] \
    [file join $rtl_dir "FFT_CORE/butterfly_radix2.sv"] \
    [file join $rtl_dir "FFT_CORE/twiddle_rom.sv"] \
    [file join $rtl_dir "FFT_CORE/complex_multiplier.sv"] \
    [file join $rtl_dir "FFT_CORE/fft_stage.sv"] \
    [file join $rtl_dir "FFT_CORE/fft_controller.sv"] \
    [file join $rtl_dir "FFT_CORE/fft_top.sv"] \
    [file join $rtl_dir "FFT_CORE/fft_reorder_buffer.sv"] \
]

# -----------------------------------------------------------------------------
# 2.2 Dual-Clock Asynchronous FIFO
# -----------------------------------------------------------------------------
add_files [list \
    [file join $rtl_dir "ASYC_FIFO/async_fifo.sv"] \
]

# -----------------------------------------------------------------------------
# 2.3 Clock Domain Crossing (CDC) Synchronizers & System Control
# -----------------------------------------------------------------------------
add_files [list \
    [file join $rtl_dir "CTRL/addr_decoder.sv"] \
    [file join $rtl_dir "CTRL/bit_sync.sv"] \
    [file join $rtl_dir "CTRL/reset_sync.sv"] \
    [file join $rtl_dir "CTRL/pulse_sync.sv"] \
    [file join $rtl_dir "CTRL/rst_ctrl.sv"] \
    [file join $rtl_dir "CTRL/fft_sys_ctrl.sv"] \
]

# -----------------------------------------------------------------------------
# 2.4 Register File & Memory-Mapped Package
# -----------------------------------------------------------------------------
add_files [list \
    [file join $rtl_dir "REG_FILE/ip_regs_pkg.sv"] \
    [file join $rtl_dir "REG_FILE/fft_rf.sv"] \
]

# -----------------------------------------------------------------------------
# 2.5 AHB-Lite Bus Slave Interface
# -----------------------------------------------------------------------------
add_files [list \
    [file join $rtl_dir "SLAVE/fft_slave.sv"] \
]

# -----------------------------------------------------------------------------
# 2.6 Top-Level Subsystem Wrapper
# -----------------------------------------------------------------------------
add_files [list \
    [file join $rtl_dir "top_wrapper.sv"] \
]

# =============================================================================
# 3. Configure Top-Level Module & Compile Order
# =============================================================================
set_property top top_wrapper [current_fileset]
update_compile_order -fileset sources_1
