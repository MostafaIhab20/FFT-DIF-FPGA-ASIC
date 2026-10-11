# =============================================================================
# File Name      : wave_uvm.do
# Description    : Waveform view configuration for FFT UVM verification.
# =============================================================================

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {CLOCKS & RESETS}
add wave -noupdate /tb_top_uvm/HCLK
add wave -noupdate /tb_top_uvm/HRESETn
add wave -noupdate /tb_top_uvm/ip_clk

add wave -noupdate -divider {AHB-LITE BUS INTERFACE}
add wave -noupdate /tb_top_uvm/ahb_vif/HSEL
add wave -noupdate -radix hexadecimal /tb_top_uvm/ahb_vif/HADDR
add wave -noupdate /tb_top_uvm/ahb_vif/HTRANS
add wave -noupdate /tb_top_uvm/ahb_vif/HBURST
add wave -noupdate /tb_top_uvm/ahb_vif/HWRITE
add wave -noupdate /tb_top_uvm/ahb_vif/HSIZE
add wave -noupdate -radix hexadecimal /tb_top_uvm/ahb_vif/HWDATA
add wave -noupdate -radix hexadecimal /tb_top_uvm/ahb_vif/HRDATA
add wave -noupdate /tb_top_uvm/ahb_vif/HREADYOUT
add wave -noupdate /tb_top_uvm/ahb_vif/HRESP

add wave -noupdate -divider {SIDEBAND SIGNALS}
add wave -noupdate /tb_top_uvm/sb_vif/irq
add wave -noupdate /tb_top_uvm/sb_vif/dma_rx_req
add wave -noupdate /tb_top_uvm/sb_vif/dma_tx_req

add wave -noupdate -divider {REGISTER FILE STATUS}
add wave -noupdate -radix hexadecimal /tb_top_uvm/u_dut/u_rf/status
add wave -noupdate -radix hexadecimal /tb_top_uvm/u_dut/u_rf/int_status
add wave -noupdate -radix unsigned /tb_top_uvm/u_dut/u_rf/in_level
add wave -noupdate -radix unsigned /tb_top_uvm/u_dut/u_rf/out_level

add wave -noupdate -divider {FFT STREAMING CORE}
add wave -noupdate /tb_top_uvm/u_dut/u_ctrl/ip_ce
add wave -noupdate /tb_top_uvm/u_dut/u_ctrl/ip_valid_in
add wave -noupdate -radix decimal /tb_top_uvm/u_dut/u_fft_core/in_data_re
add wave -noupdate -radix decimal /tb_top_uvm/u_dut/u_fft_core/in_data_im
add wave -noupdate /tb_top_uvm/u_dut/u_fft_core/valid_out
add wave -noupdate -radix decimal /tb_top_uvm/u_dut/u_fft_core/out_data_re
add wave -noupdate -radix decimal /tb_top_uvm/u_dut/u_fft_core/out_data_im

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 250
configure wave -valuecolwidth 120
configure wave -justifyvalue left
configure wave -signalnamestyle 1
configure wave -timelineunits ns
