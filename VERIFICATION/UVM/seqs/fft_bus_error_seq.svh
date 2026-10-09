// =============================================================================
// File Name      : fft_bus_error_seq.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-07
// Version        : 2.0 (Direct Raw Bus Testing with Response)
// Description    : Bus error and negative protocol stimulus sequence.
//                  Systematically exercises unaligned accesses, sub-word sizes,
//                  unmapped addresses, and writes to read-only registers via write_bus/read_bus,
//                  verifying 2-cycle HRESP_ERROR and immediate bus recovery.
// =============================================================================

`ifndef FFT_BUS_ERROR_SEQ_SVH
`define FFT_BUS_ERROR_SEQ_SVH

class fft_bus_error_seq extends fft_base_vseq;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(fft_bus_error_seq)

    // ==================================================
    // Verification Statistics
    // ==================================================
    int unsigned num_expected_errors;
    int unsigned num_detected_errors;
    int unsigned num_successful_recoveries;

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_bus_error_seq");
        super.new(name);
        num_expected_errors       = 0;
        num_detected_errors       = 0;
        num_successful_recoveries = 0;
    endfunction

    // ==================================================
    // Sequence Body Task
    // ==================================================
    virtual task body();
        `uvm_info("BUS_ERR_SEQ", "Starting Bus Error & Negative Protocol Verification Sequence...", UVM_LOW)

        // ==================================================
        // Configurations
        // ==================================================
        // Initial sanity read before injecting errors (Baseline Check)
        verify_bus_recovery("Initial Baseline Read");

        // ==================================================
        // Test Scenario
        // ==================================================
        // Unaligned Address Transfers
        `uvm_info("BUS_ERR_SEQ", "Exercising Unaligned Address Accesses...", UVM_LOW)
        test_read_error(32'h001, HSIZE_WORD, "Unaligned read at 0x001");
        test_read_error(32'h002, HSIZE_WORD, "Unaligned read at 0x002");
        test_read_error(32'h003, HSIZE_WORD, "Unaligned read at 0x003");
        test_write_error(32'h001, 32'hA5A5_5A5A, HSIZE_WORD, "Unaligned write at 0x001");
        test_write_error(32'h002, 32'hA5A5_5A5A, HSIZE_WORD, "Unaligned write at 0x002");
        test_write_error(32'h003, 32'hA5A5_5A5A, HSIZE_WORD, "Unaligned write at 0x003");
        test_read_error(32'h101, HSIZE_WORD, "Unaligned FIFO read at 0x101");
        test_write_error(32'h102, 32'h1234_5678, HSIZE_WORD, "Unaligned FIFO write at 0x102");
        verify_bus_recovery("Post-Unaligned-Access Recovery");

        // Sub-Word Transfer Sizes
        `uvm_info("BUS_ERR_SEQ", "Exercising Sub-Word Transfer Sizes...", UVM_LOW)
        test_read_error(ADDR_ID, HSIZE_BYTE, "Byte read on ADDR_ID");
        test_read_error(ADDR_ID, HSIZE_HALFWORD, "Half-word read on ADDR_ID");
        test_write_error(ADDR_CTRL, 32'h01, HSIZE_BYTE, "Byte write on ADDR_CTRL");
        test_write_error(ADDR_CTRL, 32'h01, HSIZE_HALFWORD, "Half-word write on ADDR_CTRL");
        test_read_error(ADDR_FIFO_DATA, HSIZE_BYTE, "Byte read on FIFO_DATA");
        test_write_error(ADDR_FIFO_DATA, 32'h0001_0000, HSIZE_HALFWORD, "Half-word write on FIFO_DATA");
        verify_bus_recovery("Post-Sub-Word-Size Recovery");

        // Unmapped Address Space Transfers
        `uvm_info("BUS_ERR_SEQ", "Exercising Unmapped Address Space Accesses...", UVM_LOW)
        test_read_error(32'h028, HSIZE_WORD, "Read from unmapped register hole 0x028");
        test_write_error(32'h02C, 32'hFFFF_FFFF, HSIZE_WORD, "Write to unmapped register hole 0x02C");
        test_read_error(32'h040, HSIZE_WORD, "Read from unmapped register hole 0x040");
        test_write_error(32'h0FC, 32'h1122_3344, HSIZE_WORD, "Write to unmapped register hole 0x0FC");
        test_read_error(32'h200, HSIZE_WORD, "Read from out-of-range address 0x200");
        test_write_error(32'h204, 32'hCAFE_BABE, HSIZE_WORD, "Write to out-of-range address 0x204");
        test_read_error(32'h400, HSIZE_WORD, "Read from out-of-range address 0x400");
        test_write_error(32'hFFC, 32'hDEAD_BEEF, HSIZE_WORD, "Write to out-of-range address 0xFFC");
        verify_bus_recovery("Post-Unmapped-Address Recovery");

        // Writes to Read-Only Registers
        `uvm_info("BUS_ERR_SEQ", "Exercising Writes to Read-Only Registers...", UVM_LOW)
        test_write_error(ADDR_ID, 32'hDEAD_BEEF, HSIZE_WORD, "Write to Read-Only ADDR_ID");
        test_write_error(ADDR_VERSION, 32'hDEAD_BEEF, HSIZE_WORD, "Write to Read-Only ADDR_VERSION");
        test_write_error(ADDR_STATUS, 32'hDEAD_BEEF, HSIZE_WORD, "Write to Read-Only ADDR_STATUS");
        test_write_error(ADDR_IN_LEVEL, 32'hDEAD_BEEF, HSIZE_WORD, "Write to Read-Only ADDR_IN_LEVEL");
        test_write_error(ADDR_OUT_LEVEL, 32'hDEAD_BEEF, HSIZE_WORD, "Write to Read-Only ADDR_OUT_LEVEL");
        verify_bus_recovery("Post-RO-Write-Protection Recovery");

        `uvm_info("BUS_ERR_SEQ", $sformatf("Bus Error Sequence Completed: %0d/%0d errors caught, %0d successful recoveries",
            num_detected_errors, num_expected_errors, num_successful_recoveries), UVM_LOW)
    endtask

    // ==================================================
    // Negative Testing Verification Helpers
    // (Directly Exercises write_bus & read_bus with response output)
    // ==================================================
    // Execute a read expecting an AHB ERROR response
    virtual task test_read_error(
        input bit [31:0]  addr,
        input ahb_size_e  size,
        input string      desc
    );
        bit [31:0] rdata;
        ahb_resp_e resp;

        num_expected_errors++;
        read_bus(addr, rdata, resp, 0, size);

        if (resp == HRESP_ERROR) begin
            num_detected_errors++;
            `uvm_info("BUS_ERR_PASS", $sformatf("PASS: [HRESP_ERROR] detected as expected for %s (addr=0x%08h)", desc, addr), UVM_HIGH)
        end else begin
            `uvm_error("BUS_ERR_FAIL", $sformatf("FAIL: Expected HRESP_ERROR but got HRESP_OKAY for %s (addr=0x%08h)", desc, addr))
        end
    endtask

    // Execute a write expecting an AHB ERROR response
    virtual task test_write_error(
        input bit [31:0]  addr,
        input bit [31:0]  wdata,
        input ahb_size_e  size,
        input string      desc
    );
        ahb_resp_e resp;

        num_expected_errors++;
        write_bus(addr, wdata, resp, 0, size);

        if (resp == HRESP_ERROR) begin
            num_detected_errors++;
            `uvm_info("BUS_ERR_PASS", $sformatf("PASS: [HRESP_ERROR] detected as expected for %s (addr=0x%08h)", desc, addr), UVM_HIGH)
        end else begin
            `uvm_error("BUS_ERR_FAIL", $sformatf("FAIL: Expected HRESP_ERROR but got HRESP_OKAY for %s (addr=0x%08h)", desc, addr))
        end
    endtask

    // Verify immediate recovery by issuing a valid read transaction
    virtual task verify_bus_recovery(input string phase_desc);
        bit [31:0] rdata;
        ahb_resp_e resp;

        read_bus(ADDR_ID, rdata, resp, 0, HSIZE_WORD);

        if (resp == HRESP_OKAY && rdata == 32'h4950_0001) begin
            num_successful_recoveries++;
            `uvm_info("BUS_RECOVERY_PASS", $sformatf("PASS: Bus recovery verified (%s) -> ADDR_ID = 0x%08h", phase_desc, rdata), UVM_MEDIUM)
        end else begin
            `uvm_error("BUS_RECOVERY_FAIL", $sformatf("FAIL: Bus recovery failed (%s) -> resp=%s, data=0x%08h (expected 0x49500001)",
                phase_desc, (resp == HRESP_OKAY) ? "OKAY" : "ERROR", rdata))
        end
    endtask

endclass : fft_bus_error_seq

`endif // FFT_BUS_ERROR_SEQ_SVH
