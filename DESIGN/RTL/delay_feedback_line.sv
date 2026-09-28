// =============================================================================
// File Name      : delay_feedback_line.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-09-27
// Version        : 1.0
// Description    : Parameterized synchronous delay feedback shift-register buffer.
//                  Supports arbitrary depth DEPTH (e.g., N/2, N/4, ..., 2, 1) for storing
//                  intermediate butterfly differences and input samples.
//                  Data elements are complex numbers (16-bit Re + 16-bit Im).
// =============================================================================

import fft_pkg::*;

module delay_feedback_line #(
    parameter int DEPTH = 16
)(
    input  logic          clk,
    input  logic          rst_n,
    input  logic          en,
    input  wire complex_t din,
    output wire complex_t dout
);

    generate
        if (DEPTH == 1) begin : gen_single_reg
            complex_t reg_data;

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    reg_data.re <= '0;
                    reg_data.im <= '0;
                end else if (en) begin
                    reg_data <= din;
                end
            end

            assign dout = reg_data;
        end else begin : gen_shift_reg
            complex_t shift_reg [0:DEPTH-1];

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    for (int i = 0; i < DEPTH; i++) begin
                        shift_reg[i].re <= '0;
                        shift_reg[i].im <= '0;
                    end
                end else if (en) begin
                    shift_reg[0] <= din;
                    for (int i = 1; i < DEPTH; i++) begin
                        shift_reg[i] <= shift_reg[i-1];
                    end
                end
            end

            assign dout = shift_reg[DEPTH-1];
        end
    endgenerate

endmodule : delay_feedback_line
