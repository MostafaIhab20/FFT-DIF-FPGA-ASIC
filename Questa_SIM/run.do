# =========================================================================
# QuestaSim Master Simulation Script for Parameterized DIF R2SDF FFT Core
# Usage:
#   do run.do         (Defaults to N=32, MULT_PIPE_STAGES=0)
#   do run.do 32 0    (Runs 32-point FFT with 0 mult pipeline stages)
#   do run.do 32 1    (Runs 32-point FFT with 1 mult pipeline stage)
#   do run.do <N> <P> (Runs N-point FFT with P mult pipeline stages)
# =========================================================================

# 1. Close any running simulation and clean old libraries/logs
catch {quit -sim}
if [file exists work] {
    file delete -force work
}
if [file exists sim.log] {
    file delete -force sim.log
}

# 2. Determine target N and MULT_PIPE_STAGES
set N 32
if {$argc > 0} {
    set N $1
}
set MULT_PIPE_STAGES 0
if {$argc > 1} {
    set MULT_PIPE_STAGES $2
}

# 3. Create library and map work
vlib work   
vmap work work

# 4. Enable transcript logging to sim.log
transcript on
transcript file sim.log

# 5. Compile all SystemVerilog files using file lists
vlog -sv -work work -f incdir_list.txt -f verilog_list.txt

# 6. Start simulation with parameterized N and MULT_PIPE_STAGES
vsim -voptargs=+acc -gN=$N -gMULT_PIPE_STAGES=$MULT_PIPE_STAGES work.fft_TB

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