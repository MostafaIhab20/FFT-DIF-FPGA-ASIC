// =============================================================================
// File Name      : fft_scenario_cfg.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-09
// Version        : 1.0
// Description    : Scenario configuration object defining randomized test parameters
//                  and multi-frame stimulus data structures for FFT sequences.
// =============================================================================

`ifndef FFT_SCENARIO_CFG_SVH
`define FFT_SCENARIO_CFG_SVH

class fft_scenario_cfg extends uvm_object;

    // ==================================================
    // Factory Registration
    // ==================================================
    `uvm_object_utils(fft_scenario_cfg)

    // ==================================================
    // Randomized Scenario Fields
    // ==================================================
    rand int unsigned num_frames;
    rand bit [31:0]   frames[][]; // [frame_idx][sample_idx] (32 samples per frame)

    // ==================================================
    // Constraints
    // ==================================================
    constraint c_num_frames {
        soft num_frames inside {[3:8]};
    }

    constraint c_frames_dim {
        frames.size() == num_frames;
        foreach (frames[i]) {
            frames[i].size() == 32;
        }
    }

    // ==================================================
    // Constructor
    // ==================================================
    function new(string name = "fft_scenario_cfg");
        super.new(name);
        num_frames = 5;
    endfunction

    // ==================================================
    // Utility Methods
    // ==================================================
    virtual function void do_copy(uvm_object rhs);
        fft_scenario_cfg rhs_;
        if (!$cast(rhs_, rhs)) return;
        super.do_copy(rhs);
        this.num_frames = rhs_.num_frames;
        this.frames     = rhs_.frames;
    endfunction

    virtual function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field_int("num_frames", num_frames, 32, UVM_DEC);
        printer.print_int("frames_count", frames.size(), 32, UVM_DEC);
    endfunction

    virtual function string convert2string();
        string s;
        s = $sformatf("fft_scenario_cfg: num_frames=%0d, frames_allocated=%0d",
                      num_frames, frames.size());
        return s;
    endfunction

endclass : fft_scenario_cfg

`endif // FFT_SCENARIO_CFG_SVH
