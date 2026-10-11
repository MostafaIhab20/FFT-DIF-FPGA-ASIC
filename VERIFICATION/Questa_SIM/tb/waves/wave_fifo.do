# =============================================================================
# File Name      : wave_fifo.do
# Author         : Mostafa Ihab
# Creation Date  : 2026-10-01
# Version        : 1.0
# Description    : Waveform display configuration for async_fifo_TB.
# =============================================================================

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {WRITE CLOCK DOMAIN}
add wave -noupdate -format Logic /tb_async_fifo/wclk
add wave -noupdate -format Logic /tb_async_fifo/wrst_n
add wave -noupdate -format Logic /tb_async_fifo/winc
add wave -noupdate -format Literal -radix decimal /tb_async_fifo/wdata
add wave -noupdate -format Logic /tb_async_fifo/wfull
add wave -noupdate -format Literal -radix decimal /tb_async_fifo/wlevel

add wave -noupdate -divider {READ CLOCK DOMAIN}
add wave -noupdate -format Logic /tb_async_fifo/rclk
add wave -noupdate -format Logic /tb_async_fifo/rrst_n
add wave -noupdate -format Logic /tb_async_fifo/rinc
add wave -noupdate -format Literal -radix decimal /tb_async_fifo/rdata
add wave -noupdate -format Logic /tb_async_fifo/rempty
add wave -noupdate -format Literal -radix decimal /tb_async_fifo/rlevel

add wave -noupdate -divider {VERIFICATION COUNTERS}
add wave -noupdate -format Literal -radix decimal /tb_async_fifo/wcnt
add wave -noupdate -format Literal -radix decimal /tb_async_fifo/rcnt
add wave -noupdate -format Literal -radix decimal /tb_async_fifo/errors
add wave -noupdate -format Logic /tb_async_fifo/saw_full
add wave -noupdate -format Logic /tb_async_fifo/saw_empty

TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 200
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
