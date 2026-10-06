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

    // Drive a complete AHB transfer (Address Phase + Data Phase)
    virtual task drive_transfer(ahb_seq_item item);
        // Inter-transfer idle delay
        if (item.wait_cycles > 0) begin
            vif.drv_cb.HSEL   <= 1'b0;
            vif.drv_cb.HTRANS <= HTRANS_IDLE;
            repeat (item.wait_cycles) @(vif.drv_cb);
        end

        // Wait for bus ready before presenting new address
        while (!vif.drv_cb.HREADYOUT) @(vif.drv_cb);

        // Address Phase
        vif.drv_cb.HSEL   <= 1'b1;
        vif.drv_cb.HADDR  <= item.addr;
        vif.drv_cb.HTRANS <= item.trans;
        vif.drv_cb.HWRITE <= item.write;
        vif.drv_cb.HSIZE  <= item.size;

        // Hold address and control signals stable until accepted by slave
        do begin
            @(vif.drv_cb);
        end while (!vif.drv_cb.HREADYOUT);

        // Data Phase
        if (item.write) begin
            vif.drv_cb.HWDATA <= item.data;
        end else begin
            vif.drv_cb.HWDATA <= '0;
        end

        // Default next bus state to IDLE
        vif.drv_cb.HSEL   <= 1'b0;
        vif.drv_cb.HTRANS <= HTRANS_IDLE;

        // Wait for slave to complete data phase
        while (!vif.drv_cb.HREADYOUT) begin
            @(vif.drv_cb);
        end

        // Capture read response or write status
        if (!item.write) begin
            item.data = vif.drv_cb.HRDATA;
        end
        item.resp = ahb_resp_e'(vif.drv_cb.HRESP);
    endtask

endclass : ahb_driver

`endif // AHB_DRIVER_SVH
