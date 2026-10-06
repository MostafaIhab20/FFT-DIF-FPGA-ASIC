// =============================================================================
// File Name      : fft_sanity_seq.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : End-to-end sanity sequence verifying peripheral identification,
//                  register configuration, 32-point DC frame transformation,
//                  and interrupt clearing.
// =============================================================================

`ifndef FFT_SANITY_SEQ_SVH
`define FFT_SANITY_SEQ_SVH

class fft_sanity_seq extends fft_base_seq;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(fft_sanity_seq)

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_sanity_seq");
        super.new(name);
    endfunction

    // ==================================================
    // Sequence Body Task
    // ==================================================
    virtual task body();
        bit [31:0] rdata;

        `uvm_info("SANITY_SEQ", "Starting FFT Sanity Sequence execution...", UVM_LOW)

        // Peripheral Identification
        read_reg(ADDR_ID, rdata);
        `uvm_info("SANITY_SEQ", $sformatf("Read IP ID: 0x%08h", rdata), UVM_LOW)

        read_reg(ADDR_VERSION, rdata);
        `uvm_info("SANITY_SEQ", $sformatf("Read IP Version: 0x%08h", rdata), UVM_LOW)

        // Enable Frame Done Interrupt
        write_reg(ADDR_INT_EN, 32'h01);
        read_reg(ADDR_INT_EN, rdata);
        `uvm_info("SANITY_SEQ", $sformatf("Configured INT_EN: 0x%08h", rdata), UVM_LOW)

        // Push 32 DC Complex Samples (Re = 0x6CCD, Im = 0x0000)
        `uvm_info("SANITY_SEQ", "Pushing 32 DC complex samples into IN FIFO...", UVM_LOW)
        for (int i = 0; i < 32; i++) begin
            push_sample(32'h6CCD_0000);
        end

        // Verify IN FIFO level
        read_reg(ADDR_IN_LEVEL, rdata);
        `uvm_info("SANITY_SEQ", $sformatf("IN FIFO Level prior to processing: %0d", rdata), UVM_LOW)

        // Start Core Processing (CTRL[0] = 1)
        `uvm_info("SANITY_SEQ", "Enabling FFT Core (CTRL[0] = 1)...", UVM_LOW)
        write_reg(ADDR_CTRL, 32'h01);

        // Await frame completion and output availability
        wait_for_out_level(32, 2000);
        wait_for_idle(2000);

        // Check Interrupt Status
        read_reg(ADDR_INT_STATUS, rdata);
        `uvm_info("SANITY_SEQ", $sformatf("INT_STATUS after processing: 0x%08h", rdata), UVM_LOW)

        // Read 32 FFT Output Bins from OUT FIFO
        `uvm_info("SANITY_SEQ", "Popping 32 output bins from OUT FIFO...", UVM_LOW)
        for (int i = 0; i < 32; i++) begin
            pop_sample(rdata);
            `uvm_info("SANITY_SEQ", $sformatf("Bin [%0d] = 0x%08h (Re=%0d, Im=%0d)",
                i, rdata, signed'(rdata[31:16]), signed'(rdata[15:0])), UVM_HIGH)
        end

        // Clear FRAME_DONE interrupt via W1C
        write_reg(ADDR_INT_STATUS, 32'h01);
        read_reg(ADDR_INT_STATUS, rdata);
        `uvm_info("SANITY_SEQ", $sformatf("INT_STATUS after W1C clear: 0x%08h", rdata), UVM_LOW)

        // Disable FFT Core
        write_reg(ADDR_CTRL, 32'h00);

        `uvm_info("SANITY_SEQ", "FFT Sanity Sequence execution completed successfully!", UVM_LOW)
    endtask

endclass : fft_sanity_seq

`endif // FFT_SANITY_SEQ_SVH
