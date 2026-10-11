# =============================================================================
# File Name      : run.do
# Author         : Mostafa Ihab
# Creation Date  : 2026-10-01
# Version        : 2.0
# Description    : Master QuestaSim simulation script for standalone module TBs.
#                  Compiles the design using verilog_list.txt and launches target TB.
# Usage:
#   do run.do             (Runs top_wrapper system testbench: tb_top)
#   do run.do top         (Runs top_wrapper system testbench: tb_top)
#   do run.do slave       (Runs AHB-Lite slave testbench: tb_ahb_slave)
#   do run.do fifo        (Runs asynchronous FIFO testbench: tb_async_fifo)
#   do run.do fft [N] [P] (Runs FFT core testbench: fft_TB, default N=32, P=0)
# =============================================================================

# 1. Close active simulation and clean previous run artifacts
catch {quit -sim}

if [file exists sim.log] {
    file delete -force sim.log
}

# 2. Parse target testbench from argument 1 (defaults to "top")
set TARGET "top"
if {$argc > 0} {
    set TARGET [string tolower $1]
}

# 3. Create clean work library
if [file exists work] {
    file delete -force work
}
vlib work
vmap work work

# 4. Enable transcript logging
transcript on
transcript file sim.log

# 5. Compile all design and testbench files from read list
if {[file exists incdir_list.txt] && [file size incdir_list.txt] > 0} {
    vlog -sv -work work -f incdir_list.txt -f verilog_list.txt
} else {
    vlog -sv -work work -f verilog_list.txt
}

# 6. Configure simulation targets and generics
set VSIM_FLAGS "-voptargs=+acc"

switch -- $TARGET {
    "top" {
        set TOP_MODULE "work.tb_top"
        set WAVE_FILE  "waves/wave_top.do"
        set SIM_CMD    "vsim $VSIM_FLAGS $TOP_MODULE"
    }
    "slave" {
        set TOP_MODULE "work.tb_ahb_slave"
        set WAVE_FILE  "waves/wave_slave.do"
        set SIM_CMD    "vsim $VSIM_FLAGS $TOP_MODULE"
    }
    "fifo" {
        set TOP_MODULE "work.tb_async_fifo"
        set WAVE_FILE  "waves/wave_fifo.do"
        set SIM_CMD    "vsim $VSIM_FLAGS $TOP_MODULE"
    }
    "fft" {
        set N 32
        if {$argc > 1} {
            set N $2
        }
        set MULT_PIPE_STAGES 0
        if {$argc > 2} {
            set MULT_PIPE_STAGES $3
        }
        set TOP_MODULE "work.fft_TB"
        set WAVE_FILE  "waves/wave_fft.do"
        set SIM_CMD    "vsim $VSIM_FLAGS -gN=$N -gMULT_PIPE_STAGES=$MULT_PIPE_STAGES $TOP_MODULE"
    }
    default {
        echo "\[ERROR\] Unknown simulation target: $TARGET"
        echo "Valid targets: top, slave, fifo, fft"
        return
    }
}

# 7. Launch simulation
eval $SIM_CMD

# 8. Load waveforms and run simulation
if {[batch_mode]} {
    run -all
    quit -f
} else {
    if [file exists $WAVE_FILE] {
        do $WAVE_FILE
    } else {
        add wave -r /*
    }
    run -all
    wave zoom full
}
