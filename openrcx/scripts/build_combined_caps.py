#!/usr/bin/env python3
"""Builds the combined per-stack `.caps` file `read_rcx_tables -file`
expects, from this project's tracked completed-pattern TSVs -- mirrors
what `calibration/fasterCap/scripts/parse_fasterCap.bash` does by running
fasterCapParse.py in `-in_list_file` mode over every pattern's wires.log
and concatenating the output into one file. We already have the
equivalent per-wire lines stored in `raw_result` (the exact text
fasterCapParse.py produced at solve time), so this is a reformatting
job over data already on disk -- no FasterCap re-run needed.

Only CONVERGED_SANE rows are included (anything else has no valid
capacitance data to contribute). Rows whose raw_result is wire_1-only
(the 573 legacy RDL rows whose original source logs are unrecoverable --
see conversation record / V2_FLAG_PROGRESS_TRACKER.md) still get
included: read_rcx_tables filters by wire_index per pattern family, so
a wire_1-only row simply contributes nothing to the wc2/wc3/wc5 tables
for that specific pattern (skipped, not wrong) while still covering
wc1 fully.

Layer-index remapping (see gen_resistance_table.py's REAL_MET_INDEX for
the full discovery writeup): every wire line carries three per-stack,
1-based-local layer references -- "Metal N" (this layer), "Over N"
(0 = none), "Under N" (0 = none) -- inherited from each standalone
process file's own table position. gt2n's real unified tech LEF numbers
routing levels differently (backside 1-6 REVERSED then frontside 7-21
flat-offset), and extract_parasitics indexes per-layer tables by that
real routing level, so every layer reference must be remapped before
being written to the combined .caps file, or extraction crashes/
misapplies rules. Frontside: real = local + 6 (order-preserving --
local's own "up" direction already matches the real one, so no other
change needed).

Backside needs more than a value remap. Physically, BPR (local 1) is
the layer closest to the transistors from the back, and BRDL (local 6)
is the farthest (the outer backside surface) -- so the .pro file's own
"conductor 1..6" order runs bottom(BPR)-to-top(BRDL) *away* from the
devices. But gt2n's real unified numbering (BRDL=1..BPR=6) runs the
opposite direction: real index increases *toward* the devices (BPR=6
sits just below real level 7 = frontside M0). Local "over" (higher
local index = farther from devices = local "up") is therefore real
"under" (farther from devices = lower real index = real "down") for
every backside pair -- verified concretely: local pattern M2oM1
(BM1 over BPR, local2 over local1) remaps to real(BM1)=5, real(BPR)=6,
i.e. BM1 (real 5) is actually BELOW BPR (real 6) in real terms. So for
backside, after remapping each nonzero Over/Under value to real, the
two values must also be SWAPPED between the Over and Under fields (not
just remapped in place) to express the correct real-space relationship
-- confirmed against a real over_under sample (local "Over 1 Under 3"
on Metal 2 -> real over=6, real under=4, real met=5; only swapping
them into "Over 4 Under 6" satisfies over < met < under, as OpenRCX's
addRCw requires).

DiagUnder lines have no such fix available: OpenRCX only implements a
"coupled layer is above met" diag table (_capDiagUnder; there is no
"DiagOver" counterpart), and the same local/real reversal means every
backside DiagUnder measurement needs its coupled layer BELOW met in
real terms -- a relationship this file format cannot express, and
which cannot be recovered by an Over/Under-style field swap either
(the Width field is met's own wire width, not interchangeable with the
diag neighbor's width). These lines are dropped, not guessed at --
counted and reported separately.

Usage: python3 build_combined_caps.py
Reads (relative to scratch_logs/): v2_flag_completed_patterns.tsv,
v2_flag_completed_patterns_RDL_bonus.tsv,
v2_flag_completed_patterns_convprobe_rescue{,_v2..v11}.tsv
Writes: gt2n_frontside.caps, gt2n_backside.caps (in the current dir)
"""
import re
import sys

SCRATCH = "../../scratch_logs"
SOURCES = [
    f"{SCRATCH}/v2_flag_completed_patterns.tsv",
    f"{SCRATCH}/v2_flag_completed_patterns_RDL_bonus.tsv",
    f"{SCRATCH}/v2_flag_completed_patterns_convprobe_rescue.tsv",
    f"{SCRATCH}/v2_flag_completed_patterns_convprobe_rescue_v2.tsv",
    f"{SCRATCH}/v2_flag_completed_patterns_convprobe_rescue_v3.tsv",
    f"{SCRATCH}/v2_flag_completed_patterns_convprobe_rescue_v4.tsv",
    f"{SCRATCH}/v2_flag_completed_patterns_convprobe_rescue_v5.tsv",
    f"{SCRATCH}/v2_flag_completed_patterns_convprobe_rescue_v6.tsv",
    f"{SCRATCH}/v2_flag_completed_patterns_convprobe_rescue_v7.tsv",
    f"{SCRATCH}/v2_flag_completed_patterns_convprobe_rescue_v8.tsv",
    f"{SCRATCH}/v2_flag_completed_patterns_convprobe_rescue_v9.tsv",
    f"{SCRATCH}/v2_flag_completed_patterns_convprobe_rescue_v10.tsv",
    f"{SCRATCH}/v2_flag_completed_patterns_convprobe_rescue_v11.tsv",
]

METAL_RE = re.compile(r"Metal\s")
WIRE_LINE_RE = re.compile(
    r"^Metal (\d+) Over (\d+) (Under|DiagUnder) (\d+)(.*)$", re.DOTALL
)

DROPPED_BACKSIDE_DIAG = 0


def remap_layer_indices(line, stack):
    """Rewrite a wire line's local 1-based 'Metal/Over/(Under|DiagUnder)'
    fields to gt2n's real unified routing-level numbering. Returns None
    if the line can't be represented in real-index space (backside
    DiagUnder -- see module docstring)."""
    global DROPPED_BACKSIDE_DIAG

    m = WIRE_LINE_RE.match(line)
    if not m:
        return line  # not a recognized wire-data line; pass through untouched

    met, over_val, keyword, under_val, rest = m.groups()
    met, over_val, under_val = int(met), int(over_val), int(under_val)

    if stack == "frontside":
        real_met = met + 6
        real_over = over_val + 6 if over_val else 0
        real_under = under_val + 6 if under_val else 0
        return f"Metal {real_met} Over {real_over} {keyword} {real_under}{rest}"

    # backside
    real_met = 7 - met
    if keyword == "DiagUnder":
        DROPPED_BACKSIDE_DIAG += 1
        return None

    real_old_over = 7 - over_val if over_val else 0
    real_old_under = 7 - under_val if under_val else 0
    # swap: local "over" (farther from devices) is real "under", and
    # vice versa -- see module docstring for the physical derivation.
    new_over = real_old_under
    new_under = real_old_over
    return f"Metal {real_met} Over {new_over} {keyword} {new_under}{rest}"


def extract_wire_lines(raw_result, stack):
    """raw_result is one or more wire blocks joined by ' ~WIRE~ '. The
    first segment carries a RESULT|...| prefix before the actual
    'Metal ...' text (from how merge scripts stored the first line);
    later segments are already clean. Strip down to 'Metal ...' for
    every segment, then remap its layer indices to real routing
    levels (dropping backside DiagUnder lines that can't be
    represented)."""
    lines = []
    for segment in raw_result.split("~WIRE~"):
        segment = segment.strip()
        m = METAL_RE.search(segment)
        if not m:
            continue
        remapped = remap_layer_indices(segment[m.start():], stack)
        if remapped is not None:
            lines.append(remapped)
    return lines


def load_rows(path):
    with open(path) as f:
        header = next(f).rstrip("\n").split("\t")
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) != len(header):
                continue
            yield dict(zip(header, parts))


def main():
    by_stack = {"frontside": [], "backside": []}
    seen_keys = set()
    total_rows = 0
    total_wire_lines = 0
    skipped_dupe = 0

    for path in SOURCES:
        for row in load_rows(path):
            if row.get("verdict") != "CONVERGED_SANE":
                continue
            stack = row["stack"]
            if stack not in by_stack:
                print(f"WARNING: unknown stack {stack!r}, skipping", file=sys.stderr)
                continue
            key = (stack, row["wc"], row["pattern"])
            if key in seen_keys:
                skipped_dupe += 1
                continue
            seen_keys.add(key)
            wire_lines = extract_wire_lines(row.get("raw_result", ""), stack)
            if not wire_lines:
                print(f"WARNING: no wire lines extracted for {key}", file=sys.stderr)
                continue
            by_stack[stack].extend(wire_lines)
            total_rows += 1
            total_wire_lines += len(wire_lines)

    print(f"total patterns included: {total_rows}", file=sys.stderr)
    print(f"total wire lines written: {total_wire_lines}", file=sys.stderr)
    print(f"duplicate keys skipped (present in both source files): {skipped_dupe}", file=sys.stderr)
    print(
        f"backside DiagUnder lines dropped (unrepresentable in real-index "
        f"space, see docstring): {DROPPED_BACKSIDE_DIAG}",
        file=sys.stderr,
    )

    for stack, lines in by_stack.items():
        out_path = f"gt2n_{stack}.caps"
        with open(out_path, "w") as f:
            f.write("\n".join(lines) + "\n")
        print(f"wrote {len(lines)} wire lines to {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
