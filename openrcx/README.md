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

## Status update (2026-09-15): the plan above is done, at full scale

The three "next steps" originally listed here (frontside proven,
`wire_cnt` sweep decided, final rules file assembled) are all complete
-- scaled up far beyond the single-pattern proof above, via a full
nonstop -> 3-config experimental -> 7-config D-bracket k8s pipeline
covering **both** `wire_cnt` in `{1,2,3,5}` (the fuller sweep, not just
`wire_cnt=1`) across both stacks. See `scratch_logs/V2_FLAG_PROGRESS_TRACKER.md`
for the full history and final numbers:

- Non-RDL scope: 6,128 patterns, 5,230 converged (85.3%), 898 confirmed
  unsolvable (a real FastCap solver-precision limitation on weak/long-
  range coupling terms -- see `scratch_logs/FASTERCAP_FINDINGS.md`),
  0 remaining untouched.
- RDL/BRDL (deliberately deferred, see `scratch_logs/RDL_DEFERRED_INDEX.md`):
  1,107 total, 777 converged, 145 confirmed unsolvable, 185 untouched
  (out-of-scope v1 patterns from a separate pipeline).

## How the final rules file is actually generated

Three scripts in `scripts/` (not the calibration-flow reference scripts
above -- these are this project's own, built 2026-09-15):

1. **`gen_resistance_table.py`** -- resistance needs no field solver.
   Reads `RPSQ` directly from `nxtgrd/GT2.itf` (cross-validated 0.000%
   against both our own `.pro` translation and HighTide's already-
   running `setRC.tcl` analytical model, layer by layer). Emits
   `resistance_{frontside,backside}.TYP` in the format
   `extRCmodel_solver.cpp::readRCvalues` expects (reverse-engineered
   from the C++ source -- no example of this file exists anywhere in
   the codebase).
2. **`build_combined_caps.py`** -- concatenates every tracked
   `CONVERGED_SANE` pattern's stored `raw_result` (already-computed
   data from `scratch_logs/v2_flag_completed_patterns*.tsv`, no
   FasterCap re-run needed) into `gt2n_{frontside,backside}.caps`, the
   exact format `read_rcx_tables -file` expects (identical to what
   `fasterCapParse.py` itself produces).
3. **`gen_rules_tcl.py`** -- generates `gen_rules_{frontside,backside}.tcl`:
   `init_rcx_model -met_cnt <15|6>`, then one `read_rcx_tables` call per
   (`-wire_index` in `{1,2,3}`) x (`-over`/`-under`/`-over_under`/`-diag`)
   -- matching this project's own wc1/wc2->wire1, wc3->wire2,
   wc5->wire3 convention -- plus the resistance table, then
   `write_rcx_model`.

Run order: `gen_resistance_table.py` && `build_combined_caps.py` &&
`gen_rules_tcl.py`, then `openroad -no_init -exit gen_rules_frontside.tcl`
and same for backside (each writes its own `.rcx.model`).

**Verified against a real `openroad` binary (26Q2), not just written
blind** -- found and fixed a real crash in the resistance-line format
along the way (the pattern-name field needs exactly 5 `/`-separated
segments; `getAllowedPatternWireNums` indexes backward from the end
with no bounds check, so a shorter name segfaults). Both stacks now run
clean end-to-end (0 errors) and produce real, structurally-valid
`.rcx.model` files -- hand-verified the resistance normalization math
reproduces the model file's stored values to 5 decimal places.

## Wiring the model in: frontside only, not fused with backside

Investigated how a `.rcx.model` actually gets loaded for a real
extraction run (there is **no `read_rcx_model` command** -- confirmed
via a real working reference,
`rcx_v2/flow/gcd/scripts/gcd_flow_v2_model_v2.tcl`: the real sequence
is `get_model_corners -ext_model_file <file>` ->
`define_rcx_corners -corner_list "TYP"` ->
`set_extraction_rules_file <file>` ->
`extract_parasitics -version 2.0 ...`).

This raised whether `gt2n_frontside.rcx.model` and
`gt2n_backside.rcx.model` need to be fused into one combined model or
wired in as two separate ones for a single BSPDN design. **Neither --
they belong to two different downstream tools entirely:**

- The PDK's own native reference deck, `qrc/GT2.ict`, only defines
  `GATE`/`M0`-`M13`/`RDL` -- zero backside conductors. The PDK's own
  extraction deck never modeled backside for signal-net RC at all.
- Traced why in source: PSM (`src/psm/src/ir_solver.cpp::getResistanceMap()`)
  gets its per-layer resistance from the `est` module's simple scalar
  analytical model (`estimate_parasitics_->layerRC(...)`, the same
  thing `set_layer_rc`/`setRC.tcl` populates) -- **PSM never touches
  OpenRCX, `extract_parasitics`, or a `.rcx.model` file.** This is
  exactly what `setRC.tcl`'s own comment ("PSM needs these to build
  its resistance map") refers to, specifically for the backside
  layers.

So: **`gt2n_frontside.rcx.model` is the one real target** for
`set_extraction_rules_file` + `extract_parasitics` on an actual GT2N
build. `gt2n_backside.rcx.model` isn't consumable by PSM as generated
-- if the backside calibration work should feed IR-drop analysis
later, it needs a separate, much smaller distillation into scalar
`set_layer_rc` values, not attempted yet.

## Local test build: lfsr, in progress (2026-09-15)

Picked `lfsr` from HighTide's existing gt2n ports -- smallest by far
(~250 placed instances vs. minimax's ~60k / sha3's 36,195), already has
a documented QoR baseline, no macros/SRAM. HighTide's
`tools/bazel_to_orfs.sh designs/gt2n/lfsr` prepares a self-contained,
bazel-free ORFS bundle; copied `gt2n_frontside.rcx.model` into it and
added `export RCX_RULES?=<path-to-model>` to its `config.mk`. Ran via
`FLOW_HOME=<bazel-materialized external/orfs+> OPENROAD_EXE=<local
openroad-26Q2> YOSYS_EXE=<local yosys> ./run.sh <stage>` (HighTide
builds OpenROAD/yosys from source rather than a traditional ORFS
`tools/install/` tree, so both exes need pointing explicitly). `synth`
completed cleanly as a first smoke test.

## What it would take to make this the upstream default for gt2n

Traced where gt2n's platform files (`lef/`, `lib/`, `gds/`,
`setRC.tcl`, `config.mk`) come from: HighTide doesn't vendor them --
the whole `flow/platforms/gt2n/` directory ships inside the **pinned
OpenROAD-flow-scripts archive itself** (an `archive_override` tarball
in HighTide's `MODULE.bazel`). HighTide's own
`patches/orfs-gt2n-flow-build.patch` only adds a small platform-
registration diff, no platform data.

**Confirmed gt2n currently has zero real extraction by default,
anywhere upstream.** HighTide's `patches/orfs-no-rcx-spef-stub.patch`
patches `final_report.tcl`'s `else` branch -- the one that fires
whenever `RCX_RULES` isn't set -- to stub an empty SPEF after it prints
`"OpenRCX is not enabled for this platform. Falling back to global
route-based estimates."` and calls `estimate_parasitics
-global_routing` (an even cruder fallback than `setRC.tcl`'s per-layer
scalars). That's the branch every gt2n build currently takes.

**So the real upstream change is a PR to
`The-OpenROAD-Project/OpenROAD-flow-scripts` itself** (not HighTide,
not this repo):
1. Add `gt2n_frontside.rcx.model` into that repo's
   `flow/platforms/gt2n/` directory.
2. Add one `config.mk` line: `export RCX_RULES ?= $(PLATFORM_DIR)/gt2n_frontside.rcx.model`.
3. `final_report.tcl`'s existing `if` branch (already correct) then
   fires automatically for every gt2n design.

HighTide itself would need no code changes -- just bump the pinned
OpenROAD-flow-scripts commit once the upstream PR lands, and
`orfs-no-rcx-spef-stub.patch` becomes dead code for gt2n (check other
platforms before removing it).
