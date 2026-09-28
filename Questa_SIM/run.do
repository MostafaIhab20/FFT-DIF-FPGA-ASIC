# =========================================================================
# QuestaSim Master Simulation Script for Parameterized DIF R2SDF FFT Core
# Usage:
#   do run.do       (Defaults to N=32)
#   do run.do 32    (Runs 32-point FFT)
#   do run.do 64    (Runs 64-point FFT)
#   do run.do <N>   (Runs N-point FFT)
# =========================================================================

# 1. Close any running simulation and clean old libraries/logs
catch {quit -sim}
if [file exists work] {
    file delete -force work
}
if [file exists sim.log] {
    file delete -force sim.log
}

# 2. Determine target N (defaults to 32 if no argument passed)
set N 32
if {$argc > 0} {
    set N $1
}

# 3. Create library and map work
vlib work   
vmap work work

# 4. Enable transcript logging to sim.log
transcript on
transcript file sim.log

# 5. Compile all SystemVerilog files using file lists
vlog -sv -work work -f incdir_list.txt -f verilog_list.txt

# 6. Start simulation with parameterized N
vsim -voptargs=+acc -gN=$N work.fft_TB

# 7. Run simulation (batch exits cleanly, GUI opens waveforms)
if {[batch_mode]} {
    run -all
    quit -f
} else {
    if [file exists wave.do] {
        do wave.do
    }
    run -all
}