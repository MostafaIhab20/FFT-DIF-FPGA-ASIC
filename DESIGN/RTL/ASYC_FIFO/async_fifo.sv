// =============================================================================
// File Name      : async_fifo.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-01
// Version        : 1.0
// Description    : Parameterized dual-clock asynchronous FIFO with Gray-coded
//                  pointers, First-Word Fall-Through (FWFT) read semantics,
//                  and conservative level estimation in both clock domains.
// =============================================================================

module async_fifo #(
    parameter int DATA_W      = 32,
    parameter int ADDR_W      = 4,
    parameter int SYNC_STAGES = 2
)(
    // Write Interface (wclk Domain)
    input  logic              wclk,
    input  logic              wrst_n,
    input  logic              winc,
    input  logic [DATA_W-1:0] wdata,
    output logic              wfull,
    output logic [ADDR_W:0]   wlevel,

    // Read Interface (rclk Domain)
    input  logic              rclk,
    input  logic              rrst_n,
    input  logic              rinc,
    output logic [DATA_W-1:0] rdata,
    output logic              rempty,
    output logic [ADDR_W:0]   rlevel
);

    localparam int DEPTH = 1 << ADDR_W;

    // =========================================================================
    // Internal Signal Declarations
    // =========================================================================
    // Dual-Port RAM Memory Storage (Read Combinationally for FWFT)
    logic [DATA_W-1:0] mem [DEPTH];

    // Write-Domain Pointer & Status Signals
    logic [ADDR_W:0]   wbin;
    logic [ADDR_W:0]   wbin_nxt;
    logic [ADDR_W:0]   wgray;
    logic [ADDR_W:0]   wgray_nxt;
    logic              wfull_nxt;
    logic              wen;

    // Read-Domain Pointer & Status Signals
    logic [ADDR_W:0]   rbin;
    logic [ADDR_W:0]   rbin_nxt;
    logic [ADDR_W:0]   rgray;
    logic [ADDR_W:0]   rgray_nxt;
    logic              rempty_nxt;
    logic              ren;

    // Synchronized Pointers Across Clock Domains
    logic [ADDR_W:0]   rgray_wsync; // Read Gray pointer synchronized into wclk domain
    logic [ADDR_W:0]   wgray_rsync; // Write Gray pointer synchronized into rclk domain

    // =========================================================================
    // Functions: Binary to Gray and Gray to Binary Conversions
    // =========================================================================
    function automatic logic [ADDR_W:0] bin2gray(input logic [ADDR_W:0] b);
        return (b >> 1) ^ b;
    endfunction

    function automatic logic [ADDR_W:0] gray2bin(input logic [ADDR_W:0] g);
        logic [ADDR_W:0] b;
        b[ADDR_W] = g[ADDR_W];
        for (int i = ADDR_W-1; i >= 0; i--) begin
            b[i] = b[i+1] ^ g[i];
        end
        return b;
    endfunction

    // =========================================================================
    // 1. Write Interface Logic (wclk Domain)
    // =========================================================================
    assign wen       = winc & ~wfull;
    assign wbin_nxt  = wbin + (ADDR_W+1)'(wen);
    assign wgray_nxt = bin2gray(wbin_nxt);

    // Full condition: next write Gray equals read Gray with top two MSBs inverted
    assign wfull_nxt = (wgray_nxt == {~rgray_wsync[ADDR_W:ADDR_W-1], rgray_wsync[ADDR_W-2:0]});

    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin  <= '0;
            wgray <= '0;
            wfull <= 1'b0;
        end else begin
            wbin  <= wbin_nxt;
            wgray <= wgray_nxt;
            wfull <= wfull_nxt;
        end
    end

    // Synchronous memory write
    always_ff @(posedge wclk) begin
        if (wen) begin
            mem[wbin[ADDR_W-1:0]] <= wdata;
        end
    end

    // Conservative write-domain level (delayed read pointer => wlevel >= actual level)
    always_ff @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wlevel <= '0;
        end else begin
            wlevel <= wbin_nxt - gray2bin(rgray_wsync);
        end
    end

    // =========================================================================
    // 2. Read Interface Logic (rclk Domain)
    // =========================================================================
    assign ren        = rinc & ~rempty;
    assign rbin_nxt   = rbin + (ADDR_W+1)'(ren);
    assign rgray_nxt  = bin2gray(rbin_nxt);
    assign rempty_nxt = (rgray_nxt == wgray_rsync);

    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin   <= '0;
            rgray  <= '0;
            rempty <= 1'b1;
        end else begin
            rbin   <= rbin_nxt;
            rgray  <= rgray_nxt;
            rempty <= rempty_nxt;
        end
    end

    // Combinational First-Word Fall-Through (FWFT) read output
    assign rdata = mem[rbin[ADDR_W-1:0]];

    // Conservative read-domain level (delayed write pointer => rlevel <= actual level)
    always_ff @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rlevel <= '0;
        end else begin
            rlevel <= gray2bin(wgray_rsync) - rbin_nxt;
        end
    end

    // =========================================================================
    // 3. Clock Domain Crossing Synchronizers for Gray Pointers
    // =========================================================================
    bit_sync #(
        .WIDTH  (ADDR_W+1),
        .STAGES (SYNC_STAGES)
    ) u_sync_r2w (
        .clk   (wclk),
        .rst_n (wrst_n),
        .d     (rgray),
        .q     (rgray_wsync)
    );

    bit_sync #(
        .WIDTH  (ADDR_W+1),
        .STAGES (SYNC_STAGES)
    ) u_sync_w2r (
        .clk   (rclk),
        .rst_n (rrst_n),
        .d     (wgray),
        .q     (wgray_rsync)
    );

endmodule : async_fifo
