# =============================================================================
# File Name      : run_uvm.do
# Author         : Mostafa Ihab
# Creation Date  : 2026-10-05
# Version        : 1.0
# Description    : Master QuestaSim simulation script for UVM verification.
#                  Compiles RTL, UVM packages, interfaces, top module,
#                  and runs tests with full logging and coverage.
# =============================================================================

# Close any active simulation
catch {quit -sim}

# Set root paths
set RTL_ROOT "../../DESIGN/RTL"
set UVM_ROOT "../UVM"
set QUESTA_UVM "C:/questasim64_2021.1/verilog_src/uvm-1.2/src"
set UVM_DPI   "C:/questasim64_2021.1/uvm-1.2/win64/uvm_dpi"

# Parse target test name from argument (default: fft_sanity_test)
set TEST_NAME "fft_sanity_test"
if {$argc > 0} {
    set TEST_NAME $1
}

# Create fresh work library
if [file exists work] {
    file delete -force work
}
vlib work
vmap work work

# Compile RTL design files
vlog -sv -work work \
    $RTL_ROOT/FFT_CORE/fft_pkg.sv \
    $RTL_ROOT/FFT_CORE/adder_subtractor_bk.sv \
    $RTL_ROOT/FFT_CORE/booth_radix4_multiplier.sv \
    $RTL_ROOT/FFT_CORE/delay_feedback_line.sv \
    $RTL_ROOT/FFT_CORE/butterfly_radix2.sv \
    $RTL_ROOT/FFT_CORE/twiddle_rom.sv \
    $RTL_ROOT/FFT_CORE/complex_multiplier.sv \
    $RTL_ROOT/FFT_CORE/fft_stage.sv \
    $RTL_ROOT/FFT_CORE/fft_controller.sv \
    $RTL_ROOT/FFT_CORE/fft_top.sv \
    $RTL_ROOT/FFT_CORE/fft_reorder_buffer.sv \
    $RTL_ROOT/REG_FILE/ip_regs_pkg.sv \
    $RTL_ROOT/ASYC_FIFO/async_fifo.sv \
    $RTL_ROOT/CTRL/addr_decoder.sv \
    $RTL_ROOT/CTRL/bit_sync.sv \
    $RTL_ROOT/CTRL/reset_sync.sv \
    $RTL_ROOT/CTRL/pulse_sync.sv \
    $RTL_ROOT/CTRL/rst_ctrl.sv \
    $RTL_ROOT/CTRL/fft_sys_ctrl.sv \
    $RTL_ROOT/REG_FILE/fft_rf.sv \
    $RTL_ROOT/SLAVE/fft_slave.sv \
    $RTL_ROOT/top_wrapper.sv

# Compile UVM package and DPI
vlog -sv -work work +incdir+$QUESTA_UVM $QUESTA_UVM/uvm_pkg.sv

# Compile interfaces
vlog -sv -work work \
    $UVM_ROOT/agents/ahb_agent/ahb_if.sv \
    $UVM_ROOT/agents/sideband_agent/sideband_if.sv

# Compile agent packages
vlog -sv -work work \
    +incdir+$QUESTA_UVM \
    +incdir+$UVM_ROOT/agents/ahb_agent \
    $UVM_ROOT/agents/ahb_agent/ahb_types_pkg.sv \
    $UVM_ROOT/agents/ahb_agent/ahb_agent_pkg.sv

vlog -sv -work work \
    +incdir+$QUESTA_UVM \
    +incdir+$UVM_ROOT/agents/sideband_agent \
    $UVM_ROOT/agents/sideband_agent/sideband_agent_pkg.sv

# Compile environment package
vlog -sv -work work \
    +incdir+$QUESTA_UVM \
    +incdir+$UVM_ROOT/agents/ahb_agent \
    +incdir+$UVM_ROOT/agents/sideband_agent \
    +incdir+$UVM_ROOT/env \
    $UVM_ROOT/env/fft_env_pkg.sv

# Compile sequences package
vlog -sv -work work \
    +incdir+$QUESTA_UVM \
    +incdir+$UVM_ROOT/agents/ahb_agent \
    +incdir+$UVM_ROOT/seqs \
    $UVM_ROOT/seqs/fft_seq_pkg.sv

# Compile tests package
vlog -sv -work work \
    +incdir+$QUESTA_UVM \
    +incdir+$UVM_ROOT/agents/ahb_agent \
    +incdir+$UVM_ROOT/agents/sideband_agent \
    +incdir+$UVM_ROOT/env \
    +incdir+$UVM_ROOT/seqs \
    +incdir+$UVM_ROOT/tests \
    $UVM_ROOT/tests/fft_test_pkg.sv

# Compile top-level module
vlog -sv -work work \
    +incdir+$QUESTA_UVM \
    +incdir+$UVM_ROOT/agents/ahb_agent \
    +incdir+$UVM_ROOT/agents/sideband_agent \
    +incdir+$UVM_ROOT/env \
    +incdir+$UVM_ROOT/seqs \
    +incdir+$UVM_ROOT/tests \
    $UVM_ROOT/fft_top_uvm.sv

# Run simulation
vsim -c -t 1ps -suppress 3009,8785 -sv_lib $UVM_DPI +UVM_TESTNAME=$TEST_NAME work.tb_top_uvm -do "run -all; quit -f"
