# GT2N OpenRCX rules model

A FasterCap-calibrated OpenRCX extraction rules file for GT2N (a
backside-power-delivery process, two independent metal stacks:
frontside signal routing, backside power delivery), replacing the
flat per-layer analytical model GT2N's build currently falls back to.

## Why this exists

GT2N has no OpenRCX rules file upstream. Without one, every GT2N build
falls back to `setRC.tcl`/`set_layer_rc` — a single capacitance and
resistance scalar per metal layer, with no concept of which neighbor a
wire couples to, no distance-dependence, and no distinction between
over/under/diagonal coupling. This project builds a real rules file
instead: `gen_solver_patterns` generates calibration geometry for every
relevant layer-pair/width/spacing combination, FasterCap solves each
one's actual capacitance, and the harvested results are assembled into
`rules/gt2n_combined.rcx.model`, the file `extract_parasitics` reads
per real net.

Even accounting for every gap and limitation below, this is a strict
improvement over the flat scalar it replaces: every entry in it is
real simulated physics of the correct geometry and distance-dependence
for that specific coupling relationship, not a single layer-wide
average with none of that structure at all.

## Current coverage

| scope | total | converged | gap |
|---|---|---|---|
| Non-RDL | 6,128 | 5,953 (97.1%) | 175 (2.9%) |
| RDL/BRDL | 928 | 923 (99.46%) | 5 confirmed unsolvable |

**The 175-pattern non-RDL gap** is not a silent zero. It splits into:

- **162 patterns** were blocked by a real FasterCap solver crash
  (`PotEstimateOpt`/`SIGTRAP` on numerical divergence in "Under"-type
  geometry) — now patched and validated (0 crashes across an
  11-config NRP sweep against all 162). These still fall back to a
  pooled isolated-pattern (1-2 wire) substitute for that specific
  layer-pair relationship — real measured physics of the right
  geometry and distance-dependence, just from a different wire-count
  context, with a quantified bias in the single-digit-to-low-teens
  percent range, not an unbounded error. Full detail:
  `DIAGONAL_PAIR_COVERAGE_GAPS.md`.
- The crash investigation itself: `UNDERDIAG_CRASH_INVESTIGATION.md`
  (discovery) and `FASTERCAP_BUG_REPORT.md` (the fix).
- **13** further unattributed patterns (`OverUnder5`/`Over5`/
  `OverUnder3`), same isolated-substitute fallback, no cause
  identified yet.

**RDL/BRDL**: every pattern in the true 928-pattern universe has been
attempted; only 5 are confirmed genuinely unsolvable (the same
solver-precision limitation on weak/long-range coupling documented in
`scratch_logs/FASTERCAP_FINDINGS.md`). See `scratch_logs/RDL_DEFERRED_INDEX.md`
for history.

## How to use it

```tcl
get_model_corners -ext_model_file gt2n_combined.rcx.model
define_rcx_corners -corner_list "TYP"
set_extraction_rules_file gt2n_combined.rcx.model
extract_parasitics -version 2.0 ...
```

The live file is `rules/gt2n_combined.rcx.model`. One caveat: this
model is frontside-only for any consumer besides `extract_parasitics`
— OpenROAD's PSM (power-grid analysis) gets its per-layer resistance
from the separate `set_layer_rc`/`setRC.tcl` path and never reads a
`.rcx.model` file at all, so backside power-delivery analysis still
needs that older, cruder path regardless of this model's accuracy for
signal-net RC.

To regenerate the model from scratch, or to repeat this whole process
for a different PDK, see `HOWTO.md` — it documents the full pipeline
(process-file translation, pattern generation, FasterCap quirks and
flags, cluster-scale running, rules-file assembly) in reusable detail.
This file intentionally doesn't duplicate any of that.

## How to read the rules model file

`rules/gt2n_combined.rcx.model` is plain text, organized as one block
per (reference layer, coupling family), each containing one sub-block
per neighbor layer:

```
Metal 14 DIAGUNDER 15
DIST count 360 width 0.038
0 0 0 0
0.038 0 2.99789e-05 0
...
END DIAGUNDER
```

- **`Metal <N>`** is a *combined routing-level index*, not the PDK's
  own conductor name — backside layers are 1-6, frontside layers are
  7-21 (frontside layer = its own local index + 6). This remap happens
  once, in `build_combined_caps.py` (see `HOWTO.md` Stage 5b); nothing
  past that point knows about per-stack local numbering. To find a
  specific real conductor's entries, convert first.
- **The family** is one of `OVER`/`UNDER`/`OVERUNDER`/`DIAGUNDER`
  (plus a `RESOVER` family for resistance) — `OVER`/`UNDER` are a
  direct neighbor immediately above/below; `OVERUNDER` is sandwiched on
  both sides; `DIAGUNDER` is a neighbor below, offset diagonally
  (OpenRCX has no symmetric `DIAGOVER`). A trailing `0`/`1` on the
  family name (`OVER0`, `OVER1`) is the open-ended, 1-2-wire isolated
  measurement, kept in its own table; the bare family name
  (`OVER`, `DIAGUNDER`) is the fully-coupled table that `wc3` and
  `wc5` both pool into (see `DIAGONAL_PAIR_COVERAGE_GAPS.md` for why
  that pooling matters).
- **Each `DIST count N width W` row is `<distance> <coupling>
  <fringe> <resistance>`** — confirmed directly from the reader
  (`extDistRC::readRC`, `openroad-fork/src/rcx/src/extRCmodel.cpp:74-79`):
  column 1 is separation distance, column 2 is the direct coupling
  capacitance term, column 3 is fringe capacitance, column 4 is
  resistance (always `0` here; real resistance lives in the separate
  `RESOVER` family). These are per-unit-length values in the solver's
  own internal scale, not the `pF`/`fF` units the harvested `.tsv`
  data is reported in.
- **`DIST count 0`** means no data was ever generated for that exact
  (reference, family, neighbor) triple — looked up at runtime, this
  returns `nullptr` and is treated as `0.0` added capacitance, silently,
  with no warning. Confirmed every such empty entry in this file is
  either a structurally impossible cross-stack pairing, a distance
  beyond `gen_solver_patterns`' sweep range, or one of the documented
  gaps above — not an unexplained hole.

## Status

- **Local test build**: `lfsr` (HighTide's smallest gt2n port, ~250
  instances) ran `synth` cleanly as a first smoke test with this model
  wired in via `RCX_RULES`. Not yet taken further through the flow.
- **Not yet upstream**: gt2n currently has zero real extraction by
  default anywhere upstream — every build silently falls back to a
  cruder-than-`setRC.tcl` global-route estimate
  (`orfs-no-rcx-spef-stub.patch`). Making this the default needs a PR
  to `The-OpenROAD-Project/OpenROAD-flow-scripts` itself (not
  HighTide): add `gt2n_frontside.rcx.model` to
  `flow/platforms/gt2n/`, and one `config.mk` line
  (`export RCX_RULES ?= $(PLATFORM_DIR)/gt2n_frontside.rcx.model`).
  HighTide itself needs no code changes once that lands — just bump
  the pinned OpenROAD-flow-scripts commit.

## Other docs in this directory

- `HOWTO.md` — the full, reusable generation process.
- `RULES_VALIDATION.md` — validation methodology and QoR comparison
  against the existing `setRC.tcl` baseline.
- `UNDERDIAG_CRASH_INVESTIGATION.md` / `FASTERCAP_BUG_REPORT.md` — the
  `SIGTRAP` crash: discovery and fix.
- `DIAGONAL_PAIR_COVERAGE_GAPS.md` — the remaining 14 metal-pair gaps
  in the crash-bug family: what's served for them today, why, and
  what was and wasn't fixable.
- `HIGHTIDE_QOR_COMPARISON.md` — real chip-build QoR comparison
  (setup/hold/Fmax/power) with this model wired in via `RCX_RULES`
  across HighTide's gt2n designs, against the existing `setRC.tcl`
  baselines.
- `BLACKOUT_PATTERNS.md` / `TIMING_REGRESSION_INVESTIGATION.md` /
  `MESH_EXPLOSION_INVESTIGATION.md` — the historical convergence-rescue
  effort (pre-dates the crash-bug fix).
- `scratch_logs/RDL_DEFERRED_INDEX.md` — RDL/BRDL coverage history.
