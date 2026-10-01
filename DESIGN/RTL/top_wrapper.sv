// =============================================================================
// File Name      : top_wrapper.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-01
// Version        : 1.0
// Description    : Top-level AHB-Lite system wrapper integrating AHB slave interface,
//                  address decoder, register file, dual-clock asynchronous FIFOs,
//                  reset controller/synchronizers, IP stream controller, bit-reversal
//                  ping-pong reorder buffer (natural order output), hardware DMA
//                  handshaking, and the parameterized Radix-2 DIF R2SDF FFT core.
// =============================================================================

import fft_pkg::*;

module top_wrapper #(
    parameter int          ADDR_W               = 32,
    parameter int          IN_ADDR_W            = 6,      // IN  FIFO depth = 2**6 = 64 words (2 full frames)
    parameter int          OUT_ADDR_W           = 6,      // OUT FIFO depth = 2**6 = 64 words (2 full frames)
    parameter int          HOLD_CYCLES          = 16,     // Reset hold duration in HCLK cycles
    parameter logic [31:0] IP_ID                = 32'h4950_0001,
    parameter logic [31:0] IP_VERSION           = 32'h0001_0000,
    parameter int          FFT_N                = 32,
    parameter int          MULT_PIPE_STAGES     = 0,
    parameter bit          NATURAL_OUTPUT_ORDER = 1'b1    // 1: Natural order (0..N-1), 0: Bit-reversed DIF
)(
    input  logic              HCLK,
    input  logic              HRESETn,
    input  logic              ip_clk,

    // AHB-Lite Slave Interface
    input  logic              HSEL,
    input  logic [ADDR_W-1:0] HADDR,
    input  logic [1:0]        HTRANS,
    input  logic              HWRITE,
    input  logic [2:0]        HSIZE,
    input  logic [31:0]       HWDATA,
    input  logic              HREADY,
    output logic              HREADYOUT,
    output logic [31:0]       HRDATA,
    output logic              HRESP,

    // Interrupt Request Output
    output logic              irq,

    // Hardware DMA Handshake Interface (HCLK Domain)
    output logic              dma_rx_req, // Request DMA to push data into IN FIFO
    output logic              dma_tx_req  // Request DMA to pull data from OUT FIFO
);

    localparam int LVL_W = 16;

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================
    // Simple Register Bus Interface (HCLK Domain)
    logic [ADDR_W-1:0]   bus_addr;
    logic                bus_write;
    logic                bus_wr_en;
    logic                bus_rd_en;
    logic                bus_err;
    logic [31:0]         bus_wdata;
    logic [31:0]         bus_rdata;

    // Register File Bus Interface (HCLK Domain)
    logic [5:0]          reg_addr;
    logic                reg_wr_en;
    logic [31:0]         reg_wdata;
    logic [31:0]         reg_rdata;

    // FIFO Host Push/Pop Interface (HCLK Domain)
    logic                in_push;
    logic                out_pop;
    logic [31:0]         in_wdata;
    logic [31:0]         out_rdata;
    logic                in_full;
    logic                out_empty;

    // FIFO Levels and Status (HCLK Domain)
    logic [IN_ADDR_W:0]  in_wlevel;
    logic [OUT_ADDR_W:0] out_rlevel;

    // Control & Reset Request Signals (HCLK Domain)
    logic                enable;
    logic                req_soft;
    logic                req_flush_in;
    logic                req_flush_out;
    logic                ip_busy_h;
    logic                rst_active;

    // Reset Controller Outputs (HCLK Domain)
    logic                in_rst_n_h;
    logic                out_rst_n_h;
    logic                ip_rst_n_h;

    // Synchronized Resets (ip_clk Domain)
    logic                in_rst_n_i;
    logic                out_rst_n_i;
    logic                ip_rst_n_i;

    // Asynchronous FIFO IP-Side Interconnects (ip_clk Domain)
    logic                in_empty_i;
    logic                out_full_i;
    logic                in_pop_i;
    logic                out_push_i;
    logic [31:0]         in_rdata_i;
    logic [31:0]         out_wdata_i;

    // IP Core Control and Raw Output (ip_clk Domain)
    logic                fft_ce;
    logic                fft_valid_in;
    logic [31:0]         ip_din;
    logic                fft_valid_out;
    logic signed [15:0]  fft_out_re;
    logic signed [15:0]  fft_out_im;
    logic [31:0]         fft_dout;

    // Reorder Buffer Output & Frame Done Events
    logic                ip_vout;
    logic [31:0]         ip_dout;
    logic                ip_busy_i;
    logic                frame_done_i;
    logic                frame_done_h;

    // =========================================================================
    // AHB-Lite Slave
    // =========================================================================
    ahb_slave #(
        .ADDR_W (ADDR_W)
    ) u_ahb (
        .HCLK      (HCLK),
        .HRESETn   (HRESETn),
        .HSEL      (HSEL),
        .HADDR     (HADDR),
        .HTRANS    (HTRANS),
        .HWRITE    (HWRITE),
        .HSIZE     (HSIZE),
        .HWDATA    (HWDATA),
        .HREADY    (HREADY),
        .HREADYOUT (HREADYOUT),
        .HRDATA    (HRDATA),
        .HRESP     (HRESP),
        .bus_addr  (bus_addr),
        .bus_write (bus_write),
        .bus_wdata (bus_wdata),
        .bus_wr_en (bus_wr_en),
        .bus_rd_en (bus_rd_en),
        .bus_rdata (bus_rdata),
        .bus_err   (bus_err)
    );

    // =========================================================================
    // Address Decoder
    // =========================================================================
    addr_decoder #(
        .ADDR_W (ADDR_W)
    ) u_dec (
        .bus_addr  (bus_addr),
        .bus_write (bus_write),
        .bus_wdata (bus_wdata),
        .bus_wr_en (bus_wr_en),
        .bus_rd_en (bus_rd_en),
        .bus_rdata (bus_rdata),
        .bus_err   (bus_err),
        .reg_addr  (reg_addr),
        .reg_wr_en (reg_wr_en),
        .reg_wdata (reg_wdata),
        .reg_rdata (reg_rdata),
        .in_push   (in_push),
        .in_wdata  (in_wdata),
        .out_pop   (out_pop),
        .out_rdata (out_rdata),
        .out_empty (out_empty)
    );
    // =========================================================================
    // System Controller 
    // =========================================================================
    fft_sys_ctrl #(
        .DATA_W (32)
    ) u_ctrl (
        .clk          (ip_clk),
        .rst_n        (ip_rst_n_i),
        .enable       (enable),
        .in_empty     (in_empty_i),
        .in_rdata     (in_rdata_i),
        .in_pop       (in_pop_i),
        .out_full     (out_full_i),
        .out_push     (out_push_i),
        .out_wdata    (out_wdata_i),
        .ip_ce        (fft_ce),
        .ip_valid_in  (fft_valid_in),
        .ip_data_in   (ip_din),
        .ip_valid_out (ip_vout),
        .ip_data_out  (ip_dout),
        .busy         (ip_busy_i)
    );

    // =========================================================================
    // Reset Controller (HCLK Domain)
    // =========================================================================
    rst_ctrl #(
        .HOLD (HOLD_CYCLES)
    ) u_rst (
        .clk           (HCLK),
        .rst_n         (HRESETn),
        .req_soft      (req_soft),
        .req_flush_in  (req_flush_in),
        .req_flush_out (req_flush_out),
        .in_rst_n      (in_rst_n_h),
        .out_rst_n     (out_rst_n_h),
        .ip_rst_n      (ip_rst_n_h),
        .active        (rst_active)
    );

    // =========================================================================
    // Register File
    // =========================================================================
    reg_file #(
        .ID        (IP_ID),
        .VERSION   (IP_VERSION),
        .LVL_W     (LVL_W),
        .IN_DEPTH  (1 << IN_ADDR_W),
        .OUT_DEPTH (1 << OUT_ADDR_W)
    ) u_rf (
        .clk              (HCLK),
        .rst_n            (HRESETn),
        .reg_addr         (reg_addr),
        .reg_wr_en        (reg_wr_en),
        .reg_wdata        (reg_wdata),
        .reg_rdata        (reg_rdata),
        .rst_active       (rst_active),
        .ip_busy          (ip_busy_h),
        .in_full          (in_full),
        .out_empty        (out_empty),
        .in_level         (LVL_W'(in_wlevel)),
        .out_level        (LVL_W'(out_rlevel)),
        .ev_in_overflow   (in_push & in_full),
        .ev_out_underflow (out_pop & out_empty),
        .ev_frame_done    (frame_done_h),
        .enable           (enable),
        .soft_reset_req   (req_soft),
        .flush_in_req     (req_flush_in),
        .flush_out_req    (req_flush_out),
        .irq              (irq),
        .dma_rx_req       (dma_rx_req),
        .dma_tx_req       (dma_tx_req)
    );

    // =========================================================================
    // Asynchronous FIFOs
    // =========================================================================
        // =========================================================================
        // Input FIFO (SoC >> IP Slave)
        // =========================================================================
        async_fifo #(
            .DATA_W (32),
            .ADDR_W (IN_ADDR_W)
        ) u_in_fifo (
            .wclk   (HCLK),
            .wrst_n (in_rst_n_h),
            .winc   (in_push),
            .wdata  (in_wdata),
            .wfull  (in_full),
            .wlevel (in_wlevel),
            .rclk   (ip_clk),
            .rrst_n (in_rst_n_i),
            .rinc   (in_pop_i),
            .rdata  (in_rdata_i),
            .rempty (in_empty_i),
            .rlevel ()
        );

        // =========================================================================
        // Output FIFO (IP Slave >> SoC)
        // =========================================================================
        async_fifo #(
            .DATA_W (32),
            .ADDR_W (OUT_ADDR_W)
        ) u_out_fifo (
            .wclk   (ip_clk),
            .wrst_n (out_rst_n_i),
            .winc   (out_push_i),
            .wdata  (out_wdata_i),
            .wfull  (out_full_i),
            .wlevel (),
            .rclk   (HCLK),
            .rrst_n (out_rst_n_h),
            .rinc   (out_pop),
            .rdata  (out_rdata),
            .rempty (out_empty),
            .rlevel (out_rlevel)
        );

    // =========================================================================
    // N FFT Core 
    // =========================================================================
    fft_top #(
        .N                (FFT_N),
        .MULT_PIPE_STAGES (MULT_PIPE_STAGES)
    ) u_fft_core (
        .clk         (ip_clk),
        .rst_n       (ip_rst_n_i),
        .clk_en      (fft_ce),
        .valid_in    (fft_valid_in),
        .in_data_re  (signed'(ip_din[31:16])),
        .in_data_im  (signed'(ip_din[15:0])),
        .valid_out   (fft_valid_out),
        .out_data_re (fft_out_re),
        .out_data_im (fft_out_im)
    );

    assign fft_dout = {fft_out_re, fft_out_im};

    // =========================================================================
    // Output Bit-Reversal / Natural-Order 
    // =========================================================================
    fft_reorder_buffer #(
        .DATA_W (32),
        .N      (FFT_N),
        .BYPASS (~NATURAL_OUTPUT_ORDER)
    ) u_reorder_buf (
        .clk        (ip_clk),
        .rst_n      (ip_rst_n_i),
        .clk_en     (fft_ce),
        .valid_in   (fft_valid_out),
        .data_in    (fft_dout),
        .valid_out  (ip_vout),
        .data_out   (ip_dout),
        .frame_done (frame_done_i)
    );

    // =========================================================================
    // Synchronizers
    // =========================================================================
        // =========================================================================
        // Asynchronous Reset Synchronizers (HCLK -> ip_clk Domain)
        // =========================================================================
        reset_sync u_rs_in  (.clk(ip_clk), .arst_n(in_rst_n_h),  .srst_n(in_rst_n_i));
        reset_sync u_rs_out (.clk(ip_clk), .arst_n(out_rst_n_h), .srst_n(out_rst_n_i));
        reset_sync u_rs_ip  (.clk(ip_clk), .arst_n(ip_rst_n_h),  .srst_n(ip_rst_n_i));

        // =========================================================================
        // Frame-Done Synchronizer (ip_clk -> HCLK Domain)
        // =========================================================================
        pulse_sync #(
            .SYNC_STAGES (2)
        ) u_frame_sync (
            .src_clk   (ip_clk),
            .src_rst_n (ip_rst_n_i),
            .src_pulse (frame_done_i),
            .dst_clk   (HCLK),
            .dst_rst_n (HRESETn),
            .dst_pulse (frame_done_h)
        );

        // =========================================================================
        // Status Synchronization (ip_clk -> HCLK Domain)
        // =========================================================================
        bit_sync #(
            .WIDTH (1)
        ) u_busy_sync (
            .clk   (HCLK),
            .rst_n (HRESETn),
            .d     (ip_busy_i),
            .q     (ip_busy_h)
        );
        

endmodule : top_wrapper
