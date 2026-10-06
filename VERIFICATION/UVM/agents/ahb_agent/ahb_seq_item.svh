// =============================================================================
// File Name      : ahb_seq_item.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Sequence item representing an AHB-Lite bus transfer.
//                  Models address, data, transfer type, size, and response.
// =============================================================================

`ifndef AHB_SEQ_ITEM_SVH
`define AHB_SEQ_ITEM_SVH

class ahb_seq_item extends uvm_sequence_item;

    // ==================================================
    // Transaction Fields
    // ==================================================
    rand bit [31:0]   addr;
    rand bit [31:0]   data;
    rand bit          write;
    rand ahb_size_e   size;
    rand ahb_trans_e  trans;
    rand int unsigned wait_cycles;
    ahb_resp_e        resp;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(ahb_seq_item)

    // ==================================================
    // Constraints
    // ==================================================
    // Default constraints for aligned 32-bit transfers
    constraint default_aligned_c {
        soft addr[1:0] == 2'b00;
    }

    constraint default_size_c {
        soft size == HSIZE_WORD;
    }

    constraint default_trans_c {
        soft trans == HTRANS_NONSEQ;
    }

    constraint wait_cycles_c {
        soft wait_cycles dist {
            0       := 80,
            [1:3]   := 15,
            [4:10]  := 5
        };
    }

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "ahb_seq_item");
        super.new(name);
    endfunction

    // ==================================================
    // Utility Methods
    // ==================================================
    virtual function string convert2string();
        return $sformatf("AHB_ITEM [addr=0x%08h, data=0x%08h, %s, size=%s, trans=%s, resp=%s, wait=%0d]",
            addr, data, write ? "WR" : "RD", size.name(), trans.name(), resp.name(), wait_cycles);
    endfunction

endclass : ahb_seq_item

`endif // AHB_SEQ_ITEM_SVH
