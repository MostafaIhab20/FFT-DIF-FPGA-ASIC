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

endpackage : ahb_types_pkg

`endif // AHB_TYPES_PKG_SV
