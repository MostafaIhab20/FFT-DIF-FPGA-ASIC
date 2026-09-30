// =============================================================================
// File Name      : booth_radix4_multiplier.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-09-27
// Version        : 1.0
// Description    : Parameterized 16x16 Signed Radix-4 Modified Booth Multiplier.
//                  Features:
//                    - Radix-4 Booth Encoding (reduces 16 partial products to 8)
//                    - Two-level 4:2 Compressor Tree (carry-free row reduction)
//                    - Parameterized pipeline depth PIPELINE_STAGES:
//                        0: Pure combinational (0 latency cycles)
//                        1: 1 internal pipeline register after Compressor Tree
//                        2: 2 internal pipeline registers (after Level 1 & Level 2)
//                    - Carry-Propagate Final Addition using Brent-Kung Adder
// =============================================================================

`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// 1. Primitive 4:2 Compressor Cell
//    Equation: X0 + X1 + X2 + X3 + Cin = Sum + 2 * (Carry + Cout)
//    Notice: Cout depends ONLY on X0, X1, X2 (no ripple carry to adjacent bits!)
// -----------------------------------------------------------------------------
module compressor4_2 (
    input  logic x0,
    input  logic x1,
    input  logic x2,
    input  logic x3,
    input  logic cin,
    output logic sum,
    output logic carry,
    output logic cout
);
    logic s_int;

    assign s_int = x0 ^ x1 ^ x2;
    assign cout  = (x0 & x1) | (x1 & x2) | (x0 & x2);

    assign sum   = s_int ^ x3 ^ cin;
    assign carry = (s_int & x3) | (x3 & cin) | (s_int & cin);

endmodule : compressor4_2

// -----------------------------------------------------------------------------
// 2. 32-bit 4:2 Compressor Slice Array
// -----------------------------------------------------------------------------
module compressor4_2_array #(
    parameter int WIDTH = 32
)(
    input  logic [WIDTH-1:0] x0,
    input  logic [WIDTH-1:0] x1,
    input  logic [WIDTH-1:0] x2,
    input  logic [WIDTH-1:0] x3,
    output logic [WIDTH-1:0] sum,
    output logic [WIDTH-1:0] carry
);
    logic [WIDTH:0] c_chain;
    assign c_chain[0] = 1'b0;

    generate
        for (genvar i = 0; i < WIDTH; i++) begin : gen_comp_bits
            compressor4_2 u_comp_cell (
                .x0    (x0[i]),
                .x1    (x1[i]),
                .x2    (x2[i]),
                .x3    (x3[i]),
                .cin   (c_chain[i]),
                .sum   (sum[i]),
                .carry (carry[i]),
                .cout  (c_chain[i+1])
            );
        end
    endgenerate

endmodule : compressor4_2_array

// -----------------------------------------------------------------------------
// 3. Top-Level Radix-4 Booth Multiplier
// -----------------------------------------------------------------------------
module booth_radix4_multiplier #(
    parameter int PIPELINE_STAGES = 0 // 0: Combinational, 1: 1 Stage, 2: 2 Stages
)(
    input  logic               clk,
    input  logic               rst_n,
    input  logic               en,
    input  logic signed [15:0] a, // Multiplicand
    input  logic signed [15:0] b, // Multiplier
    output logic signed [31:0] p  // Product: a * b
);

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================
    // Multiplier Extension & Partial Products
    logic [16:0]        b_ext;
    logic signed [31:0] pp [0:7];

    // Level 1 Reduction Signals
    logic [31:0]        s_a, c_a;
    logic [31:0]        s_b, c_b;
    logic [31:0]        s_a_pipe, c_a_pipe;
    logic [31:0]        s_b_pipe, c_b_pipe;

    // Level 2 Reduction Signals
    logic [31:0]        s_final, c_final;
    logic [31:0]        s_fin_pipe, c_fin_pipe;

    // Final Vector Addition Signals
    logic [31:0]        bk_sum;
    logic               bk_cout;
    logic               bk_ovf;

    // =========================================================================
    // Phase 1: Radix-4 Booth Partial Product Generation
    // =========================================================================
    assign b_ext = {b, 1'b0};

    always_comb begin
        for (int i = 0; i < 8; i++) begin
            logic [2:0] triplet;
            logic signed [17:0] val;

            triplet = b_ext[2*i +: 3];

            case (triplet)
                3'b001, 3'b010: val =  $signed(a);
                3'b011:         val =  $signed({a, 1'b0});
                3'b100:         val = -$signed({a, 1'b0});
                3'b101, 3'b110: val = -$signed(a);
                default:        val = '0;
            endcase

            // Sign extend 18-bit multiple to 32 bits and shift left by 2*i
            pp[i] = $signed(val) <<< (2 * i);
        end
    end

    // =========================================================================
    // Phase 2: Level 1 Reduction (8 rows -> 4 rows)
    // =========================================================================
    compressor4_2_array #(.WIDTH(32)) u_comp_tree_l1_a (
        .x0    (pp[0]),
        .x1    (pp[1]),
        .x2    (pp[2]),
        .x3    (pp[3]),
        .sum   (s_a),
        .carry (c_a)
    );

    compressor4_2_array #(.WIDTH(32)) u_comp_tree_l1_b (
        .x0    (pp[4]),
        .x1    (pp[5]),
        .x2    (pp[6]),
        .x3    (pp[7]),
        .sum   (s_b),
        .carry (c_b)
    );

    // Optional Pipeline Stage 1 (after Level 1 Reduction)
    generate
        if (PIPELINE_STAGES == 2) begin : gen_pipe_l1
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    s_a_pipe <= '0;
                    c_a_pipe <= '0;
                    s_b_pipe <= '0;
                    c_b_pipe <= '0;
                end else if (en) begin
                    s_a_pipe <= s_a;
                    c_a_pipe <= c_a;
                    s_b_pipe <= s_b;
                    c_b_pipe <= c_b;
                end
            end
        end else begin : gen_bypass_l1
            assign s_a_pipe = s_a;
            assign c_a_pipe = c_a;
            assign s_b_pipe = s_b;
            assign c_b_pipe = c_b;
        end
    endgenerate

    // =========================================================================
    // Phase 3: Level 2 Reduction (4 rows -> 2 rows)
    // =========================================================================
    compressor4_2_array #(.WIDTH(32)) u_comp_tree_l2 (
        .x0    (s_a_pipe),
        .x1    ({c_a_pipe[30:0], 1'b0}),
        .x2    (s_b_pipe),
        .x3    ({c_b_pipe[30:0], 1'b0}),
        .sum   (s_final),
        .carry (c_final)
    );

    // Optional Pipeline Stage 2 (after Level 2 Reduction)
    generate
        if (PIPELINE_STAGES >= 1) begin : gen_pipe_l2
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    s_fin_pipe <= '0;
                    c_fin_pipe <= '0;
                end else if (en) begin
                    s_fin_pipe <= s_final;
                    c_fin_pipe <= c_final;
                end
            end
        end else begin : gen_bypass_l2
            assign s_fin_pipe = s_final;
            assign c_fin_pipe = c_final;
        end
    endgenerate

    // =========================================================================
    // Phase 4: Final Vector Addition using Brent-Kung Adder
    // =========================================================================
    adder_subtractor_bk #(.WIDTH(32)) u_final_adder (
        .a        (s_fin_pipe),
        .b        ({c_fin_pipe[30:0], 1'b0}),
        .sub      (1'b0), // Addition
        .sum      (bk_sum),
        .cout     (bk_cout),
        .overflow (bk_ovf)
    );

    assign p = bk_sum;

endmodule : booth_radix4_multiplier
