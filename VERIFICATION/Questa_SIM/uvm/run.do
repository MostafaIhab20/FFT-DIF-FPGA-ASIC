# =============================================================================
# File Name      : run.do
# Author         : Mostafa Ihab
# Creation Date  : 2026-10-07
# Version        : 2.0
# Description    : Master QuestaSim simulation, regression, and coverage analysis
#                  script for the UVM verification environment of the AHB-Lite
#                  32-point Radix-2 DIF FFT Subsystem.
# Usage:
#   do run.do                           (Runs default test: fft_sanity_test)
#   do run.do <test_name>               (Runs specified test, e.g. fft_multi_frame_test)
#   do run.do regression                (Runs full 9-test regression and merges coverage)
#   do run.do all                       (Alias for regression)
# =============================================================================

# Close any active simulation
catch {quit -sim}

# Set root directory paths relative to current script directory (uvm/)
set RTL_LIST    "filelists/rtl_list.f"
set INCDIR_LIST "filelists/incdir_list.f"
set UVM_LIST    "filelists/uvm_list.f"
set QUESTA_UVM  "C:/questasim64_2021.1/verilog_src/uvm-1.2/src"
set UVM_DPI     "C:/questasim64_2021.1/uvm-1.2/win64/uvm_dpi"

set CPP_MODEL   "../../../DESIGN/model/cpp/fft_radix2_dif.cpp"
set CPP_WRAP    "../../UVM/dpi/fft_dpi_wrapper.cpp"

# Ensure output directory hierarchy exists
file mkdir logs
file mkdir coverage
file mkdir coverage/ucdb
file mkdir coverage/reports
file mkdir coverage/html
file mkdir waves

# Parse argument target
set TARGET "fft_sanity_test"
if {$argc > 0} {
    set TARGET [string tolower $1]
}

# Compile C++ DPI shared library if missing or out-of-date
if {![file exists fft_dpi.dll] || [file mtime $CPP_MODEL] > [file mtime fft_dpi.dll] || [file mtime $CPP_WRAP] > [file mtime fft_dpi.dll]} {
    echo "\[INFO\] Compiling C++ DPI model (fft_dpi.dll)..."
    exec g++ -shared -std=c++17 -O3 -I C:/questasim64_2021.1/include -I ../../../DESIGN/model/cpp -o fft_dpi.dll $CPP_MODEL $CPP_WRAP
}

# Procedure: Compile all RTL design and UVM testbench sources using read lists
proc compile_all {} {
    global RTL_LIST INCDIR_LIST UVM_LIST QUESTA_UVM

    echo "\[INFO\] Rebuilding work library..."
    if [file exists work] {
        file delete -force work
    }
    vlib work
    vmap work work

    echo "\[INFO\] Compiling RTL sources with code coverage instrumentation (+cover=bcesf)..."
    vlog -sv -work work +cover=bcesf -f $RTL_LIST

    echo "\[INFO\] Compiling UVM library and testbench hierarchy using read lists..."
    vlog -sv -work work -f $INCDIR_LIST $QUESTA_UVM/uvm_pkg.sv -f $UVM_LIST
}

# Procedure: Run a single test with coverage capture and log generation
proc run_single_test {tname is_batch} {
    global UVM_DPI

    set log_file   "logs/${tname}.log"
    set ucdb_file  "coverage/ucdb/${tname}.ucdb"
    set sum_file   "coverage/reports/${tname}_summary.txt"
    set det_file   "coverage/reports/${tname}_detail.txt"
    set html_dir   "coverage/html/${tname}"

    echo "========================================================================="
    echo "\[RUN\] Launching Test: $tname"
    echo "========================================================================="

    catch {quit -sim}

    transcript on
    transcript file $log_file

    vsim -coverage -onfinish stop -t 1ps -suppress 3009,8785 \
        -sv_lib $UVM_DPI \
        -sv_lib fft_dpi \
        +UVM_TESTNAME=$tname \
        work.tb_top_uvm

    if {!$is_batch} {
        if [file exists "waves/wave_uvm.do"] {
            do "waves/wave_uvm.do"
        } else {
            add wave -r /*
        }
    }

    run -all

    # Explicitly save UCDB database
    coverage save $ucdb_file

    # Generate text and HTML coverage reports
    if [file exists $ucdb_file] {
        echo "\[INFO\] Generating coverage reports for $tname..."
        vcover report -summary -output $sum_file $ucdb_file
        vcover report -zeros -details -annotate -all -output $det_file $ucdb_file
        vcover report -html -output $html_dir $ucdb_file
    }

    transcript off

    if {$is_batch} {
        quit -f
    } else {
        wave zoom full
    }
}

# Procedure: Run complete 9-test regression and generate unified merged coverage
proc run_regression {} {
    global UVM_DPI

    set test_list [list \
        "fft_sanity_test" \
        "fft_burst_test" \
        "fft_reg_reset_test" \
        "fft_multi_frame_test" \
        "fft_bus_error_test" \
        "fft_fifo_boundary_test" \
        "fft_dma_handshake_test" \
        "fft_reset_flush_test" \
        "fft_coverage_closure_test" \
    ]

    echo "========================================================================="
    echo "                   STARTING FULL UVM REGRESSION SUITE                    "
    echo "========================================================================="

    foreach tst $test_list {
        set log_file   "logs/${tst}.log"
        set ucdb_file  "coverage/ucdb/${tst}.ucdb"
        set sum_file   "coverage/reports/${tst}_summary.txt"
        set det_file   "coverage/reports/${tst}_detail.txt"
        set html_dir   "coverage/html/${tst}"

        echo "-------------------------------------------------------------------------"
        echo "\[REGRESSION\] Executing test: $tst"
        echo "-------------------------------------------------------------------------"

        catch {quit -sim}
        transcript on
        transcript file $log_file

        vsim -coverage -onfinish stop -t 1ps -suppress 3009,8785 \
            -sv_lib $UVM_DPI \
            -sv_lib fft_dpi \
            +UVM_TESTNAME=$tst \
            work.tb_top_uvm

        run -all

        coverage save $ucdb_file
        transcript off

        if [file exists $ucdb_file] {
            vcover report -summary -output $sum_file $ucdb_file
            vcover report -zeros -details -annotate -all -output $det_file $ucdb_file
            vcover report -html -output $html_dir $ucdb_file
        }
    }

    catch {quit -sim}

    echo "========================================================================="
    echo "                MERGING REGRESSION COVERAGE DATABASES                    "
    echo "========================================================================="

    set ucdb_files [glob -nocomplain coverage/ucdb/*.ucdb]
    set merged_ucdb "coverage/ucdb/regression_merged.ucdb"

    # Filter out previous merged file from the list if present
    set clean_ucdbs [list]
    foreach f $ucdb_files {
        if {[file tail $f] ne "regression_merged.ucdb"} {
            lappend clean_ucdbs $f
        }
    }

    if {[llength $clean_ucdbs] > 0} {
        eval vcover merge $merged_ucdb $clean_ucdbs

        echo "\[INFO\] Generating cumulative merged regression coverage reports..."
        vcover report -summary -output coverage/reports/regression_summary.txt $merged_ucdb
        vcover report -zeros -details -annotate -all -output coverage/reports/regression_detail.txt $merged_ucdb
        vcover report -html -output coverage/html/merged $merged_ucdb

        echo "========================================================================="
        echo "                   REGRESSION COVERAGE SUMMARY                           "
        echo "========================================================================="
        vcover report -summary $merged_ucdb
    }

    echo "========================================================================="
    echo "                FULL REGRESSION COMPLETED SUCCESSFULLY!                  "
    echo "========================================================================="

    if {[batch_mode]} {
        quit -f
    }
}

# Procedure: Open interactive QuestaSim GUI for coverage analysis with exclusions loaded
proc view_coverage {} {
    catch {quit -sim}
    vsim -viewcov coverage/ucdb/regression_merged.ucdb
    if {[file exists "coverage/coverage_exclusions.do"]} {
        do coverage/coverage_exclusions.do
    }
}

# Main Execution Flow
compile_all

if {$TARGET eq "regression" || $TARGET eq "all"} {
    run_regression
} else {
    run_single_test $TARGET [batch_mode]
}
