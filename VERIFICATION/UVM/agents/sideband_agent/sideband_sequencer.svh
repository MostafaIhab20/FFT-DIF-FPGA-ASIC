// =============================================================================
// File Name      : sideband_sequencer.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-09
// Version        : 2.1 (Dedicated Signal FIFOs, Analysis Imps & Live State Tracking)
// Description    : Reactive sequencer for the sideband agent.
//                  Maintains dedicated TLM analysis FIFOs and live state variables
//                  for IRQ, DMA RX, and DMA TX, populated directly via analysis imps.
// =============================================================================

`ifndef SIDEBAND_SEQUENCER_SVH
`define SIDEBAND_SEQUENCER_SVH

`uvm_analysis_imp_decl(_sb_irq)
`uvm_analysis_imp_decl(_sb_dma_rx)
`uvm_analysis_imp_decl(_sb_dma_tx)

class sideband_sequencer extends uvm_sequencer #(sideband_seq_item);

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(sideband_sequencer)

    // ==================================================
    // Dedicated TLM Analysis FIFOs for Each Sideband Signal
    // ==================================================
    uvm_tlm_analysis_fifo #(sideband_seq_item) irq_fifo;
    uvm_tlm_analysis_fifo #(sideband_seq_item) dma_rx_fifo;
    uvm_tlm_analysis_fifo #(sideband_seq_item) dma_tx_fifo;

    // ==================================================
    // Analysis Imps from Monitor
    // ==================================================
    uvm_analysis_imp_sb_irq    #(sideband_seq_item, sideband_sequencer) sb_irq_export;
    uvm_analysis_imp_sb_dma_rx #(sideband_seq_item, sideband_sequencer) sb_dma_rx_export;
    uvm_analysis_imp_sb_dma_tx #(sideband_seq_item, sideband_sequencer) sb_dma_tx_export;

    // ==================================================
    // Live State Tracking
    // ==================================================
    bit cur_irq;
    bit cur_dma_rx;
    bit cur_dma_tx;

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "sideband_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ==================================================
    // UVM Build Phase
    // ==================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        irq_fifo         = new("irq_fifo", this);
        sb_irq_export    = new("sb_irq_export", this);
        dma_rx_fifo      = new("dma_rx_fifo", this);
        sb_dma_rx_export = new("sb_dma_rx_export", this);
        dma_tx_fifo      = new("dma_tx_fifo", this);
        sb_dma_tx_export = new("sb_dma_tx_export", this);
    endfunction

    // ==================================================
    // Analysis Imp Write Callbacks
    // ==================================================
    virtual function void write_sb_irq(sideband_seq_item item);
        cur_irq = item.irq;
        irq_fifo.write(item);
    endfunction

    virtual function void write_sb_dma_rx(sideband_seq_item item);
        cur_dma_rx = item.dma_rx_req;
        dma_rx_fifo.write(item);
    endfunction

    virtual function void write_sb_dma_tx(sideband_seq_item item);
        cur_dma_tx = item.dma_tx_req;
        dma_tx_fifo.write(item);
    endfunction

endclass : sideband_sequencer

`endif // SIDEBAND_SEQUENCER_SVH
