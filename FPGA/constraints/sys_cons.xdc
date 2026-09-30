# =============================================================================
# File Name      : sys_cons.xdc
# Author         : Mostafa Ihab
# Creation Date  : 2026-09-28
# Version        : 1.0
# Description    : Timing constraints for Parameterized R2SDF DIF FFT Core.
#                  Target Device: AMD/Xilinx Zynq UltraScale+ (ZCU104 Evaluation Board)
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Primary Clock Definition
#    Target Frequency: 300 MHz (Clock Period: 3.333 ns, 50% duty cycle)
# -----------------------------------------------------------------------------
create_clock -period 3.333 -name sys_clk -waveform {0.000 1.666} [get_ports clk]

# -----------------------------------------------------------------------------
# 2. Input / Output Timing Budget (Virtual Clock Constraints)
#    Budgets 20% of the clock period (~0.666 ns) for external routing/setup
# -----------------------------------------------------------------------------
set_input_delay  -clock sys_clk -max 0.666 [get_ports {valid_in in_data_re* in_data_im*}]
set_input_delay  -clock sys_clk -min 0.200 [get_ports {valid_in in_data_re* in_data_im*}]

set_output_delay -clock sys_clk -max 0.666 [get_ports {valid_out out_data_re* out_data_im*}]
set_output_delay -clock sys_clk -min 0.200 [get_ports {valid_out out_data_re* out_data_im*}]

# -----------------------------------------------------------------------------
# 3. Asynchronous Reset Constraints
#    Exclude active-low reset from synchronous data path timing
# -----------------------------------------------------------------------------
set_false_path -from [get_ports rst_n]
