// =============================================================================
// File Name      : sideband_seq_item.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Sequence item capturing sideband signal events (IRQ and DMA).
// =============================================================================

`ifndef SIDEBAND_SEQ_ITEM_SVH
`define SIDEBAND_SEQ_ITEM_SVH

class sideband_seq_item extends uvm_sequence_item;

    // ==================================================
    // Transaction Fields
    // ==================================================
    bit  irq;
    bit  dma_rx_req;
    bit  dma_tx_req;
    time event_time;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(sideband_seq_item)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "sideband_seq_item");
        super.new(name);
    endfunction

    // ==================================================
    // Utility Methods
    // ==================================================
    virtual function string convert2string();
        return $sformatf("SIDEBAND_ITEM [time=%0t, irq=%0b, dma_rx_req=%0b, dma_tx_req=%0b]",
            event_time, irq, dma_rx_req, dma_tx_req);
    endfunction

endclass : sideband_seq_item

`endif // SIDEBAND_SEQ_ITEM_SVH
