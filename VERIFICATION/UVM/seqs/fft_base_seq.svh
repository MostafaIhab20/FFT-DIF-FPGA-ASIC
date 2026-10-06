// =============================================================================
// File Name      : fft_base_seq.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Base sequence providing reusable AHB bus access routines
//                  for registers and FIFO sample streaming.
// =============================================================================

`ifndef FFT_BASE_SEQ_SVH
`define FFT_BASE_SEQ_SVH

class fft_base_seq extends uvm_sequence #(ahb_seq_item);

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(fft_base_seq)

    // ==================================================
    // Memory Map Register Offsets
    // ==================================================
    localparam bit [31:0] ADDR_ID         = 32'h000;
    localparam bit [31:0] ADDR_VERSION    = 32'h004;
    localparam bit [31:0] ADDR_CTRL       = 32'h008;
    localparam bit [31:0] ADDR_STATUS     = 32'h00C;
    localparam bit [31:0] ADDR_INT_EN     = 32'h010;
    localparam bit [31:0] ADDR_INT_STATUS = 32'h014;
    localparam bit [31:0] ADDR_IN_LEVEL   = 32'h018;
    localparam bit [31:0] ADDR_OUT_LEVEL  = 32'h01C;
    localparam bit [31:0] ADDR_IN_THRESH  = 32'h020;
    localparam bit [31:0] ADDR_OUT_THRESH = 32'h024;
    localparam bit [31:0] ADDR_FIFO_DATA  = 32'h100;

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_base_seq");
        super.new(name);
    endfunction

    // ==================================================
    // Raw Bus Access Tasks
    // ==================================================
    // Raw AHB Write Transaction
    virtual task write_bus(
        input bit [31:0]   target_addr,
        input bit [31:0]   wr_data,
        input int unsigned wait_cycles = 0,
        input ahb_size_e   transfer_size = HSIZE_WORD
    );
        req = ahb_seq_item::type_id::create("req");
        start_item(req);
        if (!req.randomize() with {
            req.addr        == target_addr;
            req.data        == wr_data;
            req.write       == 1'b1;
            req.size        == transfer_size;
            req.wait_cycles == wait_cycles;
        }) begin
            `uvm_fatal("BASE_SEQ", "Randomization failed for write_bus")
        end
        finish_item(req);
    endtask

    // Raw AHB Read Transaction
    virtual task read_bus(
        input  bit [31:0]   target_addr,
        output bit [31:0]   rd_data,
        input  int unsigned wait_cycles = 0,
        input  ahb_size_e   transfer_size = HSIZE_WORD
    );
        req = ahb_seq_item::type_id::create("req");
        start_item(req);
        if (!req.randomize() with {
            req.addr        == target_addr;
            req.write       == 1'b0;
            req.size        == transfer_size;
            req.wait_cycles == wait_cycles;
        }) begin
            `uvm_fatal("BASE_SEQ", "Randomization failed for read_bus")
        end
        finish_item(req);
        rd_data = req.data;
    endtask

    // ==================================================
    // Register Convenience Tasks
    // ==================================================
    virtual task write_reg(input bit [31:0] offset, input bit [31:0] data);
        write_bus(offset, data);
    endtask

    virtual task read_reg(input bit [31:0] offset, output bit [31:0] data);
        read_bus(offset, data);
    endtask

    // ==================================================
    // FIFO Sample Streaming Tasks
    // ==================================================
    virtual task push_sample(input bit [31:0] sample);
        write_bus(ADDR_FIFO_DATA, sample);
    endtask

    virtual task pop_sample(output bit [31:0] sample);
        read_bus(ADDR_FIFO_DATA, sample);
    endtask

    // Burst AHB Write Transaction
    virtual task write_burst(
        input bit [31:0]   target_addr,
        input bit [31:0]   wr_data[],
        input ahb_burst_e  burst_mode,
        input int unsigned wait_cycles = 0,
        input ahb_size_e   transfer_size = HSIZE_WORD
    );
        req = ahb_seq_item::type_id::create("req");
        start_item(req);
        if (!req.randomize() with {
            req.addr        == target_addr;
            req.burst       == burst_mode;
            req.burst_len   == wr_data.size();
            req.write       == 1'b1;
            req.size        == transfer_size;
            req.wait_cycles == wait_cycles;
        }) begin
            `uvm_fatal("BASE_SEQ", "Randomization failed for write_burst")
        end
        req.burst_data = wr_data;
        if (wr_data.size() > 0) begin
            req.data = wr_data[0];
        end
        finish_item(req);
    endtask

    // Burst AHB Read Transaction
    virtual task read_burst(
        input  bit [31:0]   target_addr,
        output bit [31:0]   rd_data[],
        input  ahb_burst_e  burst_mode,
        input  int unsigned burst_length,
        input  int unsigned wait_cycles = 0,
        input  ahb_size_e   transfer_size = HSIZE_WORD
    );
        req = ahb_seq_item::type_id::create("req");
        start_item(req);
        if (!req.randomize() with {
            req.addr        == target_addr;
            req.burst       == burst_mode;
            req.burst_len   == burst_length;
            req.write       == 1'b0;
            req.size        == transfer_size;
            req.wait_cycles == wait_cycles;
        }) begin
            `uvm_fatal("BASE_SEQ", "Randomization failed for read_burst")
        end
        finish_item(req);
        rd_data = req.burst_data;
    endtask

    // Burst FIFO Streaming Tasks
    virtual task push_samples_burst(
        input bit [31:0]  samples[],
        input ahb_burst_e burst = HBURST_INCR4
    );
        write_burst(ADDR_FIFO_DATA, samples, burst);
    endtask

    virtual task pop_samples_burst(
        output bit [31:0]   samples[],
        input  int unsigned len,
        input  ahb_burst_e  burst = HBURST_INCR4
    );
        read_burst(ADDR_FIFO_DATA, samples, burst, len);
    endtask

    // ==================================================
    // Synchronization & Polling Tasks
    // ==================================================
    // Poll STATUS register until core is IDLE
    virtual task wait_for_idle(input int max_polls = 1000);
        bit [31:0] status_val;
        int count = 0;
        do begin
            read_reg(ADDR_STATUS, status_val);
            count++;
            if (count > max_polls) begin
                `uvm_error("BASE_SEQ", "Timeout waiting for FFT core IDLE state")
                return;
            end
        end while (status_val[0] !== 1'b0);
    endtask

    // Poll until OUT FIFO contains at least required number of samples
    virtual task wait_for_out_level(input int target_level, input int max_polls = 1000);
        bit [31:0] level;
        int count = 0;
        do begin
            read_reg(ADDR_OUT_LEVEL, level);
            count++;
            if (count > max_polls) begin
                `uvm_error("BASE_SEQ", $sformatf("Timeout waiting for OUT FIFO level >= %0d", target_level))
                return;
            end
        end while (level < target_level);
    endtask

endclass : fft_base_seq

`endif // FFT_BASE_SEQ_SVH
