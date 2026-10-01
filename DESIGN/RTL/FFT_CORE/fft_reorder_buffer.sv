// =============================================================================
// File Name      : fft_reorder_buffer.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-01
// Version        : 1.0
// Description    : Parameterized Ping-Pong Output Buffer for Decimation-in-Frequency (DIF)
//                  FFT. Reorders bit-reversed frequency bins into sequential natural
//                  order (0, 1, 2, ..., N-1) with 100% streaming throughput.
//                  Provides a frame_done pulse upon completing each full frame.
// =============================================================================

module fft_reorder_buffer #(
    parameter int DATA_W = 32,
    parameter int N      = 32,
    parameter bit BYPASS = 1'b0
)(
    input  logic              clk,
    input  logic              rst_n,
    input  logic              clk_en,

    // Input Stream from FFT Core (Bit-Reversed Order)
    input  logic              valid_in,
    input  logic [DATA_W-1:0] data_in,

    // Output Stream to OUT FIFO (Natural Order: 0, 1, ..., N-1)
    output logic              valid_out,
    output logic [DATA_W-1:0] data_out,

    // Frame Completion Strobe (1 cycle pulse per completed frame)
    output logic              frame_done
);

    localparam int ADDR_W = $clog2(N);

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================
    // Dual Memory Banks for Ping-Pong Buffering
    logic [DATA_W-1:0]        mem_bank0 [N];
    logic [DATA_W-1:0]        mem_bank1 [N];

    // Write-Side Control & Address Signals
    logic [ADDR_W-1:0]        wr_cnt;
    logic [ADDR_W-1:0]        wr_addr_rev;
    logic                     wr_bank;

    // Read-Side Control & Address Signals
    logic [ADDR_W-1:0]        rd_cnt;
    logic                     rd_bank;
    logic                     rd_active;
    logic                     bank0_ready;
    logic                     bank1_ready;

    // Output Staging Signals
    logic                     rd_valid;
    logic [DATA_W-1:0]        rd_data;
    logic                     frame_done_pulse;

    // Bypass Signals
    logic                     bp_frame_done;

    // =========================================================================
    // Bit-Reversal Index Mapping Function
    // =========================================================================
    function automatic logic [ADDR_W-1:0] bit_reverse(input logic [ADDR_W-1:0] in);
        logic [ADDR_W-1:0] rev;
        for (int i = 0; i < ADDR_W; i++) begin
            rev[i] = in[ADDR_W - 1 - i];
        end
        return rev;
    endfunction

    // =========================================================================
    // 1. Write Interface: Store Bit-Reversed Samples into Natural Addresses
    // =========================================================================
    assign wr_addr_rev = bit_reverse(wr_cnt);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_cnt      <= '0;
            wr_bank     <= 1'b0;
            bank0_ready <= 1'b0;
            bank1_ready <= 1'b0;
        end else if (clk_en) begin
            if (valid_in) begin
                // Write into selected memory bank at bit-reversed address
                if (wr_bank == 1'b0) begin
                    mem_bank0[wr_addr_rev] <= data_in;
                end else begin
                    mem_bank1[wr_addr_rev] <= data_in;
                end

                // Frame boundary reached
                if (wr_cnt == ADDR_W'(N - 1)) begin
                    wr_cnt  <= '0;
                    wr_bank <= ~wr_bank;

                    // Mark written bank ready for readout
                    if (wr_bank == 1'b0) begin
                        bank0_ready <= 1'b1;
                    end else begin
                        bank1_ready <= 1'b1;
                    end
                end else begin
                    wr_cnt <= wr_cnt + 1'b1;
                end
            end

            // Clear bank ready flags when readout starts
            if (rd_active && (rd_cnt == '0)) begin
                if (rd_bank == 1'b0) begin
                    bank0_ready <= 1'b0;
                end else begin
                    bank1_ready <= 1'b0;
                end
            end
        end
    end

    // =========================================================================
    // 2. Read Interface: Sequential Natural-Order Readout
    // =========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_cnt           <= '0;
            rd_bank          <= 1'b0;
            rd_active        <= 1'b0;
            frame_done_pulse <= 1'b0;
        end else if (clk_en) begin
            frame_done_pulse <= 1'b0;

            if (!rd_active) begin
                // Start readout whenever a finished bank is available
                if (bank0_ready) begin
                    rd_active <= 1'b1;
                    rd_bank   <= 1'b0;
                    rd_cnt    <= '0;
                end else if (bank1_ready) begin
                    rd_active <= 1'b1;
                    rd_bank   <= 1'b1;
                    rd_cnt    <= '0;
                end
            end else begin
                // Read next natural-order sample
                if (rd_cnt == ADDR_W'(N - 1)) begin
                    rd_cnt           <= '0;
                    frame_done_pulse <= 1'b1;

                    // Check if opposite bank is already ready for back-to-back streaming
                    if (rd_bank == 1'b0 && bank1_ready) begin
                        rd_bank   <= 1'b1;
                        rd_active <= 1'b1;
                    end else if (rd_bank == 1'b1 && bank0_ready) begin
                        rd_bank   <= 1'b0;
                        rd_active <= 1'b1;
                    end else begin
                        rd_active <= 1'b0;
                    end
                end else begin
                    rd_cnt <= rd_cnt + 1'b1;
                end
            end
        end
    end

    // Combinational readout from the active bank
    assign rd_valid = rd_active & clk_en;
    assign rd_data  = (rd_bank == 1'b0) ? mem_bank0[rd_cnt] : mem_bank1[rd_cnt];

    // =========================================================================
    // 3. Bypass / Natural Order Selection
    // =========================================================================
    assign bp_frame_done = (wr_cnt == ADDR_W'(N - 1)) && valid_in && clk_en;

    generate
        if (BYPASS) begin : gen_bypass
            assign valid_out  = valid_in;
            assign data_out   = data_in;
            assign frame_done = bp_frame_done;
        end else begin : gen_reorder
            assign valid_out  = rd_valid;
            assign data_out   = rd_data;
            assign frame_done = frame_done_pulse;
        end
    endgenerate

endmodule : fft_reorder_buffer
