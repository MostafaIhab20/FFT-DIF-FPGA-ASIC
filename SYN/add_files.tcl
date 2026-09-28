# Vivado add_files.tcl

# Add all synthesis RTL and Header files in a single batch
add_files [list \
    "C:/MY_PROJETS/RTL2GDS_FFT32/DESIGN/RTL/fft32_pkg.sv" \
    "C:/MY_PROJETS/RTL2GDS_FFT32/DESIGN/RTL/adder_subtractor_bk.sv" \
    "C:/MY_PROJETS/RTL2GDS_FFT32/DESIGN/RTL/booth_radix4_multiplier.sv" \
    "C:/MY_PROJETS/RTL2GDS_FFT32/DESIGN/RTL/butterfly_radix2.sv" \
    "C:/MY_PROJETS/RTL2GDS_FFT32/DESIGN/RTL/complex_multiplier.sv" \
    "C:/MY_PROJETS/RTL2GDS_FFT32/DESIGN/RTL/delay_feedback_line.sv" \
    "C:/MY_PROJETS/RTL2GDS_FFT32/DESIGN/RTL/fft32_top.sv" \
    "C:/MY_PROJETS/RTL2GDS_FFT32/DESIGN/RTL/fft_controller.sv" \
    "C:/MY_PROJETS/RTL2GDS_FFT32/DESIGN/RTL/fft_stage.sv" \
    "C:/MY_PROJETS/RTL2GDS_FFT32/DESIGN/RTL/twiddle_rom.sv" \
]

# Set the top module and update compile order
set_property top fft32_top [current_fileset]
update_compile_order -fileset sources_1
