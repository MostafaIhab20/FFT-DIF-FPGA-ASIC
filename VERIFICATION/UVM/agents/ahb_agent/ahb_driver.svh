// =============================================================================
// File Name      : ahb_driver.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : AHB-Lite bus master driver component. Translates sequence
//                  items into AHB address and data phase signal transitions.
// =============================================================================

`ifndef AHB_DRIVER_SVH
`define AHB_DRIVER_SVH

class ahb_driver extends uvm_driver #(ahb_seq_item);

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(ahb_driver)

    // ==================================================
    // Virtual Interface Handle
    // ==================================================
    virtual ahb_if vif;

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "ahb_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ==================================================
    // UVM Build Phase
    // ==================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ahb_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal("AHB_DRV", "Virtual interface 'vif' not found in config_db")
        end
    endfunction

    // ==================================================
    // UVM Run Phase
    // ==================================================
    virtual task run_phase(uvm_phase phase);
        reset_signals();
        wait_for_reset();

        forever begin
            seq_item_port.get_next_item(req);
            drive_transfer(req);
            seq_item_port.item_done();
        end
    endtask

    // ==================================================
    // Interface Control Tasks
    // ==================================================
    // Reset interface signals to safe idle states
    virtual task reset_signals();
        vif.drv_cb.HSEL   <= 1'b0;
        vif.drv_cb.HADDR  <= '0;
        vif.drv_cb.HTRANS <= HTRANS_IDLE;
        vif.drv_cb.HBURST <= HBURST_SINGLE;
        vif.drv_cb.HWRITE <= 1'b0;
        vif.drv_cb.HSIZE  <= HSIZE_WORD;
        vif.drv_cb.HWDATA <= '0;
    endtask

    // Wait until hardware reset is deasserted
    virtual task wait_for_reset();
        @(posedge vif.HCLK);
        while (!vif.HRESETn) begin
            reset_signals();
            @(vif.drv_cb);
        end
        @(vif.drv_cb);
    endtask

    // Drive a complete AHB transfer (Address Phase + Data Phase, supports multi-beat bursts)
    virtual task drive_transfer(ahb_seq_item item);
        bit [31:0]   beat_addr;
        int unsigned len;

        // Ensure payload array consistency
        if (item.burst_data.size() == 0) begin
            item.burst_len  = 1;
            item.burst      = HBURST_SINGLE;
            item.burst_data = new[1];
            item.burst_data[0] = item.data;
        end else if (item.burst_len == 0) begin
            item.burst_len = item.burst_data.size();
        end

        len = item.burst_len;
        if (!item.write && item.burst_data.size() < len) begin
            item.burst_data = new[len];
        end

        // Inter-transfer idle delay
        if (item.wait_cycles > 0) begin
            vif.drv_cb.HSEL   <= 1'b0;
            vif.drv_cb.HTRANS <= HTRANS_IDLE;
            vif.drv_cb.HBURST <= HBURST_SINGLE;
            repeat (item.wait_cycles) @(vif.drv_cb);
        end

        // Wait for bus ready before presenting new address
        while (!vif.drv_cb.HREADYOUT) @(vif.drv_cb);

        beat_addr = item.addr;

        // Drive Beat 0 Address Phase
        vif.drv_cb.HSEL   <= 1'b1;
        vif.drv_cb.HADDR  <= beat_addr;
        vif.drv_cb.HTRANS <= HTRANS_NONSEQ;
        vif.drv_cb.HBURST <= item.burst;
        vif.drv_cb.HWRITE <= item.write;
        vif.drv_cb.HSIZE  <= item.size;

        // Hold Beat 0 address until accepted by slave
        do begin
            @(vif.drv_cb);
        end while (!vif.drv_cb.HREADYOUT);

        // Pipelined phases: overlap data phase of beat k-1 with address phase of beat k
        for (int unsigned k = 1; k < len; k++) begin
            beat_addr = ahb_next_burst_addr(beat_addr, item.burst, item.size);

            // Address phase of beat k
            vif.drv_cb.HSEL   <= 1'b1;
            vif.drv_cb.HADDR  <= beat_addr;
            vif.drv_cb.HTRANS <= HTRANS_SEQ;
            vif.drv_cb.HBURST <= item.burst;
            vif.drv_cb.HWRITE <= item.write;
            vif.drv_cb.HSIZE  <= item.size;

            // Data phase of beat k-1
            if (item.write) begin
                vif.drv_cb.HWDATA <= item.burst_data[k-1];
            end else begin
                vif.drv_cb.HWDATA <= '0;
            end

            // Wait until beat k address and beat k-1 data are accepted
            do begin
                @(vif.drv_cb);
            end while (!vif.drv_cb.HREADYOUT);

            // Sample read data of beat k-1
            if (!item.write) begin
                item.burst_data[k-1] = vif.drv_cb.HRDATA;
            end
        end

        // Final Beat Data Phase (beat len-1)
        // Bus returns to IDLE for address phase
        vif.drv_cb.HSEL   <= 1'b0;
        vif.drv_cb.HTRANS <= HTRANS_IDLE;
        vif.drv_cb.HBURST <= HBURST_SINGLE;

        if (item.write) begin
            vif.drv_cb.HWDATA <= item.burst_data[len-1];
        end else begin
            vif.drv_cb.HWDATA <= '0;
        end

        // Wait until final beat data is accepted
        do begin
            @(vif.drv_cb);
        end while (!vif.drv_cb.HREADYOUT);

        // Sample read data and response for final beat
        if (!item.write) begin
            item.burst_data[len-1] = vif.drv_cb.HRDATA;
            item.data              = item.burst_data[0];
        end else begin
            item.data              = item.burst_data[0];
        end
        item.resp = ahb_resp_e'(vif.drv_cb.HRESP);
    endtask

endclass : ahb_driver

`endif // AHB_DRIVER_SVH
