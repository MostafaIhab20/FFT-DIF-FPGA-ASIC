# =============================================================================
# File Name      : top_wrapper.xdc
# Author         : Mostafa Ihab
# Creation Date  : 2026-10-01
# Version        : 1.0
# Description    : Timing, Clock Domain Crossing (CDC), I/O delay budgeting,
#                  and physical pin constraints for the AHB-Lite FFT Subsystem.
#                  Target Platform: AMD/Xilinx Zynq UltraScale+ ZCU104
#                  Target Device  : xczu7ev-ffvc1156-2-e
# =============================================================================

# =============================================================================
# 1. Configuration Parameters & Timing Budgets
# =============================================================================
# Primary Clock Periods and Waveform Configuration
set HCLK_PERIOD             10.000; # 100 MHz AHB-Lite Host Bus Clock (ns)
set HCLK_HALF_PERIOD         5.000; # 50% Duty Cycle

set IP_CLK_PERIOD            5.000; # 200 MHz FFT Core Processing Clock (ns)
set IP_CLK_HALF_PERIOD       2.500; # 50% Duty Cycle

# AHB-Lite Host Interface I/O Timing Delay Budgets (HCLK Domain)
# Budget 30% of HCLK period for external setup / board routing
set AHB_INPUT_MAX_DELAY      3.000; # Max external delay to FPGA inputs (ns)
set AHB_INPUT_MIN_DELAY      0.500; # Min external delay (Hold budget) (ns)

set AHB_OUTPUT_MAX_DELAY     3.000; # Max external setup delay for downstream logic (ns)
set AHB_OUTPUT_MIN_DELAY     0.500; # Min external hold delay for downstream logic (ns)

# =============================================================================
# 2. Primary Clock Definitions
# =============================================================================
# Host AHB-Lite Bus Clock (100 MHz)
create_clock -period $HCLK_PERIOD \
             -name HCLK \
             -waveform [list 0.000 $HCLK_HALF_PERIOD] \
             [get_ports HCLK]

# Core Processing Clock (200 MHz IP Domain)
create_clock -period $IP_CLK_PERIOD \
             -name ip_clk \
             -waveform [list 0.000 $IP_CLK_HALF_PERIOD] \
             [get_ports ip_clk]

# =============================================================================
# 3. Clock Domain Crossing (CDC) Grouping
#    Declare HCLK and ip_clk as fully asynchronous, independent clock domains
# =============================================================================
set_clock_groups -asynchronous \
    -group [get_clocks HCLK] \
    -group [get_clocks ip_clk]

# =============================================================================
# 4. Asynchronous FIFO Gray-Pointer CDC Max Delay Constraints
#    Restricts datapath delay across CDC boundary to prevent multi-bit skew
# =============================================================================
# IN FIFO: Read Gray-pointer crossing into Write (HCLK) domain
set_max_delay -from [get_cells -hier -filter {NAME =~ *u_in_fifo/rgray_reg*}] \
              -to   [get_cells -hier -filter {NAME =~ *u_in_fifo/u_sync_r2w/*sync_q_reg[0]* || NAME =~ *u_in_fifo/u_sync_r2w/*sync_q[0]*}] \
              -datapath_only $HCLK_PERIOD

# IN FIFO: Write Gray-pointer crossing into Read (ip_clk) domain
set_max_delay -from [get_cells -hier -filter {NAME =~ *u_in_fifo/wgray_reg*}] \
              -to   [get_cells -hier -filter {NAME =~ *u_in_fifo/u_sync_w2r/*sync_q_reg[0]* || NAME =~ *u_in_fifo/u_sync_w2r/*sync_q[0]*}] \
              -datapath_only $IP_CLK_PERIOD

# OUT FIFO: Read Gray-pointer crossing into Write (ip_clk) domain
set_max_delay -from [get_cells -hier -filter {NAME =~ *u_out_fifo/rgray_reg*}] \
              -to   [get_cells -hier -filter {NAME =~ *u_out_fifo/u_sync_r2w/*sync_q_reg[0]* || NAME =~ *u_out_fifo/u_sync_r2w/*sync_q[0]*}] \
              -datapath_only $IP_CLK_PERIOD

# OUT FIFO: Write Gray-pointer crossing into Read (HCLK) domain
set_max_delay -from [get_cells -hier -filter {NAME =~ *u_out_fifo/wgray_reg*}] \
              -to   [get_cells -hier -filter {NAME =~ *u_out_fifo/u_sync_w2r/*sync_q_reg[0]* || NAME =~ *u_out_fifo/u_sync_w2r/*sync_q[0]*}] \
              -datapath_only $HCLK_PERIOD

# =============================================================================
# 5. Status & Event CDC Max Delay Constraints
# =============================================================================
# Core Busy Synchronizer: ip_clk -> HCLK Domain
set_max_delay -from [get_cells -hier -filter {NAME =~ *u_ctrl/inflight_reg*}] \
              -to   [get_cells -hier -filter {NAME =~ *u_busy_sync/*sync_q_reg[0]* || NAME =~ *u_busy_sync/*sync_q[0]*}] \
              -datapath_only $HCLK_PERIOD

# Frame-Done Pulse Synchronizer: ip_clk -> HCLK Domain
set_max_delay -from [get_cells -hier -filter {NAME =~ *u_frame_sync/toggle_src_reg*}] \
              -to   [get_cells -hier -filter {NAME =~ *u_frame_sync/sync_pipe_reg[0]*}] \
              -datapath_only $HCLK_PERIOD

# =============================================================================
# 6. Asynchronous Reset Constraints
# =============================================================================
# Exclude active-low asynchronous system reset from data path timing
set_false_path -from [get_ports HRESETn]

# =============================================================================
# 7. Host AHB-Lite & Handshake I/O Delay Budgeting
# =============================================================================
set AHB_INPUT_PORTS [get_ports {HSEL HADDR* HTRANS* HWRITE HSIZE* HWDATA* HREADY}]

set_input_delay  -clock HCLK -max $AHB_INPUT_MAX_DELAY $AHB_INPUT_PORTS
set_input_delay  -clock HCLK -min $AHB_INPUT_MIN_DELAY $AHB_INPUT_PORTS

set AHB_OUTPUT_PORTS [get_ports {HREADYOUT HRDATA* HRESP irq dma_rx_req dma_tx_req}]

set_output_delay -clock HCLK -max $AHB_OUTPUT_MAX_DELAY $AHB_OUTPUT_PORTS
set_output_delay -clock HCLK -min $AHB_OUTPUT_MIN_DELAY $AHB_OUTPUT_PORTS
