// =============================================================================
// File Name      : ahb_reg_adapter.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-06
// Version        : 1.0
// Description    : Protocol adapter converting between generic UVM register
//                  operations (uvm_reg_bus_op) and AHB bus transfers (ahb_seq_item).
// =============================================================================

`ifndef AHB_REG_ADAPTER_SVH
`define AHB_REG_ADAPTER_SVH

class ahb_reg_adapter extends uvm_reg_adapter;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(ahb_reg_adapter)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "ahb_reg_adapter");
        super.new(name);
        supports_byte_enable = 0;
        provides_responses   = 0;
    endfunction

    // ==================================================
    // Register to Bus Transformation
    // ==================================================
    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        ahb_seq_item item = ahb_seq_item::type_id::create("ahb_reg_item");
        item.sel           = 1'b1;
        item.addr          = rw.addr;
        item.write         = (rw.kind == UVM_WRITE);
        item.data          = rw.data;
        item.size          = HSIZE_WORD;
        item.burst         = HBURST_SINGLE;
        item.burst_len     = 1;
        item.burst_data    = new[1];
        item.burst_data[0] = rw.data;
        item.trans         = HTRANS_NONSEQ;
        item.wait_cycles   = 0;
        return item;
    endfunction

    // ==================================================
    // Bus to Register Transformation
    // ==================================================
    virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        ahb_seq_item item;
        if (!$cast(item, bus_item)) begin
            `uvm_fatal("AHB_REG_ADAPT", "Provided bus_item is not of type ahb_seq_item")
            return;
        end
        rw.kind   = item.write ? UVM_WRITE : UVM_READ;
        rw.addr   = item.addr;
        rw.data   = item.data;
        rw.status = (item.resp == HRESP_ERROR) ? UVM_NOT_OK : UVM_IS_OK;
    endfunction

endclass : ahb_reg_adapter

`endif // AHB_REG_ADAPTER_SVH
