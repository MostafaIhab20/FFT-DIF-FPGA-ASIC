// =============================================================================
// File Name      : ahb_seq_item.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Sequence item representing an AHB-Lite bus transfer.
//                  Models address, data, transfer type, size, burst mode, and response.
// =============================================================================

`ifndef AHB_SEQ_ITEM_SVH
`define AHB_SEQ_ITEM_SVH

class ahb_seq_item extends uvm_sequence_item;

    // ==================================================
    // Transaction Fields
    // ==================================================
    rand bit [31:0]      addr;
    rand bit [31:0]      data;
    rand bit [31:0]      burst_data[];
    rand ahb_burst_e     burst;
    rand int unsigned    burst_len;
    rand bit             write;
    rand ahb_size_e      size;
    rand ahb_trans_e     trans;
    rand bit             sel;
    rand int unsigned    wait_cycles;
    ahb_resp_e           resp;

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

    constraint default_sel_c {
        soft sel == 1'b1;
    }

    constraint default_size_c {
        soft size == HSIZE_WORD;
    }

    constraint default_trans_c {
        soft trans == HTRANS_NONSEQ;
    }

    constraint default_burst_c {
        soft burst == HBURST_SINGLE;
    }

    constraint burst_len_c {
        if (burst == HBURST_SINGLE) {
            burst_len == 1;
        } else if (burst inside {HBURST_WRAP4, HBURST_INCR4}) {
            burst_len == 4;
        } else if (burst inside {HBURST_WRAP8, HBURST_INCR8}) {
            burst_len == 8;
        } else if (burst inside {HBURST_WRAP16, HBURST_INCR16}) {
            burst_len == 16;
        } else if (burst == HBURST_INCR) {
            burst_len inside {[1:64]};
        }
    }

    constraint burst_data_payload_c {
        burst_data.size() == burst_len;
    }

    constraint single_burst_data_c {
        if (burst == HBURST_SINGLE && burst_data.size() > 0) {
            burst_data[0] == data;
        }
    }

    constraint wait_cycles_c {
        soft wait_cycles dist {
            0       := 80,
            [1:3]   := 15,
            [4:10]  := 5
        };
    }

    // ==================================================
    // Post Randomization Hook
    // ==================================================
    function void post_randomize();
        if (burst == HBURST_SINGLE) begin
            if (burst_data.size() == 0) begin
                burst_data = new[1];
            end
            burst_data[0] = data;
        end else if (burst_data.size() > 0) begin
            data = burst_data[0];
        end
    endfunction

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "ahb_seq_item");
        super.new(name);
        burst      = HBURST_SINGLE;
        burst_len  = 1;
        burst_data = new[1];
    endfunction

    // ==================================================
    // Utility Methods
    // ==================================================
    virtual function void do_copy(uvm_object rhs);
        ahb_seq_item rhs_;
        if (!$cast(rhs_, rhs)) return;
        super.do_copy(rhs);
        this.addr        = rhs_.addr;
        this.data        = rhs_.data;
        this.burst_data  = rhs_.burst_data;
        this.burst       = rhs_.burst;
        this.burst_len   = rhs_.burst_len;
        this.write       = rhs_.write;
        this.size        = rhs_.size;
        this.trans       = rhs_.trans;
        this.wait_cycles = rhs_.wait_cycles;
        this.resp        = rhs_.resp;
    endfunction

    virtual function string convert2string();
        string s;
        s = $sformatf("AHB_ITEM [addr=0x%08h, burst=%s, len=%0d, %s, size=%s, trans=%s, resp=%s, wait=%0d]",
            addr, burst.name(), burst_len, write ? "WR" : "RD", size.name(), trans.name(), resp.name(), wait_cycles);
        if (burst_len <= 4 && burst_data.size() > 0) begin
            s = {s, $sformatf(", data=%p", burst_data)};
        end else if (burst_data.size() > 0) begin
            s = {s, $sformatf(", data[0]=0x%08h..data[%0d]=0x%08h", burst_data[0], burst_len-1, burst_data[burst_len-1])};
        end else begin
            s = {s, $sformatf(", data=0x%08h", data)};
        end
        return s;
    endfunction

endclass : ahb_seq_item

`endif // AHB_SEQ_ITEM_SVH
