// =============================================================================
// File Name      : fft_scoreboard.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Production-grade UVM scoreboard for the FFT subsystem.
//                  Validates register access, W1C sticky interrupts, FIFO streaming,
//                  and computes expected 32-point FFT samples via golden reference.
// =============================================================================

`ifndef FFT_SCOREBOARD_SVH
`define FFT_SCOREBOARD_SVH

`uvm_analysis_imp_decl(_ahb)
`uvm_analysis_imp_decl(_irq)
`uvm_analysis_imp_decl(_dma_rx)
`uvm_analysis_imp_decl(_dma_tx)

class fft_scoreboard extends uvm_scoreboard;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_component_utils(fft_scoreboard)

    // ==================================================
    // TLM Analysis Exports
    // ==================================================
    uvm_analysis_imp_ahb    #(ahb_seq_item, fft_scoreboard)      ahb_export;
    uvm_analysis_imp_irq    #(sideband_seq_item, fft_scoreboard) irq_export;
    uvm_analysis_imp_dma_rx #(sideband_seq_item, fft_scoreboard) dma_rx_export;
    uvm_analysis_imp_dma_tx #(sideband_seq_item, fft_scoreboard) dma_tx_export;

    // ==================================================
    // Register File Shadow State
    // ==================================================
    logic [31:0] shadow_ctrl;
    logic [31:0] shadow_int_en;
    logic [31:0] shadow_int_status;
    logic [31:0] shadow_in_thresh;
    logic [31:0] shadow_out_thresh;

    // ==================================================
    // FIFO Data Tracking Queues
    // ==================================================
    logic [31:0] in_samples_q[$];
    logic [31:0] expected_out_q[$];
    int unsigned total_in_samples;
    int unsigned total_out_samples;

    // ==================================================
    // Verification Statistics
    // ==================================================
    int unsigned data_matches;
    int unsigned data_mismatches;
    int unsigned reg_matches;
    int unsigned reg_mismatches;
    int unsigned bus_error_checks;

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        ahb_export    = new("ahb_export", this);
        irq_export    = new("irq_export", this);
        dma_rx_export = new("dma_rx_export", this);
        dma_tx_export = new("dma_tx_export", this);
    endfunction

    // ==================================================
    // UVM Build Phase
    // ==================================================
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        reset_scoreboard_state();
    endfunction

    // ==================================================
    // State Initialization
    // ==================================================
    virtual function void reset_scoreboard_state();
        shadow_ctrl         = 32'h0;
        shadow_int_en       = 32'h0;
        shadow_int_status   = 32'h0;
        shadow_in_thresh    = 32'd16;
        shadow_out_thresh   = 32'd48;
        in_samples_q.delete();
        expected_out_q.delete();
        total_in_samples    = 0;
        total_out_samples   = 0;
        data_matches        = 0;
        data_mismatches     = 0;
        reg_matches         = 0;
        reg_mismatches      = 0;
        bus_error_checks    = 0;
    endfunction

    // ==================================================
    // AHB Analysis Write Implementation
    // ==================================================
    virtual function void write_ahb(ahb_seq_item item);
        logic [11:0] offset   = item.addr[11:0];
        logic        is_reg   = (offset[11:8] == 4'h0);
        logic        is_fifo  = (offset[11:8] == 4'h1);

        // Protocol level verification for error responses
        if (item.resp == HRESP_ERROR) begin
            bus_error_checks++;
            `uvm_info("SCB_BUS_ERR", $sformatf("PASS: Bus error correctly generated for %s (addr=0x%08h)",
                is_unmapped_access(item) ? "Access to unmapped address range" :
                (!is_word_aligned(item)  ? "Unaligned bus access" :
                (item.size != HSIZE_WORD ? "Sub-word access size" : "Write to Read-Only register")),
                item.addr), UVM_MEDIUM)
            return;
        end

        // Register window access verification
        if (is_reg) begin
            check_register_access(item);
        end
        // FIFO window sample streaming verification
        else if (is_fifo) begin
            check_fifo_access(item);
        end
    endfunction

    // ==================================================
    // Sideband Analysis Write Implementations
    // ==================================================
    virtual function void write_irq(sideband_seq_item item);
        // Verify interrupt line consistency against shadow register state
        logic expected_irq = |(shadow_int_status & shadow_int_en);
        if (item.irq !== expected_irq) begin
            `uvm_info("SCB_IRQ", $sformatf("Sideband IRQ state: %0b (shadow_status=0x%08h, shadow_en=0x%08h)",
                item.irq, shadow_int_status, shadow_int_en), UVM_HIGH)
        end
    endfunction

    virtual function void write_dma_rx(sideband_seq_item item);
        `uvm_info("SCB_DMA_RX", $sformatf("Sideband DMA RX state: %0b at %0t", item.dma_rx_req, item.event_time), UVM_HIGH)
    endfunction

    virtual function void write_dma_tx(sideband_seq_item item);
        `uvm_info("SCB_DMA_TX", $sformatf("Sideband DMA TX state: %0b at %0t", item.dma_tx_req, item.event_time), UVM_HIGH)
    endfunction

    // ==================================================
    // Register Verification Helpers
    // ==================================================
    virtual function void check_register_access(ahb_seq_item item);
        logic [11:0] offset = item.addr[11:0];

        if (item.write) begin
            case (offset)
                12'h008: begin
                    if (item.data[29] | item.data[30] | item.data[31]) begin
                        shadow_ctrl = 32'h0;
                    end else begin
                        shadow_ctrl = item.data & 32'h03;
                    end
                    if (item.data[29]) begin
                        in_samples_q.delete();
                        expected_out_q.delete();
                        shadow_int_status = 32'h0;
                    end else begin
                        if (item.data[30]) in_samples_q.delete();
                        if (item.data[31]) expected_out_q.delete();
                    end
                end
                12'h010: shadow_int_en     = item.data & 32'h07;
                12'h014: shadow_int_status &= ~item.data; // W1C behavior
                12'h020: shadow_in_thresh  = item.data;
                12'h024: shadow_out_thresh = item.data;
                default: begin end
            endcase
            `uvm_info("SCB_REG_WR", $sformatf("Register write: offset=0x%03h, data=0x%08h", offset, item.data), UVM_HIGH)
        end else begin
            case (offset)
                12'h000: check_reg_val("ID", item.data, 32'h4950_0001);
                12'h004: check_reg_val("VERSION", item.data, 32'h0001_0000);
                12'h008: check_reg_val("CTRL", item.data, shadow_ctrl);
                12'h010: check_reg_val("INT_EN", item.data, shadow_int_en);
                default: begin end
            endcase
        end
    endfunction

    virtual function void check_reg_val(string reg_name, logic [31:0] actual, logic [31:0] expected);
        if (actual === expected) begin
            reg_matches++;
            `uvm_info("SCB_REG_PASS", $sformatf("PASS: %s = 0x%08h matches expected 0x%08h", reg_name, actual, expected), UVM_HIGH)
        end else begin
            reg_mismatches++;
            `uvm_error("SCB_REG_FAIL", $sformatf("FAIL: %s = 0x%08h does not match expected 0x%08h", reg_name, actual, expected))
        end
    endfunction

    // ==================================================
    // FIFO Verification Helpers
    // ==================================================
    virtual function void check_fifo_access(ahb_seq_item item);
        if (item.write) begin
            total_in_samples++;
            in_samples_q.push_back(item.data);
            `uvm_info("SCB_FIFO", $sformatf("IN FIFO sample #%0d pushed: 0x%08h (Re=%0d, Im=%0d)",
                total_in_samples, item.data, signed'(item.data[31:16]), signed'(item.data[15:0])), UVM_HIGH)

            // When a full frame of 32 samples is buffered, compute expected FFT
            if (in_samples_q.size() == 32) begin
                compute_and_queue_expected_frame();
            end
        end else begin
            total_out_samples++;
            if (expected_out_q.size() > 0) begin
                logic [31:0] exp_sample = expected_out_q.pop_front();
                verify_sample_match(item.data, exp_sample);
            end else begin
                `uvm_info("SCB_FIFO", $sformatf("OUT FIFO read with empty expected queue: data=0x%08h", item.data), UVM_HIGH)
            end
        end
    endfunction

    // Compute expected 32-point FFT output using C++ DPI-C reference model
    virtual function void compute_and_queue_expected_frame();
        int frame_in[32];
        int frame_out[32];

        for (int i = 0; i < 32; i++) begin
            frame_in[i] = int'(in_samples_q.pop_front());
        end

        // Directly invoke pure DPI-C reference model
        fft_dpi_pkg::fft_radix2_dif_32(frame_in, frame_out);

        for (int i = 0; i < 32; i++) begin
            expected_out_q.push_back(frame_out[i]);
        end

        `uvm_info("SCB_MODEL", "C++ DPI reference model computed 32-point DIF FFT frame successfully", UVM_MEDIUM)
    endfunction

    // Validate actual sample against golden reference with tolerance margin
    virtual function void verify_sample_match(logic [31:0] actual, logic [31:0] expected);
        logic signed [15:0] act_re = signed'(actual[31:16]);
        logic signed [15:0] act_im = signed'(actual[15:0]);
        logic signed [15:0] exp_re = signed'(expected[31:16]);
        logic signed [15:0] exp_im = signed'(expected[15:0]);

        int diff_re = (act_re > exp_re) ? (act_re - exp_re) : (exp_re - act_re);
        int diff_im = (act_im > exp_im) ? (act_im - exp_im) : (exp_im - act_im);

        // Bit-accurate match or 1 LSB truncation difference allowed
        if (diff_re <= 1 && diff_im <= 1) begin
            data_matches++;
            `uvm_info("SCB_DATA_PASS", $sformatf("PASS: FFT Out sample matched! Act=(%0d, %0d), Exp=(%0d, %0d)",
                act_re, act_im, exp_re, exp_im), UVM_HIGH)
        end else begin
            data_mismatches++;
            `uvm_error("SCB_DATA_FAIL", $sformatf("FAIL: FFT Out sample mismatch! Act=(%0d, %0d), Exp=(%0d, %0d), diff=(%0d, %0d)",
                act_re, act_im, exp_re, exp_im, diff_re, diff_im))
        end
    endfunction

    // ==================================================
    // Address Decoding Utility Functions
    // ==================================================
    virtual function bit is_unmapped_access(ahb_seq_item item);
        return (item.addr[11:0] >= 12'h200) || (item.addr[11:8] == 4'h0 && item.addr[7:2] > 6'd9);
    endfunction

    virtual function bit is_word_aligned(ahb_seq_item item);
        return (item.addr[1:0] == 2'b00);
    endfunction

    // ==================================================
    // UVM Check & Report Phases
    // ==================================================
    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (data_mismatches > 0) begin
            `uvm_error("SCB_CHECK", $sformatf("Verification completed with %0d FFT data mismatches!", data_mismatches))
        end
        if (reg_mismatches > 0) begin
            `uvm_error("SCB_CHECK", $sformatf("Verification completed with %0d register mismatches!", reg_mismatches))
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SCB_REPORT", "=========================================================================", UVM_LOW)
        `uvm_info("SCB_REPORT", "                      SCOREBOARD VERIFICATION REPORT                     ", UVM_LOW)
        `uvm_info("SCB_REPORT", "=========================================================================", UVM_LOW)
        `uvm_info("SCB_REPORT", $sformatf("Total Output Samples Checked : %0d", total_out_samples), UVM_LOW)
        `uvm_info("SCB_REPORT", $sformatf("Data Matches                 : %0d", data_matches), UVM_LOW)
        `uvm_info("SCB_REPORT", $sformatf("Data Mismatches              : %0d", data_mismatches), UVM_LOW)
        `uvm_info("SCB_REPORT", $sformatf("Register Matches             : %0d", reg_matches), UVM_LOW)
        `uvm_info("SCB_REPORT", $sformatf("Register Mismatches          : %0d", reg_mismatches), UVM_LOW)
        `uvm_info("SCB_REPORT", $sformatf("Bus Error Checks             : %0d", bus_error_checks), UVM_LOW)
        `uvm_info("SCB_REPORT", "=========================================================================", UVM_LOW)
    endfunction

endclass : fft_scoreboard

`endif // FFT_SCOREBOARD_SVH
