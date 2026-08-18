# GT2N -> OpenRCX process files (draft)

Draft translation of `nxtgrd/GT2.itf` into OpenRCX's own process-stack format
(the input to OpenROAD's `gen_solver_patterns -process_file ...`). OpenRCX has
no ITF/ICT reader, so this translation step is required before any
FasterCap-based rule generation can start. Not committed yet -- review before
committing.

- `gt2n_process_frontside.pro` -- M0 through RDL (15 layers)
- `gt2n_process_backside.pro` -- BPR through BRDL (6 layers, BSPDN)

Each file's header documents the exact per-field derivation from
`GT2.itf` and the units used (resistivity in ohm*um = ITF `RPSQ * THICKNESS`).

## Verified against the real parser (not just read-through)

Both files were run through the actual `rcx::gen_solver_patterns` command
(the real C++ parser, `src/rcx/src/extprocess.cpp`) using the `openroad`
binary bazel-orfs already built (bazel's `tcl_encode` rule only bakes
`OpenRCX.tcl` into the binary, not `OpenRCX_process.tcl` -- so the friendly
`gen_solver_patterns` wrapper proc needs to be `source`d manually from
`src/rcx/src/OpenRCX_process.tcl` at runtime; the underlying
`rcx::gen_solver_patterns` swig command is already linked in). This step
needs no FasterCap -- only the solve step after pattern generation does.

- **Backside file: full run completed successfully** -- all 6 patterns
  generated, real `[INFO RCX-025x]` measurement logs, no errors.
- **Frontside file: all 15 conductors + 16 dielectrics parsed with exactly
  the intended values** (`process.out` echo cross-checked by hand: e.g.
  computed cumulative height for M9 = 1.4um, matching
  `M8.height + M8.thickness + M9_diel.thickness` exactly). Full pattern
  generation was still combinatorially working through 15-layer over/under
  patterns when stopped -- expected for a stack this size, not an error.
- **Bug found and fixed**: `DIELECTRIC` blocks must have one key/value pair
  per line. An earlier draft (and OpenROAD's own reference example at
  `rcx/test/rcx_v2/FasterCapModel/data/process`, e.g. its `m2_2` block)
  crammed multiple fields onto one line -- this silently parses as
  `epsilon=0`/`thickness=0` with **no error message**, confirmed by running
  the real parser and inspecting `process.out`. `CONDUCTOR` blocks were
  never affected. Both `.pro` files here are already fixed to one-field-
  per-line.

## Resolved

- **Topside capping dielectric**: both files end with an `air_cap`
  dielectric (epsilon=1.0) above the last conductor (RDL / BRDL). This is
  sourced, not guessed -- `qrc/GT2.ict` explicitly declares
  `background_dielectric_constant 1.0` in its `process GT2 {}` block, which
  is Cadence QRC's documented value for the region above the last declared
  layer. `GT2.itf` has no equivalent field, but StarRC's own convention
  (implicit air above the top conductor absent an explicit cap) agrees. The
  16.0um thickness is *not* a PDK value -- it's a solver boundary-size
  choice (~10x RDL/BRDL's 1.6um min_width/min_spacing, a rule of thumb to
  keep the solver's outer boundary far enough from the top conductor to
  avoid truncation error); revisit if solver accuracy/runtime needs differ.

## Not yet covered / open items

- **Via/contact resistance** (`VIA V0..V13`, `BV0..BV4`, `VG`, `VSD`,
  `VBPR` in `GT2.itf`, `RPV` values) isn't part of the process file -- it
  feeds the *final* rules/model assembly step directly (already used as-is
  in `designs/gt2n/setRC_full.tcl`'s `-via -resistance` lines), not
  `gen_solver_patterns`.
- **Device/MOL layers** (`GATE`, `ACT`, `SDCON`, `VSD`, `VG`) are excluded --
  below the lowest OpenRCX-relevant routing layer (`M0`), out of scope for
  wire RC extraction.
- **Single corner only**: GT2N currently ships one process corner (`tt`);
  these files reflect that. No Cmin/Cmax variants exist in the PDK yet.
- **Frontside/backside solved independently**: GT2N is BSPDN; the two
  stacks are separated by `BOX_diel` (buried oxide) after wafer thinning and
  have no CONDUCTOR of their own, so each side is its own field-solver
  domain referenced to its own local ground plane. No attempt is made here
  to model frontside-to-backside coupling.

## Known upstream bug (noted, not yet filed)

`qrc/GT2.ict`'s via table disagrees with `nxtgrd/GT2.itf` in two places
(cross-checked via/bottom_layer/top_layer connectivity, not just via name):

- **V11/V12/V13** (`M11->M12`, `M12->M13`, `M13->RDL`): ICT gives identical
  `area_resistance 6.08 0.003136` for all three -- looks like the table
  stopped varying after V10 and just repeats it. ITF correctly scales via
  area/resistance up through the M12/M13/RDL transition (`0.95@0.02016`,
  `0.15@0.1296`), consistent with those layers' much wider `WMIN`
  (0.056->0.360->1.600). Confirmed by grep across both files, not a rounding
  difference.
- **V4** (`M4->M5`): ITF `RPV=27.8` vs. ICT `resistance=40.52` (same area,
  0.000441) -- an isolated, unexplained mismatch, doesn't fit the
  repeated-neighbor pattern above.

ITF is the trustworthy source here (see the "reconcile ITF vs ICT"
discussion this session) -- via resistances for the final rules assembly
should come from ITF, not ICT. File an issue against
`azadnaeemi/GT2N` later; not done yet.

## FasterCap: built

`https://github.com/george-goudroumanis/FasterCAP_v2` is cloned and built at
`/home/dgaddy/research/FasterCAP_v2` (binary at `build/FasterCap`, headless
mode, version 6.0.7). Required `libwxgtk3.2-dev` (installed by mrg -- the
only dependency needing admin rights; everything else, including Eigen
despite what the README implies, was either already present or unneeded).
Two local fixes were needed on top of a stock checkout, both applied
directly in this clone:

- `FasterCap_v2/FasterCap/CMakeLists.txt`: `wxWidgets_CONFIG_OPTIONS` was
  hardcoded to `--version=3.0`; only 3.2.4 is installed, so `wx-config`
  returned nothing and CMake's `find_package(wxWidgets)` failed silently.
  Changed to `--version=3.2`.
- `FasterCap_v2/FasterCap/FasterCapConsole.cpp`: missing `#include <omp.h>`
  (`omp_set_max_active_levels` undeclared) -- the project's own README
  flags this as a known possible gap; added the include.
- Also had to delete the stale, committed `CMakeCache.txt`/`CMakeFiles`
  (leftover from the original author's machine, absolute paths pointed at
  `/home/ggeorgios-r/...`) before a fresh out-of-tree `cmake` configure
  would proceed at all.

Configured with `cmake -G"Unix Makefiles" -DCMAKE_BUILD_TYPE=Release
-DFASTFIELDSOLVERS_HEADLESS=ON ../FasterCap_v2/FasterCap`.

## Pattern generation: done for wire_cnt=1

Ran `gen_solver_patterns -wire_cnt 1 -version 1` (default corner "TYP",
default `w_list`/`s_list`/`over_dist`/`under_dist`) for both stacks into
`work/frontside/` and `work/backside/`:
- Frontside: 325 patterns, clean (no WARNING/ERROR in `rulesGen.log`).
- Backside: 68 patterns, clean.

Still open: the `-wire_cnt {2,3,5} -version 2` sweep for a fuller
calibration set (not yet attempted).

## FasterCap conversion/solve/parse chain: proven end-to-end on one pattern

Ran the full chain for `backside`'s `Over1/M1oM0` pattern (BPR over the
implicit ground plane, W=0.032um, S=0.112um, L=10um):
`gen_solver_patterns` -> `wires` -> `UniversalFormat2FasterCap_923.py` ->
`wires.lst` -> **FasterCap** (real solve, converged after 9 iterations,
weighted Frobenius norm 0.0089 < the 0.01 target) -> `wires.log` ->
`fasterCapParse.py` -> `M1oM0.caps`.

**Sanity-checked the result by hand**: converged self-capacitance for the
BPR wire was 1.31478e-16 F. A parallel-plate estimate
(`eps0*3.9*(0.032um*10um)/0.09um`, using BPR_diel's `ER`/thickness) gives
1.23e-16 F -- within 6%, consistent with the field solver capturing fringing
capacitance beyond the simple plate estimate. Real, physically sane number.

Three real bugs found and fixed in our own copies under `scripts/` (NOT
edited in the bazel-vendored OpenROAD source -- that's shared/managed by
the build system):

- **`UniversalFormat2FasterCap_923.py`**: the `Wires/`/`Dielectrics/`
  shared-panel-pool references baked into `wires.lst` are a **hardcoded**
  `"../../../../../../{}"` (6 directory levels) at two call sites -- not
  computed from actual path depth. Our real structure (confirmed for every
  pattern in both stacks) is 5 levels (`out_dir` + `family/pair/W/S`).
  Fixed both occurrences to 5 levels (`../../../../../`). Symptom before
  the fix: FasterCap immediately erroring `cannot open file
  '.../Wires/wire_....txt'`.
- **`run_fasterCap.bash`**: expects `process.out` to live *inside* `in_dir`
  (the corner directory, e.g. `TYP/`), but `gen_solver_patterns` writes it
  as `TYP`'s *sibling*. Workaround: copy `process.out` into `TYP/` (done
  for `work/backside/TYP/process.out`; do the same for frontside before
  running its chain).
  Symptom before the fix: converter errors `Specified Process File path
  does not exist!`.
- **`fasterCapParse.py`**: the single-file path (`-in_list_file` empty)
  calls `readFasterCapOutPutLog(...)` without capturing its return value,
  then references the never-assigned `retCode` right after --
  `UnboundLocalError`. The `.caps` file is already fully and correctly
  written by that point (confirmed: output content identical before/after
  the fix), so this only broke the trailing success/incomplete/empty
  summary-stats reporting. Fixed by assigning `retCode = ...`.

The wxWidgets `"Assert failure"` messages FasterCap prints to stderr are
the known-benign issue the FasterCap README itself documents (fixed
upstream in wxWidgets >= 3.1.1) -- not a real error.

## Next steps (not started)

1. Run frontside's pattern set through the same conversion/solve/parse
   chain (backside is proven; frontside just needs `process.out` copied
   into `work/frontside/TYP/` first, same workaround as backside).
2. Decide whether `wire_cnt=1` alone is a sufficient calibration set or
   whether the fuller `-wire_cnt {2,3,5} -version 2` sweep is needed before
   assembling the final rules file.
3. Batch the conversion/solve/parse chain across all 325 + 68 patterns
   (currently proven on 1 of 393), then assemble the final `.rules` file
   OpenROAD's `RCX_RULES` expects (`init_rcx_model` + `read_rcx_tables` per
   corner + `write_rcx_model`).
