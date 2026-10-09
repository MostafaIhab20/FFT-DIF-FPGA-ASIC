// =============================================================================
// File Name      : sideband_monitor.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Passive monitor observing top-level interrupt and DMA lines.
//                  Broadcasts state change events to scoreboards and coverage.
// =============================================================================

`ifndef SIDEBAND_MONITOR_SVH
`define SIDEBAND_MONITOR_SVH

class sideband_monitor extends uvm_monitor;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(sideband_monitor)

    // ==================================================
    // Virtual Interface & TLM Ports
    // ==================================================
    virtual sideband_if                    vif;
    uvm_analysis_port #(sideband_seq_item) sb_mon_irq_ap;
    uvm_analysis_port #(sideband_seq_item) sb_mon_dma_rx_ap;
    uvm_analysis_port #(sideband_seq_item) sb_mon_dma_tx_ap;

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "sideband_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ==================================================
    // UVM Build Phase
    // ==================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual sideband_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("SB_MON", "Virtual interface 'vif' not found in config_db")
        end
        sb_mon_irq_ap = new("sb_mon_irq_ap", this);
        sb_mon_dma_rx_ap = new("sb_mon_dma_rx_ap", this);
        sb_mon_dma_tx_ap = new("sb_mon_dma_tx_ap", this);
    endfunction

    // ==================================================
    // UVM Run Phase
    // ==================================================
    virtual task run_phase(uvm_phase phase);
        bit prev_irq;
        bit prev_dma_rx;
        bit prev_dma_tx;
        bit first_sample = 1'b1;
        bit irq_event;
        bit dma_rx_event;
        bit dma_tx_event;
        sideband_seq_item item;

        // Latched interface signals
        logic hreset_n;
        logic irq;
        logic dma_rx_req;
        logic dma_tx_req;

        forever begin
            @(vif.mon_cb);

            // Latch interface signals at the clock boundary
            hreset_n   = vif.HRESETn;
            irq        = vif.mon_cb.irq;
            dma_rx_req = vif.mon_cb.dma_rx_req;
            dma_tx_req = vif.mon_cb.dma_tx_req;

            if (!hreset_n) begin
                prev_irq     = 1'b0;
                prev_dma_rx  = 1'b0;
                prev_dma_tx  = 1'b0;
                first_sample = 1'b1;
                continue;
            end

            // Detect state transitions or capture initial sample after reset
            irq_event    = first_sample || (irq !== prev_irq);
            dma_rx_event = first_sample || (dma_rx_req !== prev_dma_rx);
            dma_tx_event = first_sample || (dma_tx_req !== prev_dma_tx);

            if (irq_event) begin
                item = sideband_seq_item::type_id::create("sb_item");
                item.irq        = irq;
                item.dma_rx_req = dma_rx_req;
                item.dma_tx_req = dma_tx_req;
                item.event_time = $time;
                prev_irq        = irq;

                `uvm_info("SB_MON", $sformatf("irq Sampled: %b", irq), UVM_HIGH)
                sb_mon_irq_ap.write(item);
            end

            if (dma_rx_event) begin
                item = sideband_seq_item::type_id::create("sb_item");
                item.irq        = irq;
                item.dma_rx_req = dma_rx_req;
                item.dma_tx_req = dma_tx_req;
                item.event_time = $time;
                prev_dma_rx     = dma_rx_req;

                `uvm_info("SB_MON", $sformatf("rx_req Sampled: %b", dma_rx_req), UVM_HIGH)
                sb_mon_dma_rx_ap.write(item);
            end

            if (dma_tx_event) begin
                item = sideband_seq_item::type_id::create("sb_item");
                item.irq        = irq;
                item.dma_rx_req = dma_rx_req;
                item.dma_tx_req = dma_tx_req;
                item.event_time = $time;
                prev_dma_tx     = dma_tx_req;

                `uvm_info("SB_MON", $sformatf("tx_req Sampled: %b", dma_tx_req), UVM_HIGH)
                sb_mon_dma_tx_ap.write(item);
            end

            first_sample = 1'b0;
        end
    endtask

endclass : sideband_monitor

`endif // SIDEBAND_MONITOR_SVH
