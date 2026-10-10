// =============================================================================
// File Name      : fft_base_vseq.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-09
// Version        : 1.0
// Description    : Base virtual sequence executing across the virtual sequencer
//                  sub-sequencer hierarchy (AHB driver & sideband reactive sinks).
// =============================================================================

`ifndef FFT_BASE_VSEQ_SVH
`define FFT_BASE_VSEQ_SVH

class fft_base_vseq extends uvm_sequence #(uvm_sequence_item);

    // ==================================================
    // Factory Registration & P_SEQUENCER Hook
    // ==================================================
    `uvm_object_utils(fft_base_vseq)
    `uvm_declare_p_sequencer(fft_virtual_sequencer)

    // ==================================================
    // Sub-sequencer & RAL Handles
    // ==================================================
    ahb_sequencer       ahb_sqr;
    sideband_sequencer  sb_sqr;
    fft_reg_block       reg_model;

    // Memory Map Constants
    localparam bit [31:0] ADDR_ID         = 32'h000;
    localparam bit [31:0] ADDR_VERSION    = 32'h004;
    localparam bit [31:0] ADDR_CTRL       = 32'h008;
    localparam bit [31:0] ADDR_STATUS     = 32'h00C;
    localparam bit [31:0] ADDR_INT_STATUS = 32'h014;
    localparam bit [31:0] ADDR_IN_LEVEL   = 32'h018;
    localparam bit [31:0] ADDR_OUT_LEVEL  = 32'h01C;
    localparam bit [31:0] ADDR_FIFO_DATA  = 32'h100;

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_base_vseq");
        super.new(name);
    endfunction

    // ==================================================
    // Pre-Body
    // ==================================================
    virtual task pre_body();
        super.pre_body();
        if (p_sequencer != null) begin
            ahb_sqr   = p_sequencer.ahb_sqr;
            sb_sqr    = p_sequencer.sb_sqr;
            reg_model = p_sequencer.reg_model;
        end
    endtask

    // ==================================================
    // Raw AHB Transaction Tasks
    // ==================================================
    virtual task write_bus(
        input  bit [31:0]   target_addr,
        input  bit [31:0]   wr_data,
        output ahb_resp_e   resp,
        input  int unsigned wait_cycles   = 0,
        input  ahb_size_e   transfer_size = HSIZE_WORD
    );
        ahb_seq_item req = ahb_seq_item::type_id::create("req");
        start_item(req, -1, ahb_sqr);
        if (!req.randomize() with {
            req.addr        == target_addr;
            req.data        == wr_data;
            req.write       == 1'b1;
            req.size        == transfer_size;
            req.wait_cycles == wait_cycles;
            req.burst       == HBURST_SINGLE;
            req.trans       == HTRANS_NONSEQ;
            req.sel         == 1'b1;
        }) begin
            `uvm_fatal("BASE_VSEQ", "Randomization failed for write_bus")
        end
        finish_item(req);
        resp = req.resp;
    endtask

    virtual task read_bus(
        input  bit [31:0]   target_addr,
        output bit [31:0]   rd_data,
        output ahb_resp_e   resp,
        input  int unsigned wait_cycles   = 0,
        input  ahb_size_e   transfer_size = HSIZE_WORD
    );
        ahb_seq_item req = ahb_seq_item::type_id::create("req");
        start_item(req, -1, ahb_sqr);
        if (!req.randomize() with {
            req.addr        == target_addr;
            req.write       == 1'b0;
            req.size        == transfer_size;
            req.wait_cycles == wait_cycles;
            req.burst       == HBURST_SINGLE;
            req.trans       == HTRANS_NONSEQ;
            req.sel         == 1'b1;
        }) begin
            `uvm_fatal("BASE_VSEQ", "Randomization failed for read_bus")
        end
        finish_item(req);
        rd_data = req.data;
        resp    = req.resp;
    endtask

    virtual task write_burst(
        input bit [31:0]   target_addr,
        input bit [31:0]   wr_data[],
        input ahb_burst_e  burst_mode,
        input int unsigned wait_cycles   = 0,
        input ahb_size_e   transfer_size = HSIZE_WORD
    );
        ahb_seq_item req = ahb_seq_item::type_id::create("req");
        start_item(req, -1, ahb_sqr);
        if (!req.randomize() with {
            req.addr        == target_addr;
            req.burst       == burst_mode;
            req.burst_len   == wr_data.size();
            req.write       == 1'b1;
            req.size        == transfer_size;
            req.wait_cycles == wait_cycles;
        }) begin
            `uvm_fatal("BASE_VSEQ", "Randomization failed for write_burst")
        end
        req.burst_data = wr_data;
        if (wr_data.size() > 0) req.data = wr_data[0];
        finish_item(req);
    endtask

    virtual task read_burst(
        input  bit [31:0]   target_addr,
        output bit [31:0]   rd_data[],
        input  ahb_burst_e  burst_mode,
        input  int unsigned burst_length,
        input  int unsigned wait_cycles   = 0,
        input  ahb_size_e   transfer_size = HSIZE_WORD
    );
        ahb_seq_item req = ahb_seq_item::type_id::create("req");
        start_item(req, -1, ahb_sqr);
        if (!req.randomize() with {
            req.addr        == target_addr;
            req.burst       == burst_mode;
            req.burst_len   == burst_length;
            req.write       == 1'b0;
            req.size        == transfer_size;
            req.wait_cycles == wait_cycles;
        }) begin
            `uvm_fatal("BASE_VSEQ", "Randomization failed for read_burst")
        end
        finish_item(req);
        rd_data = req.burst_data;
    endtask

    // ==================================================
    // FIFO Streaming Tasks
    // ==================================================
    virtual task push_sample(input bit [31:0] sample);
        ahb_resp_e dummy_resp;
        write_bus(ADDR_FIFO_DATA, sample, dummy_resp);
    endtask

    virtual task pop_sample(output bit [31:0] sample);
        ahb_resp_e dummy_resp;
        read_bus(ADDR_FIFO_DATA, sample, dummy_resp);
    endtask

    virtual task push_samples_burst(
        input bit [31:0]  samples[],
        input ahb_burst_e burst = HBURST_INCR
    );
        write_burst(ADDR_FIFO_DATA, samples, burst);
    endtask

    virtual task pop_samples_burst(
        output bit [31:0]   samples[],
        input  int unsigned len   = 32,
        input  ahb_burst_e  burst = HBURST_INCR
    );
        read_burst(ADDR_FIFO_DATA, samples, burst, len);
    endtask

    // ==================================================
    // Reactive Sideband Tasks
    // ==================================================
    virtual task wait_for_irq(bit exp_val = 1'b1, time timeout = 100us);
        sideband_wait_irq_seq seq = sideband_wait_irq_seq::type_id::create("wait_irq_seq");
        seq.expected_val = exp_val;
        seq.timeout      = timeout;
        seq.start(sb_sqr);
    endtask

    virtual task wait_for_dma_rx(bit exp_val = 1'b1, time timeout = 100us);
        sideband_wait_dma_rx_seq seq = sideband_wait_dma_rx_seq::type_id::create("wait_dma_rx_seq");
        seq.expected_val = exp_val;
        seq.timeout      = timeout;
        seq.start(sb_sqr);
    endtask

    virtual task wait_for_dma_tx(bit exp_val = 1'b1, time timeout = 100us);
        sideband_wait_dma_tx_seq seq = sideband_wait_dma_tx_seq::type_id::create("wait_dma_tx_seq");
        seq.expected_val = exp_val;
        seq.timeout      = timeout;
        seq.start(sb_sqr);
    endtask
    
    // ==================================================
    // Synchronization & Polling Tasks
    // ==================================================
    virtual task wait_for_idle(input int max_polls = 1000);
        uvm_status_e   status;
        uvm_reg_data_t status_val;
        ahb_resp_e     resp;
        int count = 0;

        do begin
            if (reg_model != null && reg_model.reg_status != null) begin
                reg_model.reg_status.read(status, status_val);
            end else begin
                read_bus(ADDR_STATUS, status_val[31:0], resp);
            end
            count++;
            if (count > max_polls) begin
                `uvm_error("BASE_VSEQ", "Timeout waiting for FFT core IDLE state")
                return;
            end
        end while (status_val[0] !== 1'b0);
    endtask

    virtual task wait_for_out_level(input int target_level, input int max_polls = 1000);
        uvm_status_e   status;
        uvm_reg_data_t level_val;
        ahb_resp_e     resp;
        int count = 0;

        do begin
            if (reg_model != null && reg_model.reg_out_level != null) begin
                reg_model.reg_out_level.read(status, level_val);
            end else begin
                read_bus(ADDR_OUT_LEVEL, level_val[31:0], resp);
            end
            count++;
            if (count > max_polls) begin
                `uvm_error("BASE_VSEQ", $sformatf("Timeout waiting for OUT FIFO level >= %0d", target_level))
                return;
            end
        end while (level_val < target_level);
    endtask

    virtual task idle_cycles(input int cycles = 10);
        repeat (cycles) begin
            ahb_seq_item req = ahb_seq_item::type_id::create("req");
            start_item(req, -1, ahb_sqr);
            if (!req.randomize() with {
                req.trans == HTRANS_IDLE;
                req.sel   == 1'b0;
                req.burst == HBURST_SINGLE;
            }) begin
                `uvm_fatal("BASE_VSEQ", "Randomization failed for idle_cycles")
            end
            finish_item(req);
        end
    endtask

    // ==================================================
    // Interrupt Handler Tasks
    // ==================================================
    virtual task handle_frame_done();
        uvm_status_e   status;
        bit [31:0]     popped_frame[];
        uvm_reg_data_t rdata;
        ahb_resp_e     dummy_resp;

        // Drain 32 output samples from OUT FIFO via INCR burst
        pop_samples_burst(popped_frame, 32, HBURST_INCR);

        // Clear FRAME_DONE interrupt via RAL (W1C bit 0)
        if (reg_model != null && reg_model.reg_int_status != null) begin
            reg_model.reg_int_status.write(status, 32'h01);
        end else begin
            write_bus(ADDR_INT_STATUS, 32'h01, dummy_resp);
        end

        // Verify status bit cleared
        if (reg_model != null && reg_model.reg_int_status != null) begin
            reg_model.reg_int_status.read(status, rdata);
            if (rdata[0] !== 1'b0) begin
                `uvm_error("BASE_VSEQ", "FRAME_DONE bit failed to clear after W1C write!")
            end
        end
    endtask

    virtual task handle_overflow();
        uvm_status_e   status;
        uvm_reg_data_t rdata;
        ahb_resp_e     dummy_resp;

        `uvm_info("BASE_VSEQ", "Handling IN_OVERFLOW interrupt: Flushing IN FIFO and clearing flag...", UVM_MEDIUM)

        // Flush IN FIFO via CTRL[30]
        if (reg_model != null && reg_model.reg_ctrl != null) begin
            reg_model.reg_ctrl.write(status, 32'h4000_0001);
            repeat (20) reg_model.reg_status.read(status, rdata);
        end else begin
            write_bus(ADDR_CTRL, 32'h4000_0001, dummy_resp);
            repeat (20) read_bus(ADDR_STATUS, rdata[31:0], dummy_resp);
        end

        // Clear IN_OVERFLOW flag via RAL (W1C bit 1)
        if (reg_model != null && reg_model.reg_int_status != null) begin
            reg_model.reg_int_status.write(status, 32'h02);
        end else begin
            write_bus(ADDR_INT_STATUS, 32'h02, dummy_resp);
        end
    endtask

    virtual task handle_underflow();
        uvm_status_e   status;
        uvm_reg_data_t rdata;
        ahb_resp_e     dummy_resp;

        `uvm_info("BASE_VSEQ", "Handling OUT_UNDERFLOW interrupt: Flushing OUT FIFO and clearing flag...", UVM_MEDIUM)

        // Flush OUT FIFO via CTRL[31]
        if (reg_model != null && reg_model.reg_ctrl != null) begin
            reg_model.reg_ctrl.write(status, 32'h8000_0001);
            repeat (20) reg_model.reg_status.read(status, rdata);
        end else begin
            write_bus(ADDR_CTRL, 32'h8000_0001, dummy_resp);
            repeat (20) read_bus(ADDR_STATUS, rdata[31:0], dummy_resp);
        end

        // Clear OUT_UNDERFLOW flag via RAL (W1C bit 2)
        if (reg_model != null && reg_model.reg_int_status != null) begin
            reg_model.reg_int_status.write(status, 32'h04);
        end else begin
            write_bus(ADDR_INT_STATUS, 32'h04, dummy_resp);
        end
    endtask

endclass : fft_base_vseq

`endif // FFT_BASE_VSEQ_SVH
