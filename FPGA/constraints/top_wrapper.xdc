# =============================================================================
# File Name      : top_wrapper.xdc
# Author         : Mostafa Ihab
# Creation Date  : 2026-10-01
# Version        : 1.0
# Description    : Timing, Clock Domain Crossing (CDC), and physical constraints
#                  for the AHB-Lite FFT Subsystem (top_wrapper).
#                  Target Platform: AMD/Xilinx Zynq UltraScale+ / 7-Series FPGA
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Primary Clock Definitions
# -----------------------------------------------------------------------------
# Host AHB-Lite Bus Clock: 100 MHz (10.0 ns period, 50% duty cycle)
create_clock -period 10.000 -name HCLK -waveform {0.000 5.000} [get_ports HCLK]

# Core Processing Clock (IP Domain): 200 MHz (5.0 ns period, 50% duty cycle)
create_clock -period 5.000 -name ip_clk -waveform {0.000 2.500} [get_ports ip_clk]

# -----------------------------------------------------------------------------
# 2. Clock Domain Crossing (CDC) Grouping
#    Declare HCLK and ip_clk as fully asynchronous clock domains
# -----------------------------------------------------------------------------
set_clock_groups -asynchronous \
    -group [get_clocks HCLK] \
    -group [get_clocks ip_clk]

# -----------------------------------------------------------------------------
# 3. Asynchronous FIFO Gray-Pointer Max Delay Constraints (CDC Bus Skew Control)
#    Restricts datapath delay across domain boundary to 1 source clock period
# -----------------------------------------------------------------------------
# IN FIFO: rgray crossing into wclk domain
set_max_delay -from [get_cells -hier -filter {NAME =~ *u_in_fifo/rgray_reg*}] \
              -to   [get_cells -hier -filter {NAME =~ *u_in_fifo/u_sync_r2w/sync_pipe_reg[0]*}] \
              -datapath_only 10.000

# IN FIFO: wgray crossing into rclk domain
set_max_delay -from [get_cells -hier -filter {NAME =~ *u_in_fifo/wgray_reg*}] \
              -to   [get_cells -hier -filter {NAME =~ *u_in_fifo/u_sync_w2r/sync_pipe_reg[0]*}] \
              -datapath_only 5.000

# OUT FIFO: rgray crossing into wclk domain
set_max_delay -from [get_cells -hier -filter {NAME =~ *u_out_fifo/rgray_reg*}] \
              -to   [get_cells -hier -filter {NAME =~ *u_out_fifo/u_sync_r2w/sync_pipe_reg[0]*}] \
              -datapath_only 5.000

# OUT FIFO: wgray crossing into rclk domain
set_max_delay -from [get_cells -hier -filter {NAME =~ *u_out_fifo/wgray_reg*}] \
              -to   [get_cells -hier -filter {NAME =~ *u_out_fifo/u_sync_w2r/sync_pipe_reg[0]*}] \
              -datapath_only 10.000

# -----------------------------------------------------------------------------
# 4. Status & Event CDC Max Delay Constraints
# -----------------------------------------------------------------------------
# Busy sync: ip_clk -> HCLK
set_max_delay -from [get_cells -hier -filter {NAME =~ *u_ctrl/inflight_reg*}] \
              -to   [get_cells -hier -filter {NAME =~ *u_busy_sync/sync_pipe_reg[0]*}] \
              -datapath_only 10.000

# Frame Done pulse sync: ip_clk -> HCLK
set_max_delay -from [get_cells -hier -filter {NAME =~ *u_frame_sync/toggle_src_reg*}] \
              -to   [get_cells -hier -filter {NAME =~ *u_frame_sync/sync_pipe_reg[0]*}] \
              -datapath_only 10.000

# -----------------------------------------------------------------------------
# 5. Asynchronous Reset Constraints
# -----------------------------------------------------------------------------
set_false_path -from [get_ports HRESETn]

# -----------------------------------------------------------------------------
# 6. AHB-Lite Host Interface Input / Output Delay Budgets
#    Budget 30% of HCLK period (3.0 ns) for external setup/hold
# -----------------------------------------------------------------------------
set_input_delay  -clock HCLK -max 3.000 [get_ports {HSEL HADDR* HTRANS* HWRITE HSIZE* HWDATA* HREADY}]
set_input_delay  -clock HCLK -min 0.500 [get_ports {HSEL HADDR* HTRANS* HWRITE HSIZE* HWDATA* HREADY}]

set_output_delay -clock HCLK -max 3.000 [get_ports {HREADYOUT HRDATA* HRESP irq dma_rx_req dma_tx_req}]
set_output_delay -clock HCLK -min 0.500 [get_ports {HREADYOUT HRDATA* HRESP irq dma_rx_req dma_tx_req}]
