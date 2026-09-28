# =========================================================================
# QuestaSim Master Simulation Script for 32-Point DIF R2SDF FFT Core
# Usage inside QuestaSim: do run.do
# =========================================================================

# 1. Close any running simulation and clean old libraries/logs
catch {quit -sim}
if [file exists work] {
    file delete -force work
}
if [file exists sim.log] {
    file delete -force sim.log
}

# 2. Create library and map work
vlib work   
vmap work work

# 3. Enable transcript logging to sim.log
transcript on
transcript file sim.log

# 4. Compile all SystemVerilog files using file lists
vlog -sv -work work -f incdir_list.txt -f verilog_list.txt

# 5. Start simulation with memory file plusargs
vsim -voptargs=+acc work.fft32_TB +STIM_FILE=../model/stimulus_in.mem +GOLDEN_FILE=../model/golden_out.mem

# 6. Add waveforms (in GUI mode) and run
if {[batch_mode]} {
    run -all
    quit -f
} else {
    do wave.do
    run -all
}