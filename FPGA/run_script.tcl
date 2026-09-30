# =============================================================================
# File Name      : run_script.tcl
# Author         : Mostafa Ihab
# Creation Date  : 2026-09-28
# Version        : 1.0
# Description    : Vivado batch synthesis and implementation script
#                  for the Parameterized R2SDF DIF FFT core.
# =============================================================================

# ==============================================================================
# CONFIGURATIONS
# ==============================================================================
# Get the absolute path
set script_path [file normalize [info script]]
set script_dir  [file dirname $script_path]
set vivado_workspace "$script_dir/Vivado_Build"

# Define Project Variables
set project_name "FFT32_DIF"
set num_jobs 8

puts "=============================================================================="
puts "Starting automated Vivado flow for $project_name..."
puts "Base Directory: $script_dir"
puts "=============================================================================="

# ==============================================================================
# 0. Project Creation & Initialization
# ==============================================================================
create_project -force $project_name $vivado_workspace

# Set target device and board (AMD/Xilinx Zynq UltraScale+ ZCU104 Evaluation Board)
set_property part xczu7ev-ffvc1156-2-e [current_project]
catch { set_property board_part xilinx.com:zcu104:part0:1.1 [current_project] }

# Preserve hierarchy during synthesis for detailed module-level inspection
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]

# ==============================================================================
# 1. Set RTL, IPs and Constraints
# ==============================================================================
# Add RTL files and configure top module
source $script_dir/add_files.tcl

# Define TARGET_FPGA macro to infer DSP48E2 primitives and dedicated fast carry logic
set current_defs [get_property verilog_define [get_filesets sources_1]]
set_property verilog_define [concat $current_defs TARGET_FPGA=1] [get_filesets sources_1]

# Set XDC constraints
add_files -fileset constrs_1 -norecurse $script_dir/constraints/sys_cons.xdc

update_compile_order -fileset sources_1

# ==============================================================================
# 2. Synthesis & Implementation
# ==============================================================================
# Run Synthesis
puts "INFO: Launching synthesis..."
launch_runs synth_1 -jobs $num_jobs
wait_on_run synth_1 

# Check if synthesis completed successfully
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    error "Synthesis failed."
}

# Run Implementation 
puts "INFO: Launching implementation..."
launch_runs impl_1 -jobs $num_jobs
wait_on_run impl_1 

# Check if implementation completed successfully
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    error "Implementation failed."
}

# Open the Implemented Design in memory for reporting/extraction
open_run impl_1 -name impl_1

# ==============================================================================
# 3. Output Generation & Reporting
# ==============================================================================
# Create Directories for outputs
file mkdir $script_dir/reports
file mkdir $script_dir/outputs

# Generate comprehensive implementation reports
puts "INFO: Generating timing, utilization, power, and DRC reports..."
report_utilization -file $script_dir/reports/post_impl_utilization.rpt
report_utilization -hierarchical -file $script_dir/reports/post_impl_utilization_hier.rpt
report_timing_summary -file $script_dir/reports/post_impl_timing.rpt
report_power -file $script_dir/reports/post_impl_power.rpt
report_drc -file $script_dir/reports/post_impl_drc.rpt

# Write Functional and Timing Simulation Netlists and SDF for Gate-Level Simulation (GLS)
puts "INFO: Exporting simulation netlists and SDF timing files..."
write_verilog -mode funcsim -force $script_dir/outputs/fft_top_funcsim.v
write_verilog -mode timesim -force $script_dir/outputs/fft_top_timesim.v
write_sdf -mode timesim -process_corner slow -force $script_dir/outputs/fft_top_timesim_max.sdf
write_sdf -mode timesim -process_corner fast -force $script_dir/outputs/fft_top_timesim_min.sdf

puts "\n=============================================================================="
puts "Vivado build complete for $project_name"
puts "Reports are located in : $script_dir/reports"
puts "Outputs are located in : $script_dir/outputs"
puts "=============================================================================="



