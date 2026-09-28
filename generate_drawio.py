"""
Generates the simplified, visual-focused, schematic-style Draw.io diagram
for the 32-Point Radix-2 DIF R2SDF FFT.
Updated I/O: Simplified to pure valid_in / valid_out (no SOP / EOP).
"""

import xml.etree.ElementTree as ET
from xml.dom import minidom

class SchematicBuilder:
    def __init__(self):
        self.root = ET.Element('mxfile', {
            'host': 'Electron',
            'agent': 'Antigravity RTL2GDS Assistant',
            'version': '21.0.0',
            'type': 'device'
        })
        self.cell_id = 2

    def next_id(self):
        self.cell_id += 1
        return str(self.cell_id)

    def add_diagram(self, name, width=1500, height=800):
        diag = ET.SubElement(self.root, 'diagram', {'id': f'diag_{name.replace(" ", "_")}', 'name': name})
        model = ET.SubElement(diag, 'mxGraphModel', {
            'dx': '1200', 'dy': '800', 'grid': '1', 'gridSize': '10', 'guides': '1',
            'tooltips': '1', 'connect': '1', 'arrows': '1', 'fold': '1', 'page': '1',
            'pageScale': '1', 'pageWidth': str(width), 'pageHeight': str(height),
            'math': '0', 'shadow': '0'
        })
        root_cell = ET.SubElement(model, 'root')
        ET.SubElement(root_cell, 'mxCell', {'id': '0'})
        ET.SubElement(root_cell, 'mxCell', {'id': '1', 'parent': '0'})
        return root_cell

    def add_node(self, parent, value, x, y, w, h, style):
        cid = self.next_id()
        cell = ET.SubElement(parent, 'mxCell', {
            'id': cid,
            'value': value,
            'style': style,
            'vertex': '1',
            'parent': '1'
        })
        ET.SubElement(cell, 'mxGeometry', {
            'x': str(x), 'y': str(y), 'width': str(w), 'height': str(h), 'as': 'geometry'
        })
        return cid

    def add_edge(self, parent, value, src, tgt, style, points=None):
        cid = self.next_id()
        cell = ET.SubElement(parent, 'mxCell', {
            'id': cid,
            'value': value,
            'style': style,
            'edge': '1',
            'parent': '1',
            'source': src,
            'target': tgt
        })
        geom = ET.SubElement(cell, 'mxGeometry', {'relative': '1', 'as': 'geometry'})
        if points:
            arr = ET.SubElement(geom, 'Array', {'as': 'points'})
            for px, py in points:
                ET.SubElement(arr, 'mxPoint', {'x': str(px), 'y': str(py)})
        return cid

def generate_clean_drawio(filename):
    b = SchematicBuilder()

    # Shared Styles
    TITLE = "rounded=0;whiteSpace=wrap;html=1;fillColor=#1a237e;fontColor=#ffffff;fontStyle=1;fontSize=14;align=center;strokeColor=#0d47a1;"
    PORT  = "rounded=1;whiteSpace=wrap;html=1;fillColor=#eceff1;strokeColor=#455a64;strokeWidth=1.5;fontSize=11;fontColor=#263238;fontStyle=1;align=center;"
    BLOCK = "rounded=1;whiteSpace=wrap;html=1;fillColor=#f8f9fa;strokeColor=#37474f;strokeWidth=2;fontSize=11;fontColor=#212121;fontStyle=1;align=center;"
    STAGE = "rounded=1;whiteSpace=wrap;html=1;fillColor=#e3f2fd;strokeColor=#1565c0;strokeWidth=2;fontSize=11;fontColor=#0d47a1;fontStyle=1;align=center;"
    CTRL  = "rounded=1;whiteSpace=wrap;html=1;fillColor=#f3e5f5;strokeColor=#7b1fa2;strokeWidth=2;fontSize=11;fontColor=#4a148c;fontStyle=1;align=center;"
    MEM   = "rounded=1;whiteSpace=wrap;html=1;fillColor=#ede7f6;strokeColor=#4527a0;strokeWidth=2;fontSize=11;fontColor=#311b92;fontStyle=1;align=center;"
    PE    = "rounded=1;whiteSpace=wrap;html=1;fillColor=#e8f8f5;strokeColor=#00796b;strokeWidth=2;fontSize=11;fontColor=#004d40;fontStyle=1;align=center;"
    MULT  = "shape=ellipse;whiteSpace=wrap;html=1;fillColor=#fff3e0;strokeColor=#e65100;strokeWidth=2;fontSize=14;fontColor=#bf360c;fontStyle=1;align=center;"
    ALU_OP = "shape=ellipse;whiteSpace=wrap;html=1;fillColor=#e8f5e9;strokeColor=#2e7d32;strokeWidth=2;fontSize=16;fontColor=#1b5e20;fontStyle=1;align=center;"
    MUX   = "shape=trapezoid;perimeter=trapezoidPerimeter;whiteSpace=wrap;html=1;fixedSize=1;direction=south;fillColor=#fffde7;strokeColor=#f57f17;strokeWidth=2;fontSize=10;fontColor=#e65100;fontStyle=1;"
    REG   = "rounded=0;whiteSpace=wrap;html=1;fillColor=#e0f7fa;strokeColor=#00838f;strokeWidth=1.5;fontSize=10;fontColor=#006064;fontStyle=1;align=center;"

    BUS   = "edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;strokeColor=#0d47a1;strokeWidth=2.5;endArrow=block;endFill=1;fontSize=10;fontColor=#0d47a1;fontStyle=1;"
    WIRE  = "edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;strokeColor=#37474f;strokeWidth=1.5;endArrow=block;endFill=1;fontSize=9;fontColor=#37474f;"
    CTRL_W= "edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;strokeColor=#c2185b;strokeWidth=1.5;dashed=1;endArrow=block;endFill=1;fontSize=9;fontColor=#c2185b;"
    FBACK = "edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;jettySize=auto;html=1;strokeColor=#00796b;strokeWidth=2;endArrow=block;endFill=1;fontSize=9;fontColor=#00796b;fontStyle=1;"

    # =========================================================================
    # TAB 1: TOP-LEVEL SCHEMATIC (Simplified I/O: pure valid_in / valid_out)
    # =========================================================================
    p1 = b.add_diagram("1. Top-Level Core", 1500, 750)
    
    b.add_node(p1, "32-Point Radix-2 DIF FFT Core (Top-Level Architecture)", 40, 20, 1420, 40, TITLE)

    # Controller Block (Top Center)
    ctrl = b.add_node(p1, "<b>fft_controller</b><br/>CNT[4:0] Counter<br/>Valid Pipeline (31 Cycles)", 300, 90, 880, 55, CTRL)

    # Input Ports (Left) - Pure valid_in, in_data_re, in_data_im
    in_re = b.add_node(p1, "IN_RE[15:0]", 50, 230, 100, 35, PORT)
    in_im = b.add_node(p1, "IN_IM[15:0]", 50, 280, 100, 35, PORT)
    in_v  = b.add_node(p1, "VALID_IN",   50, 100, 100, 35, PORT)

    # 5 Stages
    st1 = b.add_node(p1, "<b>STAGE 1</b><br/>D = 16<br/>BF 1<br/>Mult (W32)", 240, 220, 140, 120, STAGE)
    st2 = b.add_node(p1, "<b>STAGE 2</b><br/>D = 8<br/>BF 2<br/>Mult (W16)", 460, 220, 140, 120, STAGE)
    st3 = b.add_node(p1, "<b>STAGE 3</b><br/>D = 4<br/>BF 3<br/>Mult (W8)",  680, 220, 140, 120, STAGE)
    st4 = b.add_node(p1, "<b>STAGE 4</b><br/>D = 2<br/>BF 4<br/>Mux (W4)",   900, 220, 140, 120, STAGE)
    st5 = b.add_node(p1, "<b>STAGE 5</b><br/>D = 1<br/>BF 5<br/>Wire (W2)",  1120, 220, 140, 120, STAGE)

    # Output Ports (Right) - Pure valid_out, out_data_re, out_data_im
    out_re = b.add_node(p1, "OUT_RE[15:0]", 1330, 230, 110, 35, PORT)
    out_im = b.add_node(p1, "OUT_IM[15:0]", 1330, 280, 110, 35, PORT)
    out_v  = b.add_node(p1, "VALID_OUT",    1330, 100, 110, 35, PORT)

    # Datapath Wires
    b.add_edge(p1, "[15:0]", in_re, st1, BUS, [(180, 247), (180, 260)])
    b.add_edge(p1, "[15:0]", in_im, st1, BUS, [(180, 297), (180, 280)])
    b.add_edge(p1, "32b", st1, st2, BUS)
    b.add_edge(p1, "32b", st2, st3, BUS)
    b.add_edge(p1, "32b", st3, st4, BUS)
    b.add_edge(p1, "32b", st4, st5, BUS)
    b.add_edge(p1, "[15:0]", st5, out_re, BUS, [(1290, 260), (1290, 247)])
    b.add_edge(p1, "[15:0]", st5, out_im, BUS, [(1290, 280), (1290, 297)])

    # Controller Wires
    b.add_edge(p1, "valid_in", in_v, ctrl, CTRL_W)
    b.add_edge(p1, "cnt[4], addr[3:0]", ctrl, st1, CTRL_W, [(310, 180)])
    b.add_edge(p1, "cnt[3], addr[2:0]", ctrl, st2, CTRL_W, [(530, 180)])
    b.add_edge(p1, "cnt[2], addr[1:0]", ctrl, st3, CTRL_W, [(750, 180)])
    b.add_edge(p1, "cnt[1], cnt[0]",    ctrl, st4, CTRL_W, [(970, 180)])
    b.add_edge(p1, "cnt[0]",            ctrl, st5, CTRL_W, [(1190, 180)])
    b.add_edge(p1, "valid_out", ctrl, out_v, CTRL_W)

    # Footnote labels
    b.add_node(p1, "Data: 16-bit Q1.15 Re + 16-bit Q1.15 Im (32-bit Bus) | Scaling: /2 per stage | Latency: 31 Cycles", 380, 410, 720, 30, REG)

    # =========================================================================
    # TAB 2: R2SDF STAGE SCHEMATIC
    # =========================================================================
    p2 = b.add_diagram("2. R2SDF Stage", 1500, 750)
    
    b.add_node(p2, "Canonical R2SDF Stage Schematic (Parameter: Delay D in {16, 8, 4, 2, 1})", 40, 20, 1420, 40, TITLE)

    # Ports
    st_in = b.add_node(p2, "STAGE_IN<br/>[31:0]", 50, 230, 90, 50, PORT)
    st_out= b.add_node(p2, "STAGE_OUT<br/>[31:0]", 1360, 230, 90, 50, PORT)
    sel_p = b.add_node(p2, "SEL = cnt[i]", 650, 80, 110, 30, CTRL)

    # Components
    mux1  = b.add_node(p2, "MUX 1", 230, 215, 50, 80, MUX)
    delay = b.add_node(p2, "<b>DELAY BUFFER</b><br/>Depth = D<br/>(D x 32b)", 360, 215, 140, 80, MEM)
    bf    = b.add_node(p2, "<b>BUTTERFLY PE</b><br/>(Radix-2 DIF)<br/>SUM = (A+B)/2<br/>DIFF = (A-B)/2", 610, 180, 160, 100, PE)
    
    tw_lut = b.add_node(p2, "ROM<br/>W_N^k", 940, 430, 70, 50, CTRL)
    mult   = b.add_node(p2, "X", 940, 310, 70, 70, MULT)
    mux2   = b.add_node(p2, "MUX 2", 1190, 215, 50, 80, MUX)

    # Wires
    b.add_edge(p2, "In (sel=0)", st_in, mux1, BUS, [(180, 255)])
    b.add_edge(p2, "", mux1, delay, BUS)
    
    b.add_edge(p2, "A", delay, bf, BUS, [(540, 255), (540, 210)])
    b.add_edge(p2, "B", st_in, bf, BUS, [(180, 255), (180, 150), (570, 150), (570, 240)])
    
    b.add_edge(p2, "SUM (sel=1)", bf, mux2, BUS, [(840, 210), (1140, 210), (1140, 235)])
    b.add_edge(p2, "DIFF Feedback (sel=1)", bf, mux1, FBACK, [(810, 260), (810, 360), (255, 360), (255, 295)])
    
    b.add_edge(p2, "DIFF Emerging", delay, mult, BUS, [(540, 255), (540, 345)])
    b.add_edge(p2, "W_N^k", tw_lut, mult, BUS)
    b.add_edge(p2, "DIFF*W (sel=0)", mult, mux2, BUS, [(1070, 345), (1140, 345), (1140, 275)])
    
    b.add_edge(p2, "", mux2, st_out, BUS)

    b.add_edge(p2, "sel", sel_p, mux1, CTRL_W, [(255, 95)])
    b.add_edge(p2, "sel", sel_p, mux2, CTRL_W, [(1215, 95)])

    b.add_node(p2, "<b>PHASE 0 (sel = 0, D Cycles):</b> MUX1 = In (Load) | MUX2 = Mult Output (Flush)", 280, 480, 440, 30, REG)
    b.add_node(p2, "<b>PHASE 1 (sel = 1, D Cycles):</b> MUX1 = DIFF (Feedback) | MUX2 = SUM (Direct Out)", 760, 480, 440, 30, REG)

    # =========================================================================
    # TAB 3: BUTTERFLY PE SCHEMATIC
    # =========================================================================
    p3 = b.add_diagram("3. Butterfly PE", 1500, 750)
    
    b.add_node(p3, "Radix-2 DIF Butterfly Datapath (Shown for Real/Imag Parallel Channels)", 40, 20, 1420, 40, TITLE)

    a_in = b.add_node(p3, "A[15:0]", 60, 180, 80, 35, PORT)
    b_in = b.add_node(p3, "B[15:0]", 60, 280, 80, 35, PORT)

    add_node = b.add_node(p3, "+", 240, 175, 45, 45, ALU_OP)
    sub_node = b.add_node(p3, "-", 240, 275, 45, 45, ALU_OP)

    rnd_a = b.add_node(p3, "+ 1", 390, 175, 45, 45, ALU_OP)
    rnd_s = b.add_node(p3, "+ 1", 390, 275, 45, 45, ALU_OP)

    shf_a = b.add_node(p3, ">>> 1", 520, 180, 70, 35, PE)
    shf_s = b.add_node(p3, ">>> 1", 520, 280, 70, 35, PE)

    sat_a = b.add_node(p3, "SAT", 680, 180, 60, 35, BLOCK)
    sat_s = b.add_node(p3, "SAT", 680, 280, 60, 35, BLOCK)

    sum_out  = b.add_node(p3, "SUM[15:0]",  840, 180, 90, 35, PORT)
    diff_out = b.add_node(p3, "DIFF[15:0]", 840, 280, 90, 35, PORT)

    b.add_edge(p3, "", a_in, add_node, BUS)
    b.add_edge(p3, "", b_in, add_node, BUS, [(180, 297), (180, 210)])
    b.add_edge(p3, "", a_in, sub_node, BUS, [(180, 197), (180, 285)])
    b.add_edge(p3, "", b_in, sub_node, BUS)

    b.add_edge(p3, "17b", add_node, rnd_a, BUS)
    b.add_edge(p3, "17b", sub_node, rnd_s, BUS)

    b.add_edge(p3, "17b", rnd_a, shf_a, BUS)
    b.add_edge(p3, "17b", rnd_s, shf_s, BUS)

    b.add_edge(p3, "16b", shf_a, sat_a, BUS)
    b.add_edge(p3, "16b", shf_s, sat_s, BUS)

    b.add_edge(p3, "", sat_a, sum_out, BUS)
    b.add_edge(p3, "", sat_s, diff_out, BUS)

    b.add_node(p3, "<b>Arithmetic:</b> SUM = SAT((A + B + 1) >>> 1)  |  DIFF = SAT((A - B + 1) >>> 1)<br/>Identical parallel blocks for Real and Imaginary paths.", 200, 390, 650, 40, REG)

    # =========================================================================
    # TAB 4: MULTIPLIERS & TWIDDLES SCHEMATIC
    # =========================================================================
    p4 = b.add_diagram("4. Multipliers & Twiddles", 1500, 750)
    
    b.add_node(p4, "Complex Multiplier (Stages 1..3) & Trivial Twiddle Units (Stages 4..5)", 40, 20, 1420, 40, TITLE)

    b.add_node(p4, "<b>complex_multiplier (Stages 1, 2, 3)</b>", 60, 80, 680, 30, REG)
    
    xr = b.add_node(p4, "Xr[15:0]", 60, 140, 70, 30, PORT)
    xi = b.add_node(p4, "Xi[15:0]", 60, 220, 70, 30, PORT)
    wr = b.add_node(p4, "Wr[15:0]", 60, 300, 70, 30, PORT)
    wi = b.add_node(p4, "Wi[15:0]", 60, 380, 70, 30, PORT)

    m1 = b.add_node(p4, "X", 220, 130, 40, 40, MULT)
    m2 = b.add_node(p4, "X", 220, 200, 40, 40, MULT)
    m3 = b.add_node(p4, "X", 220, 290, 40, 40, MULT)
    m4 = b.add_node(p4, "X", 220, 360, 40, 40, MULT)

    sub_m = b.add_node(p4, "-", 360, 165, 45, 45, ALU_OP)
    add_m = b.add_node(p4, "+", 360, 325, 45, 45, ALU_OP)

    rnd_r = b.add_node(p4, ">>> 15", 480, 170, 60, 35, PE)
    rnd_i = b.add_node(p4, ">>> 15", 480, 330, 60, 35, PE)

    yr = b.add_node(p4, "Yr[15:0]", 640, 170, 80, 35, PORT)
    yi = b.add_node(p4, "Yi[15:0]", 640, 330, 80, 35, PORT)

    b.add_edge(p4, "", xr, m1, WIRE)
    b.add_edge(p4, "", wr, m1, WIRE, [(170, 315), (170, 160)])
    b.add_edge(p4, "", xi, m2, WIRE)
    b.add_edge(p4, "", wi, m2, WIRE, [(180, 395), (180, 230)])

    b.add_edge(p4, "", xr, m3, WIRE, [(150, 155), (150, 300)])
    b.add_edge(p4, "", wi, m3, WIRE, [(180, 395), (180, 320)])
    b.add_edge(p4, "", xi, m4, WIRE, [(160, 235), (160, 370)])
    b.add_edge(p4, "", wr, m4, WIRE, [(170, 315), (170, 390)])

    b.add_edge(p4, "32b", m1, sub_m, WIRE)
    b.add_edge(p4, "32b", m2, sub_m, WIRE)
    b.add_edge(p4, "32b", m3, add_m, WIRE)
    b.add_edge(p4, "32b", m4, add_m, WIRE)

    b.add_edge(p4, "33b", sub_m, rnd_r, WIRE)
    b.add_edge(p4, "33b", add_m, rnd_i, WIRE)

    b.add_edge(p4, "", rnd_r, yr, BUS)
    b.add_edge(p4, "", rnd_i, yi, BUS)

    # Right: Trivial Twiddle
    b.add_node(p4, "<b>Stage 4: Trivial Twiddle (W4 in {1, -j})</b>", 820, 80, 600, 30, REG)

    t4_xr = b.add_node(p4, "Xr[15:0]", 820, 150, 70, 35, PORT)
    t4_xi = b.add_node(p4, "Xi[15:0]", 820, 230, 70, 35, PORT)
    k_sel = b.add_node(p4, "k = cnt[0]", 1000, 110, 80, 25, CTRL)

    t4_mx1 = b.add_node(p4, "MUX", 1010, 140, 45, 60, MUX)
    neg    = b.add_node(p4, "NEG (-)", 940, 290, 60, 30, PE)
    t4_mx2 = b.add_node(p4, "MUX", 1050, 230, 45, 60, MUX)

    t4_yr = b.add_node(p4, "Yr[15:0]", 1200, 150, 70, 35, PORT)
    t4_yi = b.add_node(p4, "Yi[15:0]", 1200, 240, 70, 35, PORT)

    b.add_edge(p4, "0: Xr", t4_xr, t4_mx1, WIRE)
    b.add_edge(p4, "1: Xi", t4_xi, t4_mx1, WIRE, [(920, 245), (920, 185)])
    b.add_edge(p4, "0: Xi", t4_xi, t4_mx2, WIRE)
    b.add_edge(p4, "", t4_xr, neg, WIRE, [(900, 165), (900, 305)])
    b.add_edge(p4, "1: -Xr", neg, t4_mx2, WIRE, [(1020, 305), (1020, 275)])

    b.add_edge(p4, "", t4_mx1, t4_yr, BUS)
    b.add_edge(p4, "", t4_mx2, t4_yi, BUS)
    b.add_edge(p4, "k", k_sel, t4_mx1, CTRL_W)
    b.add_edge(p4, "k", k_sel, t4_mx2, CTRL_W, [(1070, 125)])

    # Stage 5 Pass-Through
    b.add_node(p4, "<b>Stage 5: Trivial Twiddle (W2 = 1) -> Direct Wire Pass-Through</b>", 820, 370, 600, 30, REG)
    t5_in = b.add_node(p4, "X[15:0]", 820, 420, 80, 35, PORT)
    t5_out= b.add_node(p4, "Y[15:0]", 1200, 420, 80, 35, PORT)
    b.add_edge(p4, "Wire", t5_in, t5_out, BUS)

    # Save
    xml_str = ET.tostring(b.root, encoding='utf-8')
    pretty_xml = minidom.parseString(xml_str).toprettyxml(indent='  ')
    clean_lines = [l for l in pretty_xml.split('\n') if l.strip()]
    with open(filename, 'w', encoding='utf-8') as f:
        f.write('\n'.join(clean_lines))
    print(f"Generated clean schematic with simplified I/O {filename} successfully!")

if __name__ == "__main__":
    generate_clean_drawio("FFT32_R2SDF_Architecture.drawio")
