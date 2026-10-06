# =============================================================================
# File Name      : wave_top.do
# Author         : Mostafa Ihab
# Creation Date  : 2026-10-01
# Version        : 1.0
# Description    : Waveform display configuration for top_TB (top_wrapper subsystem).
# =============================================================================

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {CLOCKS & RESETS}
add wave -noupdate -format Logic /tb_top/HCLK
add wave -noupdate -format Logic /tb_top/HRESETn
add wave -noupdate -format Logic /tb_top/ip_clk

add wave -noupdate -divider {AHB-LITE BUS INTERFACE}
add wave -noupdate -format Logic /tb_top/HSEL
add wave -noupdate -format Literal -radix hexadecimal /tb_top/HADDR
add wave -noupdate -format Literal -radix binary /tb_top/HTRANS
add wave -noupdate -format Logic /tb_top/HWRITE
add wave -noupdate -format Literal -radix binary /tb_top/HSIZE
add wave -noupdate -format Literal -radix hexadecimal /tb_top/HWDATA
add wave -noupdate -format Literal -radix hexadecimal /tb_top/HRDATA
add wave -noupdate -format Logic /tb_top/HREADY
add wave -noupdate -format Logic /tb_top/HREADYOUT
add wave -noupdate -format Logic /tb_top/HRESP

add wave -noupdate -divider {SYSTEM HANDSHAKES & IRQ}
add wave -noupdate -format Logic /tb_top/irq
add wave -noupdate -format Logic /tb_top/dma_rx_req
add wave -noupdate -format Logic /tb_top/dma_tx_req

add wave -noupdate -divider {REGISTER FILE}
add wave -noupdate -format Logic /tb_top/u_dut/u_rf/enable
add wave -noupdate -format Logic /tb_top/u_dut/u_rf/dma_en
add wave -noupdate -format Literal -radix binary /tb_top/u_dut/u_rf/status
add wave -noupdate -format Literal -radix binary /tb_top/u_dut/u_rf/int_status
add wave -noupdate -format Literal -radix decimal /tb_top/u_dut/u_rf/in_level
add wave -noupdate -format Literal -radix decimal /tb_top/u_dut/u_rf/out_level

add wave -noupdate -divider {IN FIFO (HCLK -> ip_clk)}
add wave -noupdate -format Logic /tb_top/u_dut/u_in_fifo/winc
add wave -noupdate -format Literal -radix hexadecimal /tb_top/u_dut/u_in_fifo/wdata
add wave -noupdate -format Logic /tb_top/u_dut/u_in_fifo/wfull
add wave -noupdate -format Literal -radix decimal /tb_top/u_dut/u_in_fifo/wlevel
add wave -noupdate -format Logic /tb_top/u_dut/u_in_fifo/rinc
add wave -noupdate -format Literal -radix hexadecimal /tb_top/u_dut/u_in_fifo/rdata
add wave -noupdate -format Logic /tb_top/u_dut/u_in_fifo/rempty

add wave -noupdate -divider {FFT STREAMING CORE}
add wave -noupdate -format Logic /tb_top/u_dut/fft_ce
add wave -noupdate -format Logic /tb_top/u_dut/fft_valid_in
add wave -noupdate -format Literal -radix decimal /tb_top/u_dut/u_fft_core/in_data_re
add wave -noupdate -format Literal -radix decimal /tb_top/u_dut/u_fft_core/in_data_im
add wave -noupdate -format Logic /tb_top/u_dut/fft_valid_out
add wave -noupdate -format Literal -radix decimal /tb_top/u_dut/fft_out_re
add wave -noupdate -format Literal -radix decimal /tb_top/u_dut/fft_out_im

add wave -noupdate -divider {REORDER BUFFER & FRAME DONE}
add wave -noupdate -format Logic /tb_top/u_dut/u_reorder_buf/valid_out
add wave -noupdate -format Literal -radix hexadecimal /tb_top/u_dut/u_reorder_buf/data_out
add wave -noupdate -format Logic /tb_top/u_dut/frame_done_i
add wave -noupdate -format Logic /tb_top/u_dut/frame_done_h

add wave -noupdate -divider {OUT FIFO (ip_clk -> HCLK)}
add wave -noupdate -format Logic /tb_top/u_dut/u_out_fifo/winc
add wave -noupdate -format Literal -radix hexadecimal /tb_top/u_dut/u_out_fifo/wdata
add wave -noupdate -format Logic /tb_top/u_dut/u_out_fifo/wfull
add wave -noupdate -format Logic /tb_top/u_dut/u_out_fifo/rinc
add wave -noupdate -format Literal -radix hexadecimal /tb_top/u_dut/u_out_fifo/rdata
add wave -noupdate -format Logic /tb_top/u_dut/u_out_fifo/rempty
add wave -noupdate -format Literal -radix decimal /tb_top/u_dut/u_out_fifo/rlevel

TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 220
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
