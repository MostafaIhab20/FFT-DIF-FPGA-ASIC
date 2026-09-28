// =============================================================================
// File Name      : adder_subtractor_bk.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-09-27
// Version        : 1.0
// Description    : Parameterized Parallel-Prefix Brent-Kung Unified Adder/Subtractor.
//                  Computes:
//                    sub = 0: Sum = A + B
//                    sub = 1: Sum = A - B (Two's complement: A + ~B + 1)
//                  Features:
//                    - Brent-Kung prefix tree with O(log N) depth and bounded fan-out (<= 2)
//                    - Minimal routing track congestion for ASIC PnR
//                    - Unified carry-in injection at bit 0
//                    - Carry-out and signed overflow detection
// =============================================================================

`timescale 1ns / 1ps

module adder_subtractor_bk #(
    parameter int WIDTH = 18
)(
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic             sub,      // 0: A + B, 1: A - B
    output logic [WIDTH-1:0] sum,
    output logic             cout,     // Carry-out / No-borrow
    output logic             overflow  // Signed overflow flag
);

    // Compute power-of-2 dimensions for prefix network
    localparam int N = (WIDTH > 1) ? (1 << $clog2(WIDTH)) : 2;
    localparam int L = $clog2(N);

    // -------------------------------------------------------------------------
    // 1. Pre-Processing Phase: Generate (G) and Propagate (P)
    // -------------------------------------------------------------------------
    logic [N-1:0] a_ext;
    logic [N-1:0] b_ext;
    logic [N-1:0] p_orig;

    // Bit-0 absorbs the carry-in (sub) directly:
    //   g_init[0] = (a0 & b0') | ((a0 ^ b0') & cin)  --> Exact carry into bit 1!
    //   p_init[0] = 0                                --> Absorbed, prevents further propagation
    logic [N-1:0] g_init;
    logic [N-1:0] p_init;

    always_comb begin
        a_ext  = '0;
        b_ext  = '0;
        p_orig = '0;
        g_init = '0;
        p_init = '0;

        for (int i = 0; i < WIDTH; i++) begin
            a_ext[i]  = a[i];
            b_ext[i]  = b[i] ^ sub;
            p_orig[i] = a[i] ^ (b[i] ^ sub);

            if (i == 0) begin
                g_init[0] = (a[0] & (b[0] ^ sub)) | (p_orig[0] & sub);
                p_init[0] = 1'b0;
            end else begin
                g_init[i] = a[i] & (b[i] ^ sub);
                p_init[i] = p_orig[i];
            end
        end
    end

    // -------------------------------------------------------------------------
    // 2. Brent-Kung Forward Reduction Tree (Up-Tree: L levels)
    // -------------------------------------------------------------------------
    logic [N-1:0] g_up [0:L];
    logic [N-1:0] p_up [0:L];

    assign g_up[0] = g_init;
    assign p_up[0] = p_init;

    generate
        for (genvar s = 0; s < L; s++) begin : gen_up_levels
            localparam int STEP     = 1 << s;
            localparam int TWO_STEP = 1 << (s + 1);

            for (genvar i = 0; i < N; i++) begin : gen_up_nodes
                if (((i + 1) % TWO_STEP) == 0) begin : gen_combine
                    assign g_up[s+1][i] = g_up[s][i] | (p_up[s][i] & g_up[s][i - STEP]);
                    assign p_up[s+1][i] = p_up[s][i] & p_up[s][i - STEP];
                end else begin : gen_pass
                    assign g_up[s+1][i] = g_up[s][i];
                    assign p_up[s+1][i] = p_up[s][i];
                end
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // 3. Brent-Kung Reverse Distribution Tree (Down-Tree: L-1 levels)
    // -------------------------------------------------------------------------
    logic [N-1:0] g_down [0:L];
    logic [N-1:0] p_down [0:L];

    assign g_down[0] = g_up[L];
    assign p_down[0] = p_up[L];

    generate
        if (L <= 1) begin : gen_trivial_down
            assign g_down[1] = g_down[0];
            assign p_down[1] = p_down[0];
        end else begin : gen_down_levels
            for (genvar d = 0; d < L - 1; d++) begin : gen_d_stage
                localparam int S        = L - 2 - d;
                localparam int STEP     = 1 << S;
                localparam int TWO_STEP = 1 << (S + 1);

                for (genvar i = 0; i < N; i++) begin : gen_down_nodes
                    if ((i >= 3 * STEP - 1) && (((i + 1 - STEP) % TWO_STEP) == 0)) begin : gen_d_combine
                        assign g_down[d+1][i] = g_down[d][i] | (p_down[d][i] & g_down[d][i - STEP]);
                        assign p_down[d+1][i] = p_down[d][i] & p_down[d][i - STEP];
                    end else begin : gen_d_pass
                        assign g_down[d+1][i] = g_down[d][i];
                        assign p_down[d+1][i] = p_down[d][i];
                    end
                end
            end
        end
    endgenerate

    // Final prefix generate signals (carries)
    logic [N-1:0] g_final;
    assign g_final = (L <= 1) ? g_down[1] : g_down[L-1];

    // -------------------------------------------------------------------------
    // 4. Post-Processing Phase: Sum, Carry-Out, and Overflow
    // -------------------------------------------------------------------------
    logic [WIDTH-1:0] c_in_bit;

    always_comb begin
        c_in_bit[0] = sub;
        for (int i = 1; i < WIDTH; i++) begin
            c_in_bit[i] = g_final[i-1];
        end

        for (int i = 0; i < WIDTH; i++) begin
            sum[i] = p_orig[i] ^ c_in_bit[i];
        end
    end

    assign cout = g_final[WIDTH-1];

    // Signed overflow flag:
    // Occurs if sign(A) == sign(B') and sign(Sum) != sign(A)
    assign overflow = (a[WIDTH-1] == b_ext[WIDTH-1]) && (sum[WIDTH-1] != a[WIDTH-1]);

endmodule : adder_subtractor_bk
