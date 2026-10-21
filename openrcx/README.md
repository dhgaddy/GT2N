# GT2N OpenRCX rules model

A FasterCap-calibrated OpenRCX extraction rules file for GT2N (a
backside-power-delivery process, two independent metal stacks:
frontside signal routing, backside power delivery). This branch
contains only the rules file itself and this README — nothing else
from the development history — so it's a minimal starting point for
anyone who wants to experiment with it.

**⚠️ Not yet validated against a reference extraction tool (Quantus /
StarRC).** Everything in this document describes what *has* been
checked (the solver's own internal convergence quality, and real
HighTide chip-build results using the model) — not an independent
cross-check against a commercial field-solver or parasitic extractor.
Treat absolute capacitance/resistance values as unverified until that
comparison exists. Relative structure (distance-dependence, which
neighbor a wire couples to, over/under/diagonal distinction) is real
measured physics either way, which is already more than the flat
model below gives you — but don't take it as ground truth yet.

## Why this exists

GT2N has no OpenRCX rules file upstream. Without one, every GT2N build
falls back to `setRC.tcl`/`set_layer_rc` — a single capacitance and
resistance scalar per metal layer, with no concept of which neighbor a
wire couples to, no distance-dependence, and no distinction between
over/under/diagonal coupling. This project builds a real rules file
instead: calibration geometry is generated for every relevant
layer-pair/width/spacing combination relevant to GT2N's process stack,
FasterCap (an open-source 3D field solver) solves each one's actual
capacitance, and the harvested results are assembled into
`rules/gt2n_combined.rcx.model`, the file `extract_parasitics` reads
per real net.

Even with the validation caveat above and the coverage gaps below,
this is a strict improvement over the flat scalar it replaces in one
specific sense: every entry in it is real simulated field-solver
physics of the correct geometry and distance-dependence for that
specific coupling relationship, not a single layer-wide average with
none of that structure at all. Whether that translates into closer
absolute agreement with a true reference extractor is exactly what
hasn't been checked yet.

## Current coverage

| scope | total patterns | converged | gap |
|---|---|---|---|
| Non-RDL (regular signal/power routing) | 6,128 | 5,953 (97.1%) | 175 (2.9%) |
| RDL/BRDL (redistribution/ground-plane layers) | 928 | 923 (99.46%) | 5 confirmed unsolvable |

A "pattern" here is one specific (layer-pair, width, spacing,
wire-count) combination FasterCap was asked to solve. "Converged"
means FasterCap produced a numerically sane capacitance/resistance
result for it (`CONVERGED_SANE`); the alternative is either a solver
crash or a solver-precision failure on very weak/long-range coupling
(root-caused and confirmed, not a parsing or config bug).

**The gap is not a silent zero.** Every one of these missing
combinations still gets served *something* at runtime — OpenRCX never
returns a null/zero lookup for them:

- **162 of the 175 non-RDL gaps** come from one specific solver crash
  bug (numerical divergence in a particular class of "Under"-type
  geometry) that has since been patched upstream in the solver fork,
  but patching the crash didn't make those specific patterns
  converge — they hit a separate, deeper solver-precision limitation
  on weak coupling instead. For these, OpenRCX falls back to a pooled
  isolated-pattern (1-2 wire) substitute for that exact layer-pair
  relationship: real measured physics of the right geometry and
  distance-dependence, just measured in a different wire-count
  context (fewer neighboring wires than the fully-coupled case). The
  quantified bias this introduces is in the single-digit-to-low-teens
  percent range — not zero, but bounded and characterized, not an
  unbounded error. 14 of the underlying metal-pair relationships (out
  of 29 affected) have *no* coverage at any spacing for this
  substitute either; those specifically fall back one level further,
  to OpenRCX's own cross-pattern interpolation using the two nearest
  patterns that do have data — still a measured-physics-based
  estimate, not a flat default.
- **13 further non-RDL patterns** (different geometric families, no
  common cause identified yet) hit the same solver-precision
  limitation and get the same isolated-pattern-substitute fallback.
- **RDL/BRDL**: every pattern in the true 928-pattern universe has
  been attempted; only 5 are confirmed genuinely unsolvable (same
  solver-precision limitation), with the same substitute-fallback
  behavior.

In short: nothing in this model silently falls back to the old flat
`setRC.tcl` value or to zero. The worst case is a same-geometry
measurement taken in a less-coupled wire context, or an interpolation
between two real nearby measurements.

## How to use it

```tcl
get_model_corners -ext_model_file gt2n_combined.rcx.model
define_rcx_corners -corner_list "TYP"
set_extraction_rules_file gt2n_combined.rcx.model
extract_parasitics -version 2.0 ...
```

The rules file is `rules/gt2n_combined.rcx.model` in this repo. In a
HighTide-style flow, point your design's `RCX_RULES` source at this
file (copy it alongside your design, or reference it directly) and
`extract_parasitics` will use it automatically instead of falling back
to a flow's global-route-based estimate.

**One caveat for backside power-delivery analysis**: this model is
frontside-only for any consumer besides `extract_parasitics`.
OpenROAD's PSM (power-grid analysis) gets its per-layer resistance
from the separate `set_layer_rc`/`setRC.tcl` path and never reads a
`.rcx.model` file at all, so backside power-delivery analysis still
needs that older, cruder path regardless of this model's accuracy for
signal-net RC. **This is a general OpenROAD architectural limitation,
not a gap in this model or something specific to GT2N** — confirmed
directly in source (`src/psm/src/ir_solver.cpp`,
`src/est/src/EstimateParasitics.cpp`): PSM's resistance lookup is
populated exclusively by the `set_layer_rc` Tcl command's literal
scalar inputs (falling back to the LEF-declared static layer
resistance if that was never called), and there is no code path
anywhere that reads an RCX rules file into it. RCX rules are consumed
only by `extract_parasitics`, which produces per-net SPEF for STA, a
different data shape than the single per-layer value PSM expects. This
would be true for any PDK's OpenRCX model, not just GT2N's.

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
  own conductor name — GT2N has two independent metal stacks (backside
  power delivery, frontside signal routing) folded into one combined
  numbering so OpenRCX can address both from a single file: backside
  layers are combined-index 1-6, frontside layers are 7-21 (a
  frontside layer's combined index is its own local PDK index + 6).
  To find a specific real conductor's entries, you need to know which
  stack it's on and convert accordingly.
- **The family** is one of `OVER`/`UNDER`/`OVERUNDER`/`DIAGUNDER`
  (plus a `RESOVER` family for resistance) — `OVER`/`UNDER` are a
  direct neighbor immediately above/below; `OVERUNDER` is sandwiched on
  both sides; `DIAGUNDER` is a neighbor below, offset diagonally
  (OpenRCX has no symmetric `DIAGOVER`). A trailing `0`/`1` on the
  family name (`OVER0`, `OVER1`) is the open-ended, 1-2-wire isolated
  measurement, kept in its own table (this is the substitute data
  described above); the bare family name (`OVER`, `DIAGUNDER`) is the
  fully-coupled table.
- **Each `DIST count N width W` row is `<distance> <coupling>
  <fringe> <resistance>`** — confirmed directly from the reader
  (`extDistRC::readRC`, `openroad-fork/src/rcx/src/extRCmodel.cpp:74-79`):
  column 1 is separation distance, column 2 is the direct coupling
  capacitance term, column 3 is fringe capacitance, column 4 is
  resistance (always `0` here; real resistance lives in the separate
  `RESOVER` family). These are per-unit-length values in the solver's
  own internal scale, not `pF`/`fF`.
- **`DIST count 0`** means no data was ever generated for that exact
  (reference, family, neighbor) triple — looked up at runtime, this
  returns `nullptr` and is treated as `0.0` added capacitance, silently,
  with no warning. Every such empty entry in this file is either a
  structurally impossible cross-stack pairing, a distance beyond the
  generation sweep's range, or one of the documented gaps above — not
  an unexplained hole.

## What real chip builds show so far

The model has been wired into real HighTide gt2n chip builds (via
`RCX_RULES`) and compared against each design's existing adopted
baseline (the same flow config, just with the old flat `setRC.tcl`
fallback instead of this model). Headline finding: **results are
mixed, not uniformly better or worse** — and that mix is itself
important context before you try this on your own design.

Most designs' existing flow tuning (`HOLD_SLACK_MARGIN`, clock period,
utilization, input-delay offsets) was iteratively closed against the
old flat model's specific capacitance/resistance numbers. Real
OpenRCX extraction reports genuinely different per-net RC — that's
the entire point of building this model, it has real distance- and
neighbor-dependent structure the flat model never had — so a
configuration that was tuned to exactly zero violations under the old
estimate is not guaranteed to still be exactly zero under a different,
more accurate one. Several designs picked up new setup and/or hold
violations under real extraction that weren't present at baseline;
one tiny design (an LFSR) stayed fully clean both ways and even
achieved a slightly better maximum frequency. **If you try this model
on a design that was already timing-closed against the flat model,
expect to need a normal re-closure pass (margins, clock, utilization)
against the new numbers — don't assume it's a zero-effort drop-in.**

This is exactly the kind of signal the still-pending Quantus/StarRC
validation is meant to help explain: whether these shifts reflect the
model capturing real effects the flat estimate missed, or an
inaccuracy in the model itself that needs fixing. Right now, that's
open.

## Status

GT2N currently has zero real parasitic extraction by default anywhere
upstream — every build silently falls back to a cruder-than-`setRC.tcl`
global-route estimate. This rules file is not yet wired in as that
default anywhere; using it today means pointing your own build's
`RCX_RULES` at it explicitly, as shown above.

If you experiment with this and find something — a design where it
helps, a design where it clearly doesn't, a pattern family you'd
expect to matter that doesn't show up, or anything that looks like a
bug in the model itself rather than a flow-tuning issue — that
feedback is exactly what's needed before pursuing formal validation,
so please share what you find.
