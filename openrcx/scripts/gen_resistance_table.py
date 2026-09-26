#!/usr/bin/env python3
"""Generates an OpenRCX-compatible resistance table (the "resistance.TYP"
file `read_rcx_tables` expects alongside the capacitance `.caps` file --
see `calibration/fasterCap/Makefile` in openroad-fork for the reference
`model:` target this mirrors).

Resistance for a straight rectangular wire segment needs no field solver:
    sheet_resistance (ohm/sq) = RPSQ, read directly from the PDK's own
        nxtgrd/GT2.itf (the primary source -- NOT derived through our own
        gt2n_process_{frontside,backside}.pro translation, since that
        translation's derivation comment is our own and not independently
        authoritative on its own).
    R_total = RPSQ * (length / width)
Every pattern this project generates uses width == min_width and
LEN == 10 (10 widths long), so length/width == LEN exactly and
R_total == RPSQ * LEN -- a pure per-layer constant, independent of the
spacing sweeps that matter for capacitance.

Cross-validated three independent ways before trusting this:
  1. nxtgrd/GT2.itf's own RPSQ field (primary source used here).
  2. gt2n_process_{frontside,backside}.pro's resistivity/thickness
     (our own translation -- checked below to agree with #1 as a sanity
     gate, not trusted on its own). Confirmed exact (0.000% diff) on
     all 21 conductors, no exceptions.
  3. openroad-fork/test/gt2n_data/setRC.tcl, the analytical model
     ALREADY driving real GT2N STA in HighTide today: RPSQ/min_width
     matches its -resistance (ohm/um) values to the decimal on every
     layer it lists except RDL/BRDL (0.00625 vs its 0.01) -- a
     different quantity than what this script computes (R for a fixed
     LEN=10-widths segment, not ohm/um), so it doesn't bear on this
     table's correctness, but noted here since it's a real, if minor,
     wrinkle in the PDK data worth being aware of.

Output line format (reverse-engineered from extRCmodel_solver.cpp's
readRCvalues/parseMets/getAllowedPatternWireNums -- no example or
generator for this file exists anywhere in the codebase, this was
derived from the C++ reader itself, not copied from a reference):
    Metal <met> RESOVER 0 Under 0 Dist 0 Width <w> LEN <len> CC 0 FR 0 \
        TC 0 CC2 0 RES <resistance> <name>_res/wire_0
word[2]=="RESOVER" (not "Over") is what sets extMeasure::_res in
parseMets(); "wire is 0" for resistance lines per that file's own
comment. CC/FR/TC/CC2 are zeroed placeholders so the shared parser's
word offsets (width at word 9, LEN at word 11, resistance at word 21)
line up identically to a real capacitance line.

Two Dist samples per layer (not one), both carrying the identical RES
value: this project originally emitted a single Dist=0 sample per
layer, since R is physically distance-independent. That crashes real
extraction. write_rcx_model serializes RESOVER data to disk as compact
"<coupling> <sep> <fringe> <res>" DIST blocks (extDistRC::writeRC);
when extract_parasitics loads that file back, extDistRCTable::
readRules_res2 groups a DIST block's lines by change in the value that
lands in its coupling_ field (which, after the write/read column-order
roundtrip, is actually the ORIGINAL Dist/sep_ value, not the original
CC field) and only populates its per-group measureTableR_[] slot at
each group boundary. A single sample produces exactly one group
(measureTableR_[0] only); rcx::extDistRCTable::getComputeRC_res
unconditionally dereferences measureTableR_[1] the moment a real
design has actual coupling context (dist1+dist2 != 0) -- confirmed via
a symbolicated crash inside rcx::extMeasure::calcRes on a real routed
lfsr build (the trivial single-cell local repro used earlier never
exercised this path, since it generated 0 rc segments and no real
coupling context). Emitting a second sample at a different Dist forces
a second group, populating measureTableR_[1] -- the returned RES value
is unaffected since both samples agree.
"""
import re
import sys

ITF_FILE = "../../nxtgrd/GT2.itf"
LEN_WIDTHS = 10  # this project's universal LEN convention

# REAL routing-level numbering, from gt2n's actual unified tech LEF
# (gt2_tech.lef) -- confirmed empirically by loading it in OpenROAD and
# querying dbTechLayer::getRoutingLevel() directly (2026-09-15), NOT the
# same as either standalone process file's own 1-based table position
# (which is what this project's whole FasterCap pipeline used
# internally throughout -- fine for that, since gen_solver_patterns
# only ever saw one stack's .pro file at a time, but wrong for a real
# design, which loads a single LEF spanning both stacks). Backside
# comes FIRST (routing levels 1-6) and is reversed relative to its own
# process-file order (BRDL=1 ... BPR=6, not BPR=1 ... BRDL=6); frontside
# follows at a flat +6 offset (M0=7 ... RDL=21). Discovered when
# extract_parasitics segfaulted in extMain::getResCapTable(), which
# unconditionally iterates every routing layer in the design's loaded
# tech LEF -- a model built with the wrong/local numbering either
# indexes out of bounds (crash) or silently applies the wrong layer's
# rules (worse).
REAL_MET_INDEX = {
    "BRDL": 1, "BM4": 2, "BM3": 3, "BM2": 4, "BM1": 5, "BPR": 6,
    "M0": 7, "M1": 8, "M2": 9, "M3": 10, "M4": 11, "M5": 12, "M6": 13,
    "M7": 14, "M8": 15, "M9": 16, "M10": 17, "M11": 18, "M12": 19,
    "M13": 20, "RDL": 21,
}
MET_CNT = 21

FRONTSIDE_ORDER = [f"M{i}" for i in range(14)] + ["RDL"]  # M0..M13, RDL
BACKSIDE_ORDER = ["BPR", "BM1", "BM2", "BM3", "BM4", "BRDL"]

def parse_itf(path):
    conductors = {}
    with open(path) as f:
        text = f.read()
    for m in re.finditer(
        r"CONDUCTOR\s+(\w+)\s*\{\s*THICKNESS=([\d.]+)\s+WMIN=([\d.]+)\s+SMIN=([\d.]+)\s+RPSQ=([\d.]+)",
        text,
    ):
        name, thickness, wmin, smin, rpsq = m.groups()
        conductors[name] = {
            "thickness": float(thickness),
            "wmin": float(wmin),
            "rpsq": float(rpsq),
        }
    return conductors


def parse_pro_resistivity(path):
    """Cross-check source only -- resistivity/thickness should reproduce
    the same RPSQ as GT2.itf's own field. Not used as the value of
    record."""
    resistivity = {}
    thickness = {}
    with open(path) as f:
        text = f.read()
    for m in re.finditer(
        r"CONDUCTOR\s+(\w+)\s*\{([^}]*)\}", text, re.DOTALL
    ):
        name, body = m.groups()
        th = re.search(r"thickness\s+([\d.]+)", body)
        res = re.search(r"resistivity\s+([\d.]+)", body)
        if th and res:
            thickness[name] = float(th.group(1))
            resistivity[name] = float(res.group(1))
    return resistivity, thickness


def build_resistance_line(met_index, name, wmin, rpsq, dist):
    r_total = rpsq * LEN_WIDTHS
    # getAllowedPatternWireNums() requires the trailing pattern-name field
    # to have exactly 5 '/'-separated segments (family/pair/width/spacing/
    # wire) -- it indexes backward from the end (p.get(n2-5)) with no
    # bounds check, so anything shorter crashes with a negative index
    # (confirmed: segfaults in getAllowedPatternWireNums on a 2-segment
    # name). First segment must end in a digit (extSolverGen::getLastCharInt
    # reads it via a plain last-char digit check) -- "Res1" here is an
    # arbitrary label for that purpose, never actually consulted for
    # resistance rows (the m._res branch returns immediately on wire_num
    # == 0 before pattern_num is used further).
    pattern_name = f"Res1/{name}_res/W{wmin}_W{wmin}/S{dist}_S{dist}_L10/wire_0"
    return (
        f"Metal {met_index} RESOVER 0 Under 0 Dist {dist} Width {wmin} "
        f"LEN {LEN_WIDTHS} CC 0 FR 0 TC 0 CC2 0 RES {r_total:.6f} "
        f"{pattern_name}"
    )


def main():
    itf = parse_itf(ITF_FILE)

    for stack, order, pro_file in [
        ("frontside", FRONTSIDE_ORDER, "../gt2n_process_frontside.pro"),
        ("backside", BACKSIDE_ORDER, "../gt2n_process_backside.pro"),
    ]:
        pro_resistivity, pro_thickness = parse_pro_resistivity(pro_file)

        out_lines = []
        mismatches = []
        for name in order:
            if name not in itf:
                print(f"ERROR: {name} not found in {ITF_FILE}", file=sys.stderr)
                sys.exit(1)
            rpsq_itf = itf[name]["rpsq"]
            wmin = itf[name]["wmin"]

            # cross-check against the .pro translation
            if name in pro_resistivity and name in pro_thickness:
                rpsq_pro = pro_resistivity[name] / pro_thickness[name]
                rel_diff = abs(rpsq_pro - rpsq_itf) / rpsq_itf
                if rel_diff > 0.01:
                    mismatches.append((name, rpsq_itf, rpsq_pro, rel_diff))

            met_index = REAL_MET_INDEX[name]
            # Two distinct Dist samples per layer, not one -- see module
            # docstring's "OpenRCX resistance-table reader" note. A single
            # sample leaves write_rcx_model's on-disk RESOVER data with
            # only one distance group, which never populates the loader's
            # second distance-bin slot; extract_parasitics then null-derefs
            # it (rcx::extDistRCTable::getComputeRC_res) the moment a real
            # design has actual coupling context. Both samples carry the
            # identical RES value -- R is physically distance-independent,
            # this exists purely to satisfy the reader's >=2-group
            # structural minimum, same spirit as the pattern-name-segment
            # fix above.
            out_lines.append(build_resistance_line(met_index, name, wmin, rpsq_itf, 0))
            out_lines.append(build_resistance_line(met_index, name, wmin, rpsq_itf, 1))

        if mismatches:
            print(f"REFUSING TO WRITE {stack}: unexplained RPSQ mismatches vs .pro file:", file=sys.stderr)
            for name, a, b, d in mismatches:
                print(f"  {name}: ITF={a} .pro-derived={b:.6f} ({d*100:.1f}% diff)", file=sys.stderr)
            sys.exit(1)

        out_path = f"resistance_{stack}.TYP"
        with open(out_path, "w") as f:
            f.write("\n".join(out_lines) + "\n")
        print(f"wrote {len(out_lines)} layers to {out_path}")


if __name__ == "__main__":
    main()
