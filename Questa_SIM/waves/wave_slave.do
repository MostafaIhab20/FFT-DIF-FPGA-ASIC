# =============================================================================
# File Name      : wave_slave.do
# Author         : Mostafa Ihab
# Creation Date  : 2026-10-01
# Version        : 1.0
# Description    : Waveform display configuration for ahb_slave_TB.
# =============================================================================

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {CLOCKS & RESETS}
add wave -noupdate -format Logic /tb_ahb_slave/HCLK
add wave -noupdate -format Logic /tb_ahb_slave/HRESETn

add wave -noupdate -divider {AHB-LITE INTERFACE}
add wave -noupdate -format Logic /tb_ahb_slave/HSEL
add wave -noupdate -format Literal -radix hexadecimal /tb_ahb_slave/HADDR
add wave -noupdate -format Literal -radix binary /tb_ahb_slave/HTRANS
add wave -noupdate -format Logic /tb_ahb_slave/HWRITE
add wave -noupdate -format Literal -radix binary /tb_ahb_slave/HSIZE
add wave -noupdate -format Literal -radix hexadecimal /tb_ahb_slave/HWDATA
add wave -noupdate -format Literal -radix hexadecimal /tb_ahb_slave/HRDATA
add wave -noupdate -format Logic /tb_ahb_slave/HREADY
add wave -noupdate -format Logic /tb_ahb_slave/HREADYOUT
add wave -noupdate -format Logic /tb_ahb_slave/HRESP

add wave -noupdate -divider {SLAVE INTERNAL STATE}
add wave -noupdate -format Logic /tb_ahb_slave/dut/d_valid
add wave -noupdate -format Logic /tb_ahb_slave/dut/d_write
add wave -noupdate -format Literal -radix hexadecimal /tb_ahb_slave/dut/d_addr
add wave -noupdate -format Literal -radix binary /tb_ahb_slave/dut/d_size
add wave -noupdate -format Logic /tb_ahb_slave/dut/size_bad
add wave -noupdate -format Logic /tb_ahb_slave/dut/err_now
add wave -noupdate -format Logic /tb_ahb_slave/dut/err_ph2
add wave -noupdate -format Logic /tb_ahb_slave/dut/access

add wave -noupdate -divider {DECODED SIMPLE REGISTER BUS}
add wave -noupdate -format Literal -radix hexadecimal /tb_ahb_slave/bus_addr
add wave -noupdate -format Logic /tb_ahb_slave/bus_write
add wave -noupdate -format Logic /tb_ahb_slave/bus_wr_en
add wave -noupdate -format Logic /tb_ahb_slave/bus_rd_en
add wave -noupdate -format Literal -radix hexadecimal /tb_ahb_slave/bus_wdata
add wave -noupdate -format Literal -radix hexadecimal /tb_ahb_slave/bus_rdata
add wave -noupdate -format Logic /tb_ahb_slave/bus_err

TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 200
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
