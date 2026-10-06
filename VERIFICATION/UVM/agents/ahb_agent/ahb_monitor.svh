// =============================================================================
// File Name      : ahb_monitor.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Passive AHB-Lite bus monitor. Samples address and data
//                  phases, constructs sequence items, and broadcasts to scoreboard.
// =============================================================================

`ifndef AHB_MONITOR_SVH
`define AHB_MONITOR_SVH

class ahb_monitor extends uvm_monitor;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(ahb_monitor)

    // ==================================================
    // Virtual Interface & TLM Ports
    // ==================================================
    virtual ahb_if                    vif;
    uvm_analysis_port #(ahb_seq_item) ahb_mon_ap;

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "ahb_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ==================================================
    // UVM Build Phase
    // ==================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ahb_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("AHB_MON", "Virtual interface 'vif' not found in config_db")
        end
        ahb_mon_ap = new("ahb_mon_ap", this);
    endfunction

    // ==================================================
    // UVM Run Phase
    // ==================================================
    virtual task run_phase(uvm_phase phase);
        ahb_seq_item pending_q[$];
        ahb_seq_item item;

        // Latched interface signals
        logic              hreset_n;
        logic              hsel;
        logic [31:0]       haddr;
        logic [1:0]        htrans;
        logic [2:0]        hburst;
        logic              hwrite;
        logic [2:0]        hsize;
        logic [31:0]       hwdata;
        logic              hreadyout;
        logic [31:0]       hrdata;
        logic              hresp;

        forever begin
            // Latch interface signals at the clock boundary
            @(vif.mon_cb);
            hreset_n  = vif.HRESETn;
            hsel      = vif.mon_cb.HSEL;
            haddr     = vif.mon_cb.HADDR;
            htrans    = vif.mon_cb.HTRANS;
            hburst    = vif.mon_cb.HBURST;
            hwrite    = vif.mon_cb.HWRITE;
            hsize     = vif.mon_cb.HSIZE;
            hwdata    = vif.mon_cb.HWDATA;
            hreadyout = vif.mon_cb.HREADYOUT;
            hrdata    = vif.mon_cb.HRDATA;
            hresp     = vif.mon_cb.HRESP;

            if (!hreset_n) begin
                pending_q.delete();
                continue;
            end

            // Complete data phase for active pending transfer
            if (pending_q.size() > 0 && hreadyout === 1'b1) begin
                item = pending_q.pop_front();
                if (item.write) begin
                    item.data = hwdata;
                end else begin
                    item.data = hrdata;
                end
                item.burst_data = new[1];
                item.burst_data[0] = item.data;
                item.resp = ahb_resp_e'(hresp);

                `uvm_info("AHB_MON", $sformatf("Sampled: %s", item.convert2string()), UVM_HIGH)
                ahb_mon_ap.write(item);
            end

            // Capture address phase of newly initiated transfer
            if (hsel && htrans[1] && (hreadyout === 1'b1)) begin
                item = ahb_seq_item::type_id::create("mon_item");
                item.addr      = haddr;
                item.write     = hwrite;
                item.size      = ahb_size_e'(hsize);
                item.trans     = ahb_trans_e'(htrans);
                item.burst     = ahb_burst_e'(hburst);
                item.burst_len = 1;
                pending_q.push_back(item);
            end
        end
    endtask

endclass : ahb_monitor

`endif // AHB_MONITOR_SVH
