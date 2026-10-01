// =============================================================================
// File Name      : ip_regs_pkg.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-01
// Version        : 1.0
// Description    : Register file address index definitions, interrupt bit masks,
//                  and memory map constants for the AHB-Lite peripheral subsystem.
// =============================================================================

package ip_regs_pkg;

    // -------------------------------------------------------------------------
    // Register Word Indices (Byte Offset = Index * 4)
    // -------------------------------------------------------------------------
    localparam logic [5:0] R_ID         = 6'd0; // 0x00: RO  - Hardware Peripheral ID
    localparam logic [5:0] R_VERSION    = 6'd1; // 0x04: RO  - Hardware Core Version
    localparam logic [5:0] R_CTRL       = 6'd2; // 0x08: RW  - Control [0]en [1]soft_rst [2]flush_in [3]flush_out
    localparam logic [5:0] R_STATUS     = 6'd3; // 0x0C: RO  - Live Core and FIFO Status
    localparam logic [5:0] R_INT_EN     = 6'd4; // 0x10: RW  - Interrupt Enable Mask
    localparam logic [5:0] R_INT_STATUS = 6'd5; // 0x14: RO* - Interrupt Status (Live Levels + W1C Sticky Flags)
    localparam logic [5:0] R_IN_LEVEL   = 6'd6; // 0x18: RO  - Words Available in IN FIFO
    localparam logic [5:0] R_OUT_LEVEL  = 6'd7; // 0x1C: RO  - Words Available in OUT FIFO
    localparam logic [5:0] R_IN_THRESH  = 6'd8; // 0x20: RW  - IN FIFO Almost-Empty Threshold
    localparam logic [5:0] R_OUT_THRESH = 6'd9; // 0x24: RW  - OUT FIFO Almost-Full Threshold

    // -------------------------------------------------------------------------
    // Interrupt Status & Enable Bit Field Positions
    // -------------------------------------------------------------------------
    localparam int INT_OUT_ALMOST_FULL = 0; // Live level >= out_thresh
    localparam int INT_OUT_NOT_EMPTY   = 1; // Live level > 0
    localparam int INT_IN_ALMOST_EMPTY = 2; // Live level <= in_thresh
    localparam int INT_IN_EMPTY        = 3; // Live level == 0
    localparam int INT_OUT_FULL        = 4; // Live level == OUT_DEPTH
    localparam int INT_IN_OVERFLOW     = 5; // Sticky (W1C): Push attempted when IN FIFO was full
    localparam int INT_OUT_UNDERFLOW   = 6; // Sticky (W1C): Pop attempted when OUT FIFO was empty
    localparam int INT_FRAME_DONE      = 7; // Sticky (W1C): Complete FFT frame generated and output

    // FIFO Data Window: Byte Offsets 0x100 - 0x1FF (Write -> IN FIFO, Read -> OUT FIFO)

endpackage : ip_regs_pkg
