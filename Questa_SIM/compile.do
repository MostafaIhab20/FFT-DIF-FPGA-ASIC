# =========================================================================
# QuestaSim Compilation Script for 32-Point DIF R2SDF FFT
# =========================================================================

# Create and map work library
if [file exists work] {
    vdel -lib work -all
}
vlib work
vmap work work

# Compile RTL SystemVerilog files in dependency order
vlog -sv -work work ../DESIGN/RTL/fft32_pkg.sv
vlog -sv -work work ../DESIGN/RTL/delay_feedback_line.sv
vlog -sv -work work ../DESIGN/RTL/butterfly_radix2.sv
vlog -sv -work work ../DESIGN/RTL/twiddle_rom.sv
vlog -sv -work work ../DESIGN/RTL/complex_multiplier.sv
vlog -sv -work work ../DESIGN/RTL/fft_stage.sv
vlog -sv -work work ../DESIGN/RTL/fft_controller.sv
vlog -sv -work work ../DESIGN/RTL/fft32_top.sv

# Compile Testbench
vlog -sv -work work ../DESIGN/TB/fft32_TB.sv

puts "--- COMPILATION COMPLETED SUCCESSFULLY ---"
