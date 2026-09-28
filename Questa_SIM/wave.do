# =========================================================================
# QuestaSim Waveform Configuration for 32-Point DIF R2SDF FFT
# =========================================================================

onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {TOP-LEVEL CLK & RST}
add wave -noupdate -format Logic /fft32_TB/clk
add wave -noupdate -format Logic /fft32_TB/rst_n

add wave -noupdate -divider {INPUT STREAMING INTERFACE}
add wave -noupdate -format Logic /fft32_TB/valid_in
add wave -noupdate -format Literal -radix decimal /fft32_TB/in_data_re
add wave -noupdate -format Literal -radix decimal /fft32_TB/in_data_im

add wave -noupdate -divider {CENTRAL CONTROLLER}
add wave -noupdate -format Literal -radix unsigned /fft32_TB/u_dut/u_controller/cnt
add wave -noupdate -format Literal -radix unsigned /fft32_TB/u_dut/u_controller/flush_cnt
add wave -noupdate -format Logic /fft32_TB/u_dut/u_controller/core_en
add wave -noupdate -format Logic /fft32_TB/u_dut/u_controller/stage1_sel
add wave -noupdate -format Literal -radix unsigned /fft32_TB/u_dut/u_controller/stage1_tw_addr
add wave -noupdate -format Logic /fft32_TB/u_dut/u_controller/stage2_sel
add wave -noupdate -format Literal -radix unsigned /fft32_TB/u_dut/u_controller/stage2_tw_addr
add wave -noupdate -format Logic /fft32_TB/u_dut/u_controller/stage3_sel
add wave -noupdate -format Literal -radix unsigned /fft32_TB/u_dut/u_controller/stage3_tw_addr
add wave -noupdate -format Logic /fft32_TB/u_dut/u_controller/stage4_sel
add wave -noupdate -format Logic /fft32_TB/u_dut/u_controller/stage5_sel

add wave -noupdate -divider {STAGE INTERCONNECTS}
add wave -noupdate -format Literal -radix decimal /fft32_TB/u_dut/stage1_out.re
add wave -noupdate -format Literal -radix decimal /fft32_TB/u_dut/stage1_out.im
add wave -noupdate -format Literal -radix decimal /fft32_TB/u_dut/stage2_out.re
add wave -noupdate -format Literal -radix decimal /fft32_TB/u_dut/stage2_out.im
add wave -noupdate -format Literal -radix decimal /fft32_TB/u_dut/stage3_out.re
add wave -noupdate -format Literal -radix decimal /fft32_TB/u_dut/stage3_out.im
add wave -noupdate -format Literal -radix decimal /fft32_TB/u_dut/stage4_out.re
add wave -noupdate -format Literal -radix decimal /fft32_TB/u_dut/stage4_out.im

add wave -noupdate -divider {OUTPUT STREAMING INTERFACE}
add wave -noupdate -format Logic /fft32_TB/valid_out
add wave -noupdate -format Literal -radix decimal /fft32_TB/out_data_re
add wave -noupdate -format Literal -radix decimal /fft32_TB/out_data_im

add wave -noupdate -divider {VERIFICATION CHECKER}
add wave -noupdate -format Literal -radix decimal /fft32_TB/sample_out_cnt
add wave -noupdate -format Literal -radix decimal /fft32_TB/latency_cycles
add wave -noupdate -format Literal -radix decimal /fft32_TB/error_count

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
configure wave -namecolwidth 250
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
