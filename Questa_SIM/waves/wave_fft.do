# =============================================================================
# File Name      : wave_fft.do
# Author         : Mostafa Ihab
# Creation Date  : 2026-10-01
# Version        : 1.0
# Description    : Waveform display configuration for fft_TB.
# =============================================================================

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {TOP-LEVEL CLK & RST}
add wave -noupdate -format Logic /fft_TB/clk
add wave -noupdate -format Logic /fft_TB/rst_n
add wave -noupdate -format Logic /fft_TB/clk_en

add wave -noupdate -divider {INPUT STREAMING INTERFACE}
add wave -noupdate -format Logic /fft_TB/valid_in
add wave -noupdate -format Literal -radix decimal /fft_TB/in_data_re
add wave -noupdate -format Literal -radix decimal /fft_TB/in_data_im

add wave -noupdate -divider {CENTRAL CONTROLLER}
add wave -noupdate -format Literal -radix unsigned /fft_TB/u_dut/u_controller/cnt
add wave -noupdate -format Literal -radix unsigned /fft_TB/u_dut/u_controller/flush_cnt
add wave -noupdate -format Logic /fft_TB/u_dut/u_controller/core_en
add wave -noupdate -format Literal -radix binary /fft_TB/u_dut/u_controller/stage_sel
add wave -noupdate -format Literal /fft_TB/u_dut/u_controller/stage_tw_addr

add wave -noupdate -divider {STAGE INTERCONNECTS}
add wave -noupdate -format Literal /fft_TB/u_dut/stage_data

add wave -noupdate -divider {OUTPUT STREAMING INTERFACE}
add wave -noupdate -format Logic /fft_TB/valid_out
add wave -noupdate -format Literal -radix decimal /fft_TB/out_data_re
add wave -noupdate -format Literal -radix decimal /fft_TB/out_data_im

add wave -noupdate -divider {VERIFICATION CHECKER}
add wave -noupdate -format Literal -radix decimal /fft_TB/sample_out_cnt
add wave -noupdate -format Literal -radix decimal /fft_TB/latency_cycles
add wave -noupdate -format Literal -radix decimal /fft_TB/error_count

TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 250
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
