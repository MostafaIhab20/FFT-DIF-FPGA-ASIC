// =============================================================================
// File Name      : fft_multi_frame_vseq.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-07
// Version        : 4.0
// Description    : Multi-frame random streaming virtual sequence.
//                  Pumps multiple consecutive 32-point complex frames configured
//                  by fft_scenario_cfg using AHB INCR bursts into the FIFO
//                  streaming window, verifying reactive sideband interrupt
//                  handling (frame done, overflow, underflow) per frame.
// =============================================================================

`ifndef FFT_MULTI_FRAME_VSEQ_SVH
`define FFT_MULTI_FRAME_VSEQ_SVH

class fft_multi_frame_vseq extends fft_base_vseq;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(fft_multi_frame_vseq)

    // ==================================================
    // Scenario Configuration
    // ==================================================
    rand fft_scenario_cfg scenario_cfg;

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_multi_frame_vseq");
        super.new(name);
        scenario_cfg = fft_scenario_cfg::type_id::create("scenario_cfg");
    endfunction

    // ==================================================
    // Sequence Body Task
    // ==================================================
    virtual task body();
        uvm_status_e   status;
        uvm_reg_data_t rdata;

        if (scenario_cfg == null) begin
            scenario_cfg = fft_scenario_cfg::type_id::create("scenario_cfg");
        end
        
        if (scenario_cfg.frames.size() == 0) begin
            if (!scenario_cfg.randomize()) begin
                `uvm_fatal("MULTI_FRAME_VSEQ", "Failed to randomize scenario configuration!")
            end
        end

        `uvm_info("MULTI_FRAME_VSEQ", $sformatf("Starting Multi-Frame Random Streaming Sequence (%0d frames via INCR bursts)...", scenario_cfg.num_frames), UVM_LOW)

        // ==================================================
        // Configurations
        // ==================================================
        // Identification Check via RAL
        reg_model.reg_id.read(status, rdata);
        reg_model.reg_version.read(status, rdata);

        // Enable All Interrupt Sources (Mask = 0x07) via RAL
        reg_model.reg_int_en.write(status, 32'h07);

        // Enable Core Processing via RAL
        reg_model.reg_ctrl.write(status, 32'h01);

        // ==================================================
        // Test Scenario
        // ==================================================
        // Stream Configured Frames with Parallel Interrupt Handling
        for (int f = 0; f < scenario_cfg.num_frames; f++) begin
            `uvm_info("MULTI_FRAME_VSEQ", $sformatf("Processing frame %0d of %0d (32 random complex samples via INCR burst)...", f + 1, scenario_cfg.num_frames), UVM_LOW)

            fork
                begin
                    // Stream 32 randomized complex samples via INCR burst
                    push_samples_burst(scenario_cfg.frames[f], HBURST_INCR);
                end
                begin
                    // Wait for reactive sideband interrupt and handle according to status
                    wait_for_irq(1'b1);
                    reg_model.reg_int_status.read(status, rdata);

                    if (rdata[0] == 1'b1) begin
                        handle_frame_done();
                    end
                    if (rdata[1] == 1'b1) begin
                        handle_overflow();
                    end
                    if (rdata[2] == 1'b1) begin
                        handle_underflow();
                    end
                end
            join
        end

        // Disable FFT Core via RAL
        reg_model.reg_ctrl.write(status, 32'h00);

        `uvm_info("MULTI_FRAME_VSEQ", $sformatf("Completed streaming %0d frames successfully!", scenario_cfg.num_frames), UVM_LOW)
    endtask

endclass : fft_multi_frame_vseq

`endif // FFT_MULTI_FRAME_VSEQ_SVH
