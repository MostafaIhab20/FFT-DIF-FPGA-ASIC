// =============================================================================
// File Name      : ahb_types_pkg.sv
// Author         : Mostafa Ihab
// Creation Date  : 2026-10-05
// Version        : 1.0
// Description    : Package defining enumerated types and constants for AHB-Lite.
// =============================================================================

`ifndef AHB_TYPES_PKG_SV
`define AHB_TYPES_PKG_SV

package ahb_types_pkg;

    // ==================================================
    // Transfer Type Enumeration
    // ==================================================
    typedef enum logic [1:0] {
        HTRANS_IDLE   = 2'b00,
        HTRANS_BUSY   = 2'b01,
        HTRANS_NONSEQ = 2'b10,
        HTRANS_SEQ    = 2'b11
    } ahb_trans_e;

    // ==================================================
    // Burst Type Enumeration
    // ==================================================
    typedef enum logic [2:0] {
        HBURST_SINGLE = 3'b000,
        HBURST_INCR   = 3'b001,
        HBURST_WRAP4  = 3'b010,
        HBURST_INCR4  = 3'b011,
        HBURST_WRAP8  = 3'b100,
        HBURST_INCR8  = 3'b101,
        HBURST_WRAP16 = 3'b110,
        HBURST_INCR16 = 3'b111
    } ahb_burst_e;

    // ==================================================
    // Transfer Size Enumeration
    // ==================================================
    typedef enum logic [2:0] {
        HSIZE_BYTE     = 3'b000,
        HSIZE_HALFWORD = 3'b001,
        HSIZE_WORD     = 3'b010
    } ahb_size_e;

    // ==================================================
    // Response Type Enumeration
    // ==================================================
    typedef enum logic {
        HRESP_OKAY  = 1'b0,
        HRESP_ERROR = 1'b1
    } ahb_resp_e;

    // ==================================================
    // Transfer Direction Enumeration
    // ==================================================
    typedef enum bit {
        AHB_READ  = 1'b0,
        AHB_WRITE = 1'b1
    } ahb_dir_e;

    // ==================================================
    // Next Burst Address Calculation Helper
    // ==================================================
    function automatic logic [31:0] ahb_next_burst_addr(
        input logic [31:0] cur_addr,
        input ahb_burst_e  burst,
        input ahb_size_e   size
    );
        int unsigned num_bytes;
        int unsigned wrap_mask;
        num_bytes = 1 << size;

        case (burst)
            HBURST_SINGLE: return cur_addr;
            HBURST_INCR, HBURST_INCR4, HBURST_INCR8, HBURST_INCR16: begin
                return cur_addr + num_bytes;
            end
            HBURST_WRAP4: begin
                wrap_mask = (4 * num_bytes) - 1;
                return (cur_addr & ~wrap_mask) | ((cur_addr + num_bytes) & wrap_mask);
            end
            HBURST_WRAP8: begin
                wrap_mask = (8 * num_bytes) - 1;
                return (cur_addr & ~wrap_mask) | ((cur_addr + num_bytes) & wrap_mask);
            end
            HBURST_WRAP16: begin
                wrap_mask = (16 * num_bytes) - 1;
                return (cur_addr & ~wrap_mask) | ((cur_addr + num_bytes) & wrap_mask);
            end
            default: return cur_addr + num_bytes;
        endcase
    endfunction

endpackage : ahb_types_pkg

`endif // AHB_TYPES_PKG_SV
