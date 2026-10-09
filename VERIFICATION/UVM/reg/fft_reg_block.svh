// =============================================================================
// File Name      : fft_reg_block.svh
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-06
// Version        : 1.0
// Description    : Register model and register field definitions for the
//                  FFT subsystem Register Abstraction Layer (RAL).
// =============================================================================

`ifndef FFT_REG_BLOCK_SVH
`define FFT_REG_BLOCK_SVH

// ==================================================
// Peripheral ID Register (0x000, RO)
// ==================================================
class fft_reg_id extends uvm_reg;
    `uvm_object_utils(fft_reg_id)

    rand uvm_reg_field id;

    function new(string name = "fft_reg_id");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        id = uvm_reg_field::type_id::create("id");
        id.configure(
            .parent                 (this),
            .size                   (32),
            .lsb_pos                (0),
            .access                 ("RO"),
            .volatile               (0),
            .reset                  (32'h4950_0001),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );
    endfunction
endclass : fft_reg_id

// ==================================================
// Hardware Version Register (0x004, RO)
// ==================================================
class fft_reg_version extends uvm_reg;
    `uvm_object_utils(fft_reg_version)

    rand uvm_reg_field patch;
    rand uvm_reg_field minor;
    rand uvm_reg_field major;
    rand uvm_reg_field reserved;

    function new(string name = "fft_reg_version");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        patch = uvm_reg_field::type_id::create("patch");
        patch.configure(
            .parent                 (this),
            .size                   (8),
            .lsb_pos                (0),
            .access                 ("RO"),
            .volatile               (0),
            .reset                  (8'h00),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );

        minor = uvm_reg_field::type_id::create("minor");
        minor.configure(
            .parent                 (this),
            .size                   (8),
            .lsb_pos                (8),
            .access                 ("RO"),
            .volatile               (0),
            .reset                  (8'h00),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );

        major = uvm_reg_field::type_id::create("major");
        major.configure(
            .parent                 (this),
            .size                   (8),
            .lsb_pos                (16),
            .access                 ("RO"),
            .volatile               (0),
            .reset                  (8'h01),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );

        reserved = uvm_reg_field::type_id::create("reserved");
        reserved.configure(
            .parent                 (this),
            .size                   (8),
            .lsb_pos                (24),
            .access                 ("RO"),
            .volatile               (0),
            .reset                  (8'h00),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );
    endfunction
endclass : fft_reg_version

// ==================================================
// Control Register (0x008, RW)
// ==================================================
class fft_reg_ctrl extends uvm_reg;
    `uvm_object_utils(fft_reg_ctrl)

    rand uvm_reg_field enable;
    rand uvm_reg_field soft_reset;
    rand uvm_reg_field flush_in;
    rand uvm_reg_field flush_out;
    rand uvm_reg_field dma_en;
    rand uvm_reg_field reserved;

    function new(string name = "fft_reg_ctrl");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        enable = uvm_reg_field::type_id::create("enable");
        enable.configure(
            .parent                 (this),
            .size                   (1),
            .lsb_pos                (0),
            .access                 ("RW"),
            .volatile               (0),
            .reset                  (1'b0),
            .has_reset              (1),
            .is_rand                (1),
            .individually_accessible(1)
        );

        dma_en = uvm_reg_field::type_id::create("dma_en");
        dma_en.configure(
            .parent                 (this),
            .size                   (1),
            .lsb_pos                (1),
            .access                 ("RW"),
            .volatile               (0),
            .reset                  (1'b0),
            .has_reset              (1),
            .is_rand                (1),
            .individually_accessible(1)
        );

        reserved = uvm_reg_field::type_id::create("reserved");
        reserved.configure(
            .parent                 (this),
            .size                   (27),
            .lsb_pos                (2),
            .access                 ("RO"),
            .volatile               (0),
            .reset                  (27'h0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );

        soft_reset = uvm_reg_field::type_id::create("soft_reset");
        soft_reset.configure(
            .parent                 (this),
            .size                   (1),
            .lsb_pos                (29),
            .access                 ("WO"),
            .volatile               (1),
            .reset                  (1'b0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );

        flush_in = uvm_reg_field::type_id::create("flush_in");
        flush_in.configure(
            .parent                 (this),
            .size                   (1),
            .lsb_pos                (30),
            .access                 ("WO"),
            .volatile               (1),
            .reset                  (1'b0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );

        flush_out = uvm_reg_field::type_id::create("flush_out");
        flush_out.configure(
            .parent                 (this),
            .size                   (1),
            .lsb_pos                (31),
            .access                 ("WO"),
            .volatile               (1),
            .reset                  (1'b0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );
    endfunction
endclass : fft_reg_ctrl

// ==================================================
// Status Register (0x00C, RO)
// ==================================================
class fft_reg_status extends uvm_reg;
    `uvm_object_utils(fft_reg_status)

    rand uvm_reg_field busy;
    rand uvm_reg_field in_empty;
    rand uvm_reg_field in_full;
    rand uvm_reg_field out_empty;
    rand uvm_reg_field out_full;
    rand uvm_reg_field in_almost_empty;
    rand uvm_reg_field out_almost_full;
    rand uvm_reg_field reserved;

    function new(string name = "fft_reg_status");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        busy = uvm_reg_field::type_id::create("busy");
        busy.configure(
            .parent                 (this),
            .size                   (1),
            .lsb_pos                (0),
            .access                 ("RO"),
            .volatile               (1),
            .reset                  (1'b0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );

        in_empty = uvm_reg_field::type_id::create("in_empty");
        in_empty.configure(
            .parent                 (this),
            .size                   (1),
            .lsb_pos                (1),
            .access                 ("RO"),
            .volatile               (1),
            .reset                  (1'b1),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );

        in_full = uvm_reg_field::type_id::create("in_full");
        in_full.configure(
            .parent                 (this),
            .size                   (1),
            .lsb_pos                (2),
            .access                 ("RO"),
            .volatile               (1),
            .reset                  (1'b0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );

        out_empty = uvm_reg_field::type_id::create("out_empty");
        out_empty.configure(
            .parent                 (this),
            .size                   (1),
            .lsb_pos                (3),
            .access                 ("RO"),
            .volatile               (1),
            .reset                  (1'b1),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );

        out_full = uvm_reg_field::type_id::create("out_full");
        out_full.configure(
            .parent                 (this),
            .size                   (1),
            .lsb_pos                (4),
            .access                 ("RO"),
            .volatile               (1),
            .reset                  (1'b0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );

        in_almost_empty = uvm_reg_field::type_id::create("in_almost_empty");
        in_almost_empty.configure(
            .parent                 (this),
            .size                   (1),
            .lsb_pos                (5),
            .access                 ("RO"),
            .volatile               (1),
            .reset                  (1'b1),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );

        out_almost_full = uvm_reg_field::type_id::create("out_almost_full");
        out_almost_full.configure(
            .parent                 (this),
            .size                   (1),
            .lsb_pos                (6),
            .access                 ("RO"),
            .volatile               (1),
            .reset                  (1'b0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );

        reserved = uvm_reg_field::type_id::create("reserved");
        reserved.configure(
            .parent                 (this),
            .size                   (25),
            .lsb_pos                (7),
            .access                 ("RO"),
            .volatile               (0),
            .reset                  (25'h0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );
    endfunction
endclass : fft_reg_status

// ==================================================
// Interrupt Enable Register (0x010, RW)
// ==================================================
class fft_reg_int_en extends uvm_reg;
    `uvm_object_utils(fft_reg_int_en)

    rand uvm_reg_field frame_done;
    rand uvm_reg_field in_overflow;
    rand uvm_reg_field out_underflow;
    rand uvm_reg_field reserved;

    function new(string name = "fft_reg_int_en");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        frame_done = uvm_reg_field::type_id::create("frame_done");
        frame_done.configure(
            .parent                 (this),
            .size                   (1),
            .lsb_pos                (0),
            .access                 ("RW"),
            .volatile               (0),
            .reset                  (1'b0),
            .has_reset              (1),
            .is_rand                (1),
            .individually_accessible(1)
        );

        in_overflow = uvm_reg_field::type_id::create("in_overflow");
        in_overflow.configure(
            .parent                 (this),
            .size                   (1),
            .lsb_pos                (1),
            .access                 ("RW"),
            .volatile               (0),
            .reset                  (1'b0),
            .has_reset              (1),
            .is_rand                (1),
            .individually_accessible(1)
        );

        out_underflow = uvm_reg_field::type_id::create("out_underflow");
        out_underflow.configure(
            .parent                 (this),
            .size                   (1),
            .lsb_pos                (2),
            .access                 ("RW"),
            .volatile               (0),
            .reset                  (1'b0),
            .has_reset              (1),
            .is_rand                (1),
            .individually_accessible(1)
        );

        reserved = uvm_reg_field::type_id::create("reserved");
        reserved.configure(
            .parent                 (this),
            .size                   (29),
            .lsb_pos                (3),
            .access                 ("RO"),
            .volatile               (0),
            .reset                  (29'h0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );
    endfunction
endclass : fft_reg_int_en

// ==================================================
// Interrupt Status Register (0x014, W1C)
// ==================================================
class fft_reg_int_status extends uvm_reg;
    `uvm_object_utils(fft_reg_int_status)

    rand uvm_reg_field frame_done;
    rand uvm_reg_field in_overflow;
    rand uvm_reg_field out_underflow;
    rand uvm_reg_field reserved;

    function new(string name = "fft_reg_int_status");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        frame_done = uvm_reg_field::type_id::create("frame_done");
        frame_done.configure(
            .parent                 (this),
            .size                   (1),
            .lsb_pos                (0),
            .access                 ("W1C"),
            .volatile               (1),
            .reset                  (1'b0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );

        in_overflow = uvm_reg_field::type_id::create("in_overflow");
        in_overflow.configure(
            .parent                 (this),
            .size                   (1),
            .lsb_pos                (1),
            .access                 ("W1C"),
            .volatile               (1),
            .reset                  (1'b0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );

        out_underflow = uvm_reg_field::type_id::create("out_underflow");
        out_underflow.configure(
            .parent                 (this),
            .size                   (1),
            .lsb_pos                (2),
            .access                 ("W1C"),
            .volatile               (1),
            .reset                  (1'b0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );

        reserved = uvm_reg_field::type_id::create("reserved");
        reserved.configure(
            .parent                 (this),
            .size                   (29),
            .lsb_pos                (3),
            .access                 ("RO"),
            .volatile               (0),
            .reset                  (29'h0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );
    endfunction
endclass : fft_reg_int_status

// ==================================================
// Input FIFO Level Register (0x018, RO)
// ==================================================
class fft_reg_in_level extends uvm_reg;
    `uvm_object_utils(fft_reg_in_level)

    rand uvm_reg_field in_level;
    rand uvm_reg_field reserved;

    function new(string name = "fft_reg_in_level");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        in_level = uvm_reg_field::type_id::create("in_level");
        in_level.configure(
            .parent                 (this),
            .size                   (16),
            .lsb_pos                (0),
            .access                 ("RO"),
            .volatile               (1),
            .reset                  (16'h0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );

        reserved = uvm_reg_field::type_id::create("reserved");
        reserved.configure(
            .parent                 (this),
            .size                   (16),
            .lsb_pos                (16),
            .access                 ("RO"),
            .volatile               (0),
            .reset                  (16'h0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );
    endfunction
endclass : fft_reg_in_level

// ==================================================
// Output FIFO Level Register (0x01C, RO)
// ==================================================
class fft_reg_out_level extends uvm_reg;
    `uvm_object_utils(fft_reg_out_level)

    rand uvm_reg_field out_level;
    rand uvm_reg_field reserved;

    function new(string name = "fft_reg_out_level");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        out_level = uvm_reg_field::type_id::create("out_level");
        out_level.configure(
            .parent                 (this),
            .size                   (16),
            .lsb_pos                (0),
            .access                 ("RO"),
            .volatile               (1),
            .reset                  (16'h0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );

        reserved = uvm_reg_field::type_id::create("reserved");
        reserved.configure(
            .parent                 (this),
            .size                   (16),
            .lsb_pos                (16),
            .access                 ("RO"),
            .volatile               (0),
            .reset                  (16'h0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );
    endfunction
endclass : fft_reg_out_level

// ==================================================
// Input FIFO Threshold Register (0x020, RW)
// ==================================================
class fft_reg_in_thresh extends uvm_reg;
    `uvm_object_utils(fft_reg_in_thresh)

    rand uvm_reg_field in_thresh;
    rand uvm_reg_field reserved;

    function new(string name = "fft_reg_in_thresh");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        in_thresh = uvm_reg_field::type_id::create("in_thresh");
        in_thresh.configure(
            .parent                 (this),
            .size                   (16),
            .lsb_pos                (0),
            .access                 ("RW"),
            .volatile               (0),
            .reset                  (16'd16),
            .has_reset              (1),
            .is_rand                (1),
            .individually_accessible(1)
        );

        reserved = uvm_reg_field::type_id::create("reserved");
        reserved.configure(
            .parent                 (this),
            .size                   (16),
            .lsb_pos                (16),
            .access                 ("RO"),
            .volatile               (0),
            .reset                  (16'h0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );
    endfunction
endclass : fft_reg_in_thresh

// ==================================================
// Output FIFO Threshold Register (0x024, RW)
// ==================================================
class fft_reg_out_thresh extends uvm_reg;
    `uvm_object_utils(fft_reg_out_thresh)

    rand uvm_reg_field out_thresh;
    rand uvm_reg_field reserved;

    function new(string name = "fft_reg_out_thresh");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        out_thresh = uvm_reg_field::type_id::create("out_thresh");
        out_thresh.configure(
            .parent                 (this),
            .size                   (16),
            .lsb_pos                (0),
            .access                 ("RW"),
            .volatile               (0),
            .reset                  (16'd48),
            .has_reset              (1),
            .is_rand                (1),
            .individually_accessible(1)
        );

        reserved = uvm_reg_field::type_id::create("reserved");
        reserved.configure(
            .parent                 (this),
            .size                   (16),
            .lsb_pos                (16),
            .access                 ("RO"),
            .volatile               (0),
            .reset                  (16'h0),
            .has_reset              (1),
            .is_rand                (0),
            .individually_accessible(1)
        );
    endfunction
endclass : fft_reg_out_thresh

// ==================================================
// FFT Subsystem Register Block
// ==================================================
class fft_reg_block extends uvm_reg_block;
    `uvm_object_utils(fft_reg_block)

    // Register Handles
    rand fft_reg_id         reg_id;
    rand fft_reg_version    reg_version;
    rand fft_reg_ctrl       reg_ctrl;
    rand fft_reg_status     reg_status;
    rand fft_reg_int_en     reg_int_en;
    rand fft_reg_int_status reg_int_status;
    rand fft_reg_in_level   reg_in_level;
    rand fft_reg_out_level  reg_out_level;
    rand fft_reg_in_thresh  reg_in_thresh;
    rand fft_reg_out_thresh reg_out_thresh;

    // Address Map Handle
    uvm_reg_map ahb_map;

    function new(string name = "fft_reg_block");
        super.new(name, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        // Create 32-bit AHB-Lite address map
        ahb_map = create_map("ahb_map", 'h0, 4, UVM_LITTLE_ENDIAN);

        // ID Register (0x000, RO)
        reg_id = fft_reg_id::type_id::create("reg_id");
        reg_id.configure(this, null, "");
        reg_id.build();
        ahb_map.add_reg(reg_id, 'h000, "RO");

        // VERSION Register (0x004, RO)
        reg_version = fft_reg_version::type_id::create("reg_version");
        reg_version.configure(this, null, "");
        reg_version.build();
        ahb_map.add_reg(reg_version, 'h004, "RO");

        // CTRL Register (0x008, RW)
        reg_ctrl = fft_reg_ctrl::type_id::create("reg_ctrl");
        reg_ctrl.configure(this, null, "");
        reg_ctrl.build();
        ahb_map.add_reg(reg_ctrl, 'h008, "RW");

        // STATUS Register (0x00C, RO)
        reg_status = fft_reg_status::type_id::create("reg_status");
        reg_status.configure(this, null, "");
        reg_status.build();
        ahb_map.add_reg(reg_status, 'h00C, "RO");

        // INT_EN Register (0x010, RW)
        reg_int_en = fft_reg_int_en::type_id::create("reg_int_en");
        reg_int_en.configure(this, null, "");
        reg_int_en.build();
        ahb_map.add_reg(reg_int_en, 'h010, "RW");

        // INT_STATUS Register (0x014, RW / W1C)
        reg_int_status = fft_reg_int_status::type_id::create("reg_int_status");
        reg_int_status.configure(this, null, "");
        reg_int_status.build();
        ahb_map.add_reg(reg_int_status, 'h014, "RW");

        // IN_LEVEL Register (0x018, RO)
        reg_in_level = fft_reg_in_level::type_id::create("reg_in_level");
        reg_in_level.configure(this, null, "");
        reg_in_level.build();
        ahb_map.add_reg(reg_in_level, 'h018, "RO");

        // OUT_LEVEL Register (0x01C, RO)
        reg_out_level = fft_reg_out_level::type_id::create("reg_out_level");
        reg_out_level.configure(this, null, "");
        reg_out_level.build();
        ahb_map.add_reg(reg_out_level, 'h01C, "RO");

        // IN_THRESH Register (0x020, RW)
        reg_in_thresh = fft_reg_in_thresh::type_id::create("reg_in_thresh");
        reg_in_thresh.configure(this, null, "");
        reg_in_thresh.build();
        ahb_map.add_reg(reg_in_thresh, 'h020, "RW");

        // OUT_THRESH Register (0x024, RW)
        reg_out_thresh = fft_reg_out_thresh::type_id::create("reg_out_thresh");
        reg_out_thresh.configure(this, null, "");
        reg_out_thresh.build();
        ahb_map.add_reg(reg_out_thresh, 'h024, "RW");

        // Lock register topology and compute field offsets
        lock_model();
    endfunction
endclass : fft_reg_block

`endif // FFT_REG_BLOCK_SVH
