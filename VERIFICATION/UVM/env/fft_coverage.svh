// =============================================================================
// File Name      : fft_coverage.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Functional coverage subscriber for the AHB FFT subsystem.
//                  Tracks protocol adherence, memory map coverage, register R/W,
//                  and sideband interrupt / DMA handshake state transitions.
// =============================================================================

`ifndef FFT_COVERAGE_SVH
`define FFT_COVERAGE_SVH

`uvm_analysis_imp_decl(_cov_ahb)
`uvm_analysis_imp_decl(_cov_sb)

class fft_coverage extends uvm_subscriber #(ahb_seq_item);

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(fft_coverage)

    // ==================================================
    // TLM Exports & Sampling Variables
    // ==================================================
    uvm_analysis_imp_cov_sb #(sideband_seq_item, fft_coverage) sideband_export;
    ahb_seq_item                                              cur_ahb_item;
    sideband_seq_item                                         cur_sb_item;

    // ==================================================
    // AHB-Lite Bus Protocol Covergroup
    // ==================================================
    covergroup cg_ahb_protocol;
        option.per_instance = 1;
        option.comment = "AHB-Lite Bus Protocol Coverage";

        cp_addr_space: coverpoint cur_ahb_item.addr[11:0] {
            bins REG_FILE    = {[12'h000:12'h0FF]};
            bins FIFO_WINDOW = {[12'h100:12'h1FF]};
            bins UNMAPPED    = {[12'h200:12'hFFF]};
        }

        cp_write: coverpoint cur_ahb_item.write {
            bins READ  = {1'b0};
            bins WRITE = {1'b1};
        }

        cp_size: coverpoint cur_ahb_item.size {
            bins WORD     = {HSIZE_WORD};
            bins HALFWORD = {HSIZE_HALFWORD};
            bins BYTE     = {HSIZE_BYTE};
        }

        cp_resp: coverpoint cur_ahb_item.resp {
            bins OKAY  = {HRESP_OKAY};
            bins ERROR = {HRESP_ERROR};
        }

        cp_burst: coverpoint cur_ahb_item.burst {
            bins SINGLE = {HBURST_SINGLE};
            bins INCR   = {HBURST_INCR};
            bins WRAP4  = {HBURST_WRAP4};
            bins INCR4  = {HBURST_INCR4};
            bins WRAP8  = {HBURST_WRAP8};
            bins INCR8  = {HBURST_INCR8};
            bins WRAP16 = {HBURST_WRAP16};
            bins INCR16 = {HBURST_INCR16};
        }

        cross_addr_rw_resp: cross cp_addr_space, cp_write, cp_resp;
        cross_size_resp:    cross cp_size, cp_resp;
        cross_burst_rw:     cross cp_burst, cp_write;
    endgroup

    // ==================================================
    // Register Map Covergroup
    // ==================================================
    covergroup cg_registers;
        option.per_instance = 1;
        option.comment = "Memory-Mapped Registers Coverage";

        cp_reg_offset: coverpoint cur_ahb_item.addr[11:0] iff (cur_ahb_item.addr[11:8] == 4'h0) {
            bins ID         = {12'h000};
            bins VERSION    = {12'h004};
            bins CTRL       = {12'h008};
            bins STATUS     = {12'h00C};
            bins INT_EN     = {12'h010};
            bins INT_STATUS = {12'h014};
            bins IN_LEVEL   = {12'h018};
            bins OUT_LEVEL  = {12'h01C};
            bins IN_THRESH  = {12'h020};
            bins OUT_THRESH = {12'h024};
        }

        cp_reg_rw: coverpoint cur_ahb_item.write {
            bins READ  = {1'b0};
            bins WRITE = {1'b1};
        }

        cross_reg_access: cross cp_reg_offset, cp_reg_rw;
    endgroup

    // ==================================================
    // FIFO Window Covergroup
    // ==================================================
    covergroup cg_fifo;
        option.per_instance = 1;
        option.comment = "Subsystem FIFO Access Coverage";

        cp_fifo_rw: coverpoint cur_ahb_item.write iff (cur_ahb_item.addr[11:8] == 4'h1) {
            bins IN_PUSH   = {1'b1};
            bins OUT_POP   = {1'b0};
        }
    endgroup

    // ==================================================
    // Sideband Signals Covergroup
    // ==================================================
    covergroup cg_sidebands;
        option.per_instance = 1;
        option.comment = "Interrupt and DMA Hardware Lines Coverage";

        cp_irq: coverpoint cur_sb_item.irq {
            bins DEASSERTED = {1'b0};
            bins ASSERTED   = {1'b1};
            bins TOGGLE     = (0 => 1), (1 => 0);
        }

        cp_dma_rx: coverpoint cur_sb_item.dma_rx_req {
            bins INACTIVE = {1'b0};
            bins ACTIVE   = {1'b1};
            bins TOGGLE   = (0 => 1), (1 => 0);
        }

        cp_dma_tx: coverpoint cur_sb_item.dma_tx_req {
            bins INACTIVE = {1'b0};
            bins ACTIVE   = {1'b1};
            bins TOGGLE   = (0 => 1), (1 => 0);
        }
    endgroup

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_coverage", uvm_component parent = null);
        super.new(name, parent);
        sideband_export = new("sideband_export", this);

        cg_ahb_protocol = new();
        cg_registers    = new();
        cg_fifo         = new();
        cg_sidebands    = new();
    endfunction

    // ==================================================
    // Sampling Implementations
    // ==================================================
    virtual function void write(ahb_seq_item t);
        cur_ahb_item = t;
        cg_ahb_protocol.sample();
        if (t.addr[11:8] == 4'h0) begin
            cg_registers.sample();
        end else if (t.addr[11:8] == 4'h1) begin
            cg_fifo.sample();
        end
    endfunction

    virtual function void write_cov_sb(sideband_seq_item t);
        cur_sb_item = t;
        cg_sidebands.sample();
    endfunction

    // ==================================================
    // UVM Report Phase
    // ==================================================
    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("COV_REPORT", "=========================================================================", UVM_LOW)
        `uvm_info("COV_REPORT", "                       FUNCTIONAL COVERAGE REPORT                        ", UVM_LOW)
        `uvm_info("COV_REPORT", "=========================================================================", UVM_LOW)
        `uvm_info("COV_REPORT", $sformatf("AHB Protocol Coverage : %0.2f%%", cg_ahb_protocol.get_inst_coverage()), UVM_LOW)
        `uvm_info("COV_REPORT", $sformatf("Registers Coverage    : %0.2f%%", cg_registers.get_inst_coverage()), UVM_LOW)
        `uvm_info("COV_REPORT", $sformatf("Sidebands Coverage    : %0.2f%%", cg_sidebands.get_inst_coverage()), UVM_LOW)
        `uvm_info("COV_REPORT", "=========================================================================", UVM_LOW)
    endfunction

endclass : fft_coverage

`endif // FFT_COVERAGE_SVH
