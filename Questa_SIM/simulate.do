# =========================================================================
# QuestaSim Simulation Script for 32-Point DIF R2SDF FFT
# =========================================================================

# 1. Compile Design and Testbench
do compile.do

# 2. Invoke Simulator with memory file plusargs
vsim -voptargs=+acc work.fft32_TB +STIM_FILE=../model/stimulus_in.mem +GOLDEN_FILE=../model/golden_out.mem

# 3. Load Waveform signals
if {[batch_mode]} {
    run -all
    quit -f
} else {
    do wave.do
    run -all
}
