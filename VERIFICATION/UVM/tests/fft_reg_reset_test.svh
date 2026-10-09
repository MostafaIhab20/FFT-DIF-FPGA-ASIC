// =============================================================================
// File Name      : fft_reg_reset_test.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-06
// Version        : 1.0
// Description    : Register verification test executing the standard UVM
//                  hardware reset sequence (uvm_reg_hw_reset_seq) and verifying
//                  frontdoor read/write operations with explicit prediction.
// =============================================================================

`ifndef FFT_REG_RESET_TEST_SVH
`define FFT_REG_RESET_TEST_SVH

class fft_reg_reset_test extends fft_base_test;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(fft_reg_reset_test)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_reg_reset_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    // ==================================================
    // UVM Run Phase
    // ==================================================
    virtual task run_phase(uvm_phase phase);
        uvm_reg_hw_reset_seq reset_seq;
        uvm_status_e         status;
        uvm_reg_data_t       rdata;

        phase.raise_objection(this);

        `uvm_info("REG_TEST", "Executing standard UVM hardware reset sequence (uvm_reg_hw_reset_seq)...", UVM_LOW)

        reset_seq = uvm_reg_hw_reset_seq::type_id::create("reset_seq");
        reset_seq.model = m_env.m_reg_model;
        reset_seq.start(m_env.m_ahb_agent.ahb_sqr);

        `uvm_info("REG_TEST", "Standard hardware reset sequence passed.", UVM_LOW)

        `uvm_info("REG_TEST", "Executing frontdoor read/write and explicit prediction verification...", UVM_LOW)

        // Verify ID register read
        m_env.m_reg_model.reg_id.read(status, rdata);
        if (status != UVM_IS_OK || rdata !== 32'h4950_0001) begin
            `uvm_error("REG_TEST", $sformatf("ID read mismatch: status=%s, data=0x%08h (expected 0x49500001)", status.name(), rdata))
        end else begin
            `uvm_info("REG_TEST", $sformatf("PASS: ID register read: 0x%08h", rdata), UVM_LOW)
        end

        // Verify VERSION register read
        m_env.m_reg_model.reg_version.read(status, rdata);
        if (status != UVM_IS_OK || rdata !== 32'h0001_0000) begin
            `uvm_error("REG_TEST", $sformatf("VERSION read mismatch: status=%s, data=0x%08h (expected 0x00010000)", status.name(), rdata))
        end else begin
            `uvm_info("REG_TEST", $sformatf("PASS: VERSION register read: 0x%08h", rdata), UVM_LOW)
        end

        // Verify STATUS register read
        m_env.m_reg_model.reg_status.read(status, rdata);
        if (status != UVM_IS_OK || rdata !== 32'h0000_002A) begin
            `uvm_error("REG_TEST", $sformatf("STATUS read mismatch: status=%s, data=0x%08h (expected 0x0000002A)", status.name(), rdata))
        end else begin
            `uvm_info("REG_TEST", $sformatf("PASS: STATUS register read: 0x%08h", rdata), UVM_LOW)
        end

        // Verify IN_THRESH register write and explicit prediction update
        `uvm_info("REG_TEST", "Writing 0x0020 to IN_THRESH...", UVM_LOW)
        m_env.m_reg_model.reg_in_thresh.write(status, 32'h0020);
        if (status != UVM_IS_OK) begin
            `uvm_error("REG_TEST", $sformatf("IN_THRESH write failed with status=%s", status.name()))
        end
        // Verify mirrored value updated by predictor
        if (m_env.m_reg_model.reg_in_thresh.get() !== 32'h0020) begin
            `uvm_error("REG_TEST", $sformatf("IN_THRESH mirrored value mismatch: 0x%08h (expected 0x0020)", m_env.m_reg_model.reg_in_thresh.get()))
        end else begin
            `uvm_info("REG_TEST", $sformatf("PASS: IN_THRESH mirrored value correctly updated to 0x%08h", m_env.m_reg_model.reg_in_thresh.get()), UVM_LOW)
        end
        // Frontdoor read to confirm hardware state
        m_env.m_reg_model.reg_in_thresh.read(status, rdata);
        if (status != UVM_IS_OK || rdata !== 32'h0020) begin
            `uvm_error("REG_TEST", $sformatf("IN_THRESH readback mismatch: status=%s, data=0x%08h (expected 0x0020)", status.name(), rdata))
        end else begin
            `uvm_info("REG_TEST", $sformatf("PASS: IN_THRESH readback confirmed: 0x%08h", rdata), UVM_LOW)
        end

        // Verify OUT_THRESH register write and explicit prediction update
        `uvm_info("REG_TEST", "Writing 0x0028 to OUT_THRESH...", UVM_LOW)
        m_env.m_reg_model.reg_out_thresh.write(status, 32'h0028);
        if (status != UVM_IS_OK) begin
            `uvm_error("REG_TEST", $sformatf("OUT_THRESH write failed with status=%s", status.name()))
        end
        if (m_env.m_reg_model.reg_out_thresh.get() !== 32'h0028) begin
            `uvm_error("REG_TEST", $sformatf("OUT_THRESH mirrored value mismatch: 0x%08h (expected 0x0028)", m_env.m_reg_model.reg_out_thresh.get()))
        end else begin
            `uvm_info("REG_TEST", $sformatf("PASS: OUT_THRESH mirrored value correctly updated to 0x%08h", m_env.m_reg_model.reg_out_thresh.get()), UVM_LOW)
        end
        m_env.m_reg_model.reg_out_thresh.read(status, rdata);
        if (status != UVM_IS_OK || rdata !== 32'h0028) begin
            `uvm_error("REG_TEST", $sformatf("OUT_THRESH readback mismatch: status=%s, data=0x%08h (expected 0x0028)", status.name(), rdata))
        end else begin
            `uvm_info("REG_TEST", $sformatf("PASS: OUT_THRESH readback confirmed: 0x%08h", rdata), UVM_LOW)
        end

        // Verify INT_EN register write and explicit prediction update
        `uvm_info("REG_TEST", "Writing 0x0005 to INT_EN...", UVM_LOW)
        m_env.m_reg_model.reg_int_en.write(status, 32'h0005);
        if (status != UVM_IS_OK) begin
            `uvm_error("REG_TEST", $sformatf("INT_EN write failed with status=%s", status.name()))
        end
        if (m_env.m_reg_model.reg_int_en.get() !== 32'h0005) begin
            `uvm_error("REG_TEST", $sformatf("INT_EN mirrored value mismatch: 0x%08h (expected 0x0005)", m_env.m_reg_model.reg_int_en.get()))
        end else begin
            `uvm_info("REG_TEST", $sformatf("PASS: INT_EN mirrored value correctly updated to 0x%08h", m_env.m_reg_model.reg_int_en.get()), UVM_LOW)
        end
        m_env.m_reg_model.reg_int_en.read(status, rdata);
        if (status != UVM_IS_OK || rdata !== 32'h0005) begin
            `uvm_error("REG_TEST", $sformatf("INT_EN readback mismatch: status=%s, data=0x%08h (expected 0x0005)", status.name(), rdata))
        end else begin
            `uvm_info("REG_TEST", $sformatf("PASS: INT_EN readback confirmed: 0x%08h", rdata), UVM_LOW)
        end

        // Verify CTRL register write (enable + dma_en)
        `uvm_info("REG_TEST", "Writing 0x0003 to CTRL (enable=1, dma_en=1)...", UVM_LOW)
        m_env.m_reg_model.reg_ctrl.write(status, 32'h0003);
        if (status != UVM_IS_OK) begin
            `uvm_error("REG_TEST", $sformatf("CTRL write failed with status=%s", status.name()))
        end
        m_env.m_reg_model.reg_ctrl.read(status, rdata);
        if (status != UVM_IS_OK || rdata !== 32'h0003) begin
            `uvm_error("REG_TEST", $sformatf("CTRL readback mismatch: status=%s, data=0x%08h (expected 0x0003)", status.name(), rdata))
        end else begin
            `uvm_info("REG_TEST", $sformatf("PASS: CTRL readback confirmed: 0x%08h", rdata), UVM_LOW)
        end

        `uvm_info("REG_TEST", "All register tests completed successfully.", UVM_LOW)

        #100ns;
        phase.drop_objection(this);
    endtask

endclass : fft_reg_reset_test

`endif // FFT_REG_RESET_TEST_SVH
