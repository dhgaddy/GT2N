# Investigating why RCX-rules timing impact varies so much by design

This is a working investigation log, not a validation doc — unlike
`RULES_VALIDATION.md`, it's expected to contain hypotheses that get
revised or ruled out as evidence comes in. Start here:
`RULES_VALIDATION.md` §3-4 for the QoR table this investigation is
trying to explain.

## The question

Across the 9-design QoR sweep, the swing from baseline (analytical RC
model) to RCX rules (real FasterCap-calibrated extraction) ranges from
"no change / a slight improvement" (lfsr, minimax) to "hundreds of new
violations" (gemmini: 15→751 hold violations, 0→19 setup; floonoc:
0→190 setup violations, TNS −13,767 ps). Is there a common thread that
predicts which designs will react badly?

## Hypotheses ruled out

**Baseline timing margin** (configured clock vs. baseline's achievable
`period_min`). Computed for all 9 designs — doesn't track cleanly.
floonoc has *more* headroom (9.9%) than partition_a or partition_m
(4.8%, 11.9%) but a far worse regression. gemmini has almost none
(0.16%) and is the worst overall, but that alone doesn't explain why
floonoc (moderate headroom) is a close second.

**Placement density/utilization, alone.** gemmini (87%/0.94, highest
in the sweep) and partition_a (80%/0.88) are the two densest designs
and both broke badly — but lfsr sits at 80%/0.85, nearly as dense as
partition_a, with **zero** violations either way. Density alone
doesn't discriminate; something about *scale* has to be involved too
(user's observation: gt2n designs in HighTide generally run at high
density — it's a platform trait, not something distinctive to the
designs that broke).

**Mesh/NoC-style long-wire topology.** Initial hypothesis, based on
gemmini's systolic `Mesh`/`PE` naming and floonoc's `floonoc_mesh_top`
NoC router mesh both being the two worst regressions, plus their
violation counts being far larger than any other design's (a signature
that looked like "one systematic bias replicated across many identical
long wires"). **Directly contradicted by real data** — see below.

## Confirmed: gemmini's actual worst paths are short, local, low-metal — not long mesh wires

Loaded gemmini's real RCX-rules-extracted `6_final.odb` +
`6_final.spef` + `6_final.sdc` (not just the summary reports) and
re-ran `report_checks` to get the actual worst setup and worst hold
paths' net names, then grepped `6_final.def` for each net's `ROUTED`/
`NEW` layer records.

- **Worst setup path** (`-59.86 ps`, mesh.mesh_15_11...propagate → an
  output port): a 23-stage combinational chain (deep control-propagate
  logic within the PE array — synthesized cell names, not a long
  point-to-point route). Cap values on every segment are tiny
  (0.0005–0.03, mostly sub-0.002). Layers directly confirmed via DEF:
  **every net routes on M1–M7, mostly M2–M3**; one net (`net82045`)
  spans up to M7.
- **Worst hold path** (`-77.16 ps`, a 4-gate io-to-register path):
  layers confirmed **M1–M4** on every net.

Neither path touches M9+ or RDL at all. The mesh/thick-metal hypothesis
is wrong for gemmini specifically.

## Revised hypothesis: absolute scale of near-minimum-spacing low-metal interconnect

gemmini's local M1-M4 interconnect, at 87%/0.94 density, is forced to
minimum or near-minimum spacing far more often in absolute terms than
any other design in the sweep — not because gt2n designs in general
don't run dense (they do), but because gemmini combines that density
with being large (a big systolic PE array, many thousands of
near-identical short local paths). This is exactly `S == W`, the
single clearest FastCap calibration weak-spot documented in
`../scratch_logs/FASTERCAP_FINDINGS.md`. A systematic bias on that
specific geometry class, replicated across many structurally-identical
short local nets, would show up exactly as: many small hold violations
(751 — hold margins on short paths are already thin) plus a handful of
deep-logic-chain setup violations (19 — the same small per-net bias
compounding over ~20+ gate stages).

lfsr (also 80%/0.85, but only ~250 instances) is the control case: high
density but tiny absolute scale → few at-risk nets → clean. Not yet
checked against the other 6 designs (partition_a/m/p/o, minimax,
sha3) — pending the netlist-layer data fork below.

## Rules-file gap structure: are the missing calibration points clustered?

Separate question, same investigation: does the *rules file itself*
have structural gaps that could explain part of this, independent of
the density story?

Analyzed `../scratch_logs/all_patterns_v2.txt` (full pattern universe)
against `../scratch_logs/insane_converged_patterns_queue.tsv` +
`_RDL.tsv` (confirmed-unconvergeable patterns — the 1,041 patterns
excluded from the final `.caps` files). Grouped by
`(stack, family, layer-pair)` — each such group is a tiny spacing sweep
of only 3 or 5 discrete points.

**Answer: grouped, not sparse, and worse than a typical interpolation
gap:**

- 85.3% of all 878 missing points (of the 1,041 total, the rest didn't
  match the regex parse) have at least one adjacent missing neighbor
  within their own 3-or-5-point sweep.
- **102 of 279 affected `(stack, family, layer-pair)` groups are
  completely blacked out** — every spacing value failed to converge,
  leaving zero real measurements on that curve. That's 468 of 878
  missing points (53%). OpenRCX cannot interpolate within a curve that
  has no data point on it at all; it must fall back to some other
  layer-pair's data or a default for these.
- Full blackouts concentrate heavily in the "5" (wire_index=3,
  dense-packing) families — `OverUnder5` alone is 47/102, all four "5"
  families combined are 73/102 — matching `FASTERCAP_FINDINGS.md`'s
  documented root cause (negative-FR/CC2 solver-precision residual,
  concentrated in `wc3`/`wc5`, never `wc1`/`wc2`).
- By layer, blackouts spread M5 through M14, heaviest at **M5 and M7**
  (35 and 34 occurrences of 102), tapering at M0-M4 (4-9 each) and the
  very top.

**Possible (unconfirmed) connection**: gemmini's worst setup path has
a net spanning M2-M7, and M5/M7 are the two most common layers in the
full-blackout list. Flagged as suggestive only — the blackouts are
specifically in `wc5`/`OverUnder5` (multi-wire dense-coupling context),
while gemmini's actual violating nets are ordinary point-to-point
connections, not necessarily exercising that exact geometry. Dense
designs are plausibly more likely to have real nets that do land in
that under-calibrated geometry class, but this hasn't been directly
traced net-by-net yet.

## Full list of fully-blacked-out (family, layer-pair) combinations

All 102 (each only has 3-5 discrete spacing points total, all missing).
By family: `OverUnder5` 47, `Over3` 17, `Over5` 14, `UnderDiag3` 12,
`UnderDiag5` 9, `Under5` 3, split 97 frontside / 5 backside.

Disproportionately concentrated on **M5, M7, M11, M12 as the primary
metal** — these four have entire neighbor-family sets missing, not
just isolated points:

- `Over3`/`Over5`: `M5oM0/1/2/3/4` (all of M5's), `M7oM0/3/4/6` (most
  of M7's), `M11oM8/9/10`, `M12oM8/9/10/11`.
- `OverUnder5` (the largest single cluster, 47 of 102): mostly M11/M12
  primary with M7-M10 under / M12-M15 over, plus a scattered M5/M7
  primary set.
- `UnderDiag3`/`UnderDiag5`: `M5duM6/7/8/9`, `M7duM8/9/10/11`,
  `M11duM12/14/15`, `M12duM14/15`.
- Backside barely affected: only `Over3`/`Over5`/`OverUnder5` on
  `M2oM1` (and its `uM3`/`uM6`), plus one `M4oM3uM5`.

If prioritizing re-convergence effort (get at least one real point per
group instead of zero), M5/M7/M11/M12's `Over`/`OverUnder`/`UnderDiag`
families cover the large majority of the 102 groups.

## Cross-stack (frontside/backside boundary) gap: investigated and closed, not a defect

Separate question from the convergence-failure gaps above: the rules
file also has a block of `OVER`/`UNDER`/`OVERUNDER` entries (plain and
both `0`/`1` open-ended variants) with `DIST count 0` — or, for `Metal
6 UNDER`, no `DIST` section at all — every time the pair spans the
backside/frontside boundary (real layer 6/`BPR` vs. real layer 7/`M0`)
within `gen_solver_patterns`' `-over_dist`/`-under_dist` window
(default 4, confirmed via grep that GT2N never passes this flag
explicitly anywhere — every sweep/`gen.tcl` and k8s entrypoint script
relies on the tool default). Programmatically enumerating every such
header in `gt2n_combined.rcx.model` (gap 1-4, either direction, all
three families including the `0`/`1` variants) found **every single
one unpopulated, no exceptions** — 29 `OVER`-direction combos, 31
`UNDER`-direction combos, 510 `OVERUNDER`-direction combos.

**Initial hypothesis (wrong): a real, consequential physical gap that
should be filled.** `gt2n_process_backside.pro`'s `CONDUCTOR BPR`
block lists `distance 0.090`, which was first read as the real
physical separation between `BPR` (backside, closest to devices) and
`M0` (frontside, closest to devices) — small enough to plausibly
matter, and `gen_solver_patterns`' default-4 window was confirmed to
be an unexamined tool default rather than a deliberate PDK-informed
choice, so this looked like a genuine, previously-unnoticed model gap
worth closing by building a combined process file and generating the
missing cross-stack patterns.

**Correction, found by reading the full `nxtgrd/GT2.itf`** (the single
continuous source both `.pro` files are independently derived from,
rather than just each `.pro` file in isolation): `BPR_diel`'s
`0.090` is the ILD **beneath** `BPR` (per the established `<L>_diel`
convention, the gap down to `BM1`), not the gap up toward the
frontside. The real separation between `M0` and `BPR` in the
continuous ITF listing is the **entire transistor/MOL level**
(`GATE`/`ACT`/`SDCON`/`VSD`/`VG` — already out of scope for wire-RC
extraction per both `.pro` files' own header comments) **plus
`BOX_diel`** (23nm buried oxide, the wafer-thinning remnant;
`gt2n_process_backside.pro`'s header comment already flags this as
having "no CONDUCTOR of its own" and not belonging to either stack).
That's a structurally different, much bigger thing than a simple
dielectric gap between two metal stacks — modeling it honestly would
require representing several additional conductor layers this project
has always treated as out of scope, not just adding one dielectric
entry to a merged process file.

**Conclusion**: the frontside and backside metal stacks are genuinely
separate field-solver domains with no directly-coupled conductor
across the boundary — exactly what `HOWTO.md`'s "Frontside/backside
split" note already documents (each stack solved independently,
combined only at final rules-file assembly). The empty cross-stack
entries are a correct reflection of that physical reality, not an
overlooked default or a defect. **No combined process file or
cross-stack pattern generation is planned** — this line of
investigation is closed.

## What the flow falls back to when there's nothing to interpolate between

Traced the actual call chain in `openroad-fork/src/rcx/src/
extRCmodel.cpp` / `extmeasure_dist.cpp` for a `(met, underMet, overMet)`
combination with zero measured points:

```
extMeasure::computeOverUnderRC()
  → getOverUnderRC(rcModel)                    [extRCmodel.cpp:1996, no null guard]
  → _capOverUnder[met]->getRC(n, width, dist)
  → extDistWidthRCTable::getRC()                [extRCmodel.cpp:1736]
  → _rcDistTable[mou][wIndex]->getRC(s, true)
  → extDistRCTable::getRC() → getComputeRC(s)
  → measureTable_->getCnt() <= 0 → nullptr       [extRCmodel.cpp:643-648]
  → addRC(rcUnit=nullptr, len, jj)
  → if (rcUnit == nullptr) return nullptr        [extRCmodel.cpp:2527-2529]
```

**Not a crash, and not interpolation/extrapolation from a neighboring
layer-pair either — a silent zero.** `addRC` is the function that
accumulates fringe/coupling/resistance into the net's running total; it
null-checks at the top and returns without adding anything. The
missing coupling/fringe term is simply dropped from that net's total
capacitance, with no warning.

`getComputeRC`'s own dist-based interpolation (the behavior "OpenRCX
interpolates across gaps" refers to, per `RULES_VALIDATION.md` §2)
only operates *within* an already-populated curve — between two real
measured spacing points on the same layer-pair. It never activates
when the whole curve is empty (all 102 blackout cases), and there is
no "borrow an adjacent layer-pair" fallback anywhere in this chain —
lookup is keyed to the exact `(met, underMet, overMet)` index or
nothing.

**Implication**: for these 102 combinations, real nets needing that
specific coupling term get systematically *under*-counted capacitance
for that term — silently, unflagged — and specifically for the
geometry class (`OverUnder5`/dense-packing, M5/M7/M11/M12) expected to
have the largest coupling terms in the first place. This is a distinct
mechanism from the `S==W` calibration-bias story above, not a
replacement for it — both could be contributing simultaneously.

**Correction (this doc previously understated this): the wire-count
pooling problem is not unique to the diag family — it's a general gap
in the model, worst in diag, present everywhere else too.** Traced the
actual ingestion routing (`extMetRCTable::addRCw`, the function
GT2N's model-build step calls per raw `.caps` line — not the
superficially similar `extRCModel::addRC`, a different/legacy code
path):

```cpp
} else if (m->_over) {
    if (m->_open)       table = _capOver_open[m->_met][0];  // wc1 (isolated) — own table
    else if (m->_over1) table = _capOver_open[m->_met][1];  // wc2 (one-side-open) — own table
    else                table = _capOver[m->_met];          // wc3 AND wc5 — SAME table
} else if (m->_diag) {
    table = _capDiagUnder[m->_met];   // wc1, wc2, wc3, wc5 — ALL the same table, no branching
}
```

`OVER`/`UNDER`/`OVERUNDER` genuinely keep wc1 and wc2 in their own
dedicated tables (`_capOver_open[met][0]`/`[1]`) — a wc3/wc5
(fully-coupled) lookup against an empty fully-coupled bucket correctly
falls through to the silent-zero path documented above, and isolated
data never contaminates that lookup. **But wc3 and wc5 — "fully
coupled, 3 wires" and "fully coupled, 5 wires" — land in the exact
same `_capOver[met]`/`_capUnder[met]` table**, same mechanism as diag.
Confirmed directly: `Under3/M4uM8` and `Under5/M4uM8` (real layers
10/14, not a diag pair, not blacked) both have raw rows at the
identical spacing `S0.014` with different `CC` values (`0.008195` for
wc3; `0.008526`/`0.015425`/`0.012833`/`0.015494`/`0.008726` for wc5's
five replicas) — all appended to the same measurement list.

**The diag family's issue is the same defect, just total instead of
partial**: `extMetRCTable::allocDiagUnderTable` allocates
`_capDiagUnder[met]` as a single table with no per-wire-count array at
all (contrast `_capOver_open[met][ii]` above), and `addRCw`'s diag
branch has no `_open`/`_over1` sub-routing — wc1, wc2, wc3, *and* wc5
all land in the one table. Confirmed on `M10duM11` (real layers 16/17,
fully converged, not blacked): `UnderDiag2`/`3`/`5` all land on the
identical `DiagDist 0.112, DiagWidth 0.056` point with different
`DiagCC` values (0.0057/0.0048 for wc2; 0.0034/0.0043/0.0043 for wc3;
0.0015/0.0027/0.0038/0.0032/0.0027 for wc5) — all in the same flat
list, which `getRC`/`getComputeRC` walks positionally (`getLast()`,
`get(cnt-2)`, etc.), not by any wire-count-aware key.

**Net picture**: every family pools wc3 with wc5. Diag additionally
pools wc1 and wc2 into that same list — a much bigger context gap
(isolated, zero neighbors, vs. dense-packed, up to 5), which is why the
14 still-100%-blacked diag groups look the way they do: `frontside
UnderDiag3 M7duM8` / `UnderDiag5 M7duM8` (real layers 13/14) have zero
raw rows in `gt2n_frontside.caps`, yet the committed `Metal 13
DIAGUNDER 14` header has 120 real rows — entirely from the surviving
`UnderDiag1`/`UnderDiag2` (isolated/one-side-open) data. For
`OVER`/`UNDER`/`OVERUNDER`, the equivalent worst case (wc3 *and* wc5
both empty for some pair) genuinely hits the silent-zero path — none
of those currently exist in the committed model (verified: no
in-window, same-stack `OVER`/`UNDER`/`OVERUNDER` header has
`DIST count 0`) — but a *partial* version of the same contamination
(wc3 present, wc5 missing or vice versa, silently backfilling each
other) is architecturally possible anywhere in those families too; it
just hasn't been specifically surveyed the way the diag family has.

**Correction: the wc3/wc5 pooling is not "relatively mild."** Tracing
`extDistRCTable::interpolate()`/`getComputeRC()` further (not just the
storage layer) found this pooling can silently corrupt real-extraction
lookups outright, independent of how close wc3's and wc5's values
happen to be: raw measurements land in `measureTable_` in file-read
order, not distance order, and multiple downstream functions
(`mapInterpolate`'s per-pair walk, `mapExtrapolate`'s
flat-extrapolation-from-`get(0)`, `getComputeRC`'s
near-farthest-point special case via `getLast()`) all assume that
order is sorted ascending by distance. When wc3's sweep ends above
wc5's sweep's own starting point, that assumption breaks, and a
real query can return an arbitrary wrong constant (not an average of
wc3/wc5, not a zero) — confirmed with a minimal reproduction,
independent of GT2N's actual calibration values. **This is now fixed**
(sort `measureTable_` by distance before building `computeTable_`,
a localized change to one function, validated with a dedicated
regression test that fails without the fix and passes with it) — see
`openroad-fork/src/rcx/doc/wire_count_pooling_fixes.md` for the full
fix-tracking doc. **The diag open/coupled split described above is
also now fixed** — `diag` has its own `_capDiagUnder_open[met][0]`/`[1]`
tables now, mirroring `OVER`/`UNDER`, validated with a dedicated test
(`TestDiagOpenSplit.cpp`). Both fixes are local-fork changes only (not
upstreamed); the diag family's *runtime lookup* still doesn't do the
distance-weighted open/coupled blend `OVER`/`UNDER` use — only the
storage side no longer pools incompatible wire-counts — see the
fix-tracking doc's "Fix 2" section for exactly what's deferred.

## Fork results: 3 of 8 designs confirmed, mesh/thick-metal hypothesis further refuted

A fork gathered the same netlist-level worst-path/layer data for lfsr,
minimax, sha3, floonoc, and NVDLA partition_a/m/p/o in an isolated git
worktree. 3 of 8 completed (lfsr, minimax, sha3); 5 (floonoc,
partition_a/m/p/o) hit real cache misses (recompute from synth/
floorplan/place, not a cache-hit re-extraction) and were correctly
abandoned rather than waiting through a multi-hour rebuild
unsupervised. Root cause of the cache miss not yet determined.

**All 3 confirmed designs reinforce gemmini's finding — nothing above
M5, no thick metal, no RDL involvement, in either setup or hold:**

| Design | Worst setup path layers | Worst hold path layers |
|---|---|---|
| lfsr | M1–M3 only | M1–M3 only |
| minimax | M1–M5 (one hop, `net6921`, is 40% of total delay) | not captured (worst hold check had no interconnect) |
| sha3 | M1–M5 (one hop, `_02118_`, is 58.6% of total delay — driven by a minimum-sized `nor2_x1`) | M1–M3, evenly distributed, no single dominant hop |

Combined with gemmini (M1–M7): **4 of 4 designs with real per-net
layer data confirm violations concentrate on low/mid metal (M1–M5,
gemmini reaching M7), never on thick top metal or RDL.** The
mesh/thick-metal hypothesis is now refuted across every design
actually checked, not just gemmini.

sha3's specific mechanism is a third pattern, distinct from gemmini's
two (many-replicated short hold paths; a handful of deep logic
chains): **one single weak-driver/net pair dominating 58.6% of the
entire critical path** — not a distributed/replicated effect, and not
obviously tied to placement density the way gemmini's story is. Worth
reconciling with the "absolute scale of near-minimum-spacing
interconnect" hypothesis, or treating as a separate contributing
mechanism — not yet done.

**Known inaccuracy in the fork's directive**: it was told none of the
8 designs have SRAM macros. Wrong for NVDLA partition_o/p specifically
(both have `ADDITIONAL_LEFS`/`ADDITIONAL_LIBS`) — didn't matter in
practice since neither was reached, but flagged for accuracy if
retried.

## Pending

floonoc's real per-net layer data is still the highest-value gap — the
2nd-worst violator overall (217 violations) and the current strongest
counter-example candidate for the density-driven hypothesis (large net
count, unclear/lower density) is untested. Getting it requires either
diagnosing why the isolated worktree missed cache (expected to be a
cache hit, per the original sweep's build having already produced
these exact artifacts) or accepting a real multi-hour rebuild. Not
attempted further without checking in first, given the cost.

## Current state, all families, project-wide (verified 2026-10-01, after round 12 — unchanged since round 11, round 12 rescued 0)

Computed directly from the master tracker files
(`../scratch_logs/v2_flag_completed_patterns.tsv` +
`_RDL_bonus.tsv` for originally-SANE patterns,
`../scratch_logs/insane_converged_patterns_queue.tsv` + `_RDL.tsv` for
the originally-failing universe, cross-referenced against all 14
staged rescue TSVs and every k8s probe's raw per-pattern records from
this session — rebuilt from source each time, never extended from a
prior round's arithmetic) — 7056 patterns total, 6017 originally SANE,
1039 originally failing. 864 of those 1039 have since been rescued
across 14 rounds (670 in an earlier session, 194 in this one). Two
patterns (`frontside/OverUnder5/M5oM2uM6/.../S0.021_S0.021_L10` and
`frontside/Over5/M5oM3/.../S0.063_S0.063_L10`, both `wc5`) were rescued
(rounds 8 and 9 respectively) but were never present in
`insane_converged_patterns_queue.tsv` to begin with — a small, known
gap in that master file, noted here rather than silently absorbed into
the totals.

| stack | family | total | SANE | SANE% | crash-bug | mesh-explosion timeout | clean INSANE |
|---|---|---|---|---|---|---|---|
| backside | Over1 | 20 | 20 | 100% | - | - | - |
| backside | Over2 | 100 | 100 | 100% | - | - | - |
| backside | Over3 | 100 | 100 | 100% | - | - | - |
| backside | Over5 | 100 | 99 | 99.0% | 1 | 0 | 0 |
| backside | OverUnder1 | 20 | 20 | 100% | - | - | - |
| backside | OverUnder2 | 100 | 100 | 100% | - | - | - |
| backside | OverUnder3 | 100 | 100 | 100% | - | - | - |
| backside | OverUnder5 | 100 | 90 | 90.0% | 0 | 1 | 9 |
| backside | Under1 | 14 | 14 | 100% | - | - | - |
| backside | Under2 | 70 | 70 | 100% | - | - | - |
| backside | Under3 | 70 | 70 | 100% | - | - | - |
| backside | Under5 | 70 | 61 | 87.1% | 6 | 1 | 2 |
| backside | UnderDiag1 | 14 | 14 | 100% | - | - | - |
| backside | UnderDiag2 | 126 | 126 | 100% | - | - | - |
| backside | UnderDiag3 | 126 | 126 | 100% | - | - | - |
| backside | UnderDiag5 | 126 | 110 | 87.3% | 16 | 0 | 0 |
| frontside | Over1 | 65 | 65 | 100% | - | - | - |
| frontside | Over2 | 325 | 325 | 100% | - | - | - |
| frontside | Over3 | 325 | 325 | 100% | - | - | - |
| frontside | Over5 | 325 | 325 | 100% | - | - | - |
| frontside | OverUnder1 | 160 | 160 | 100% | - | - | - |
| frontside | OverUnder2 | 800 | 800 | 100% | - | - | - |
| frontside | OverUnder3 | 800 | 799 | 99.9% | 0 | 0 | 1 |
| frontside | OverUnder5 | 800 | 797 | 99.6% | 0 | 0 | 3 |
| frontside | Under1 | 50 | 50 | 100% | - | - | - |
| frontside | Under2 | 250 | 250 | 100% | - | - | - |
| frontside | Under3 | 250 | 250 | 100% | - | - | - |
| frontside | Under5 | 250 | 250 | 100% | - | - | - |
| frontside | UnderDiag1 | 50 | 50 | 100% | - | - | - |
| frontside | UnderDiag2 | 450 | 450 | 100% | - | - | - |
| frontside | UnderDiag3 | 450 | 375 | 83.3% | 75 | 0 | 0 |
| frontside | UnderDiag5 | 450 | 388 | 86.2% | 62 | 0 | 0 |
| **TOTAL** | | **7056** | **6879** | **97.5%** | **160** | **2** | **15** |

`crash-bug` = confirmed `rc=133` SIGTRAP hits (either the pattern's
family is `UnderDiag*`, or it was directly observed to crash in one of
this session's probes even though its family normally doesn't — 7
`Under5`/`Over5` patterns fall in the latter bucket). `mesh-explosion
timeout` = the runaway-panel-refinement failure mode
(`MESH_EXPLOSION_INVESTIGATION.md`), confirmed via direct observation
in this session's probes, not inferred. `clean INSANE` = a real,
conclusive `CONVERGED_INSANE` verdict under every config tried so far
— not a bug, not yet rescued. 160 + 2 + 15 = 177 patterns remain
non-SANE; 17 of those (2 + 15) are unrelated to the crash bug and are
this project's current active investigation target.

Every other table and count in this document below reflects the
scope and point in time it was measured at (labeled per round) — at the
time this section was written (2026-10-01, after round 12), it was the
current authoritative cross-check, with the round tables below it
superseded by it.

**Flag (2026-10-08):** this section is itself now superseded. Rounds
13-14 ran after 2026-10-01 (see `scratch_logs/v2_flag_completed_patterns_convprobe_rescue_v13.README.md`
and `_v14.README.md`), and this table's 7,056-pattern scope is combined
non-RDL + RDL, not the same denominator as the non-RDL-only
reconciliation done on 2026-10-08. The current, independently
re-derived **non-RDL-only** totals (from `scratch_logs/FASTERCAP_FINDINGS.md`'s
2026-10-08 correction note) are 5,953/6,128 `CONVERGED_SANE`, 175
missing (162 crash-bug family, 13 unattributed), close to but not
identical to this table's project-wide 160/2/15 breakdown, since this
table's denominator includes RDL patterns that the 2026-10-08 pass did
not re-reconcile. Don't treat this table's 160 crash-bug count and the
2026-10-08 162 figure as the same measurement reconciled to the
decimal; they're close because both describe mostly the same
non-RDL-dominated population, not because they were cross-checked
against each other.

## Convergence-probe results: rescuing the fully-blacked-out patterns

Direct follow-up to "What the flow falls back to" above: since the 102
fully-blacked-out groups get a silent zero rather than interpolation,
the only real fix is getting at least one genuine convergence per
group. Built 30 distinct FasterCap configuration/tuning angles (every
one confirmed *not* already tried anywhere in this project's FCAP_FLAGS
history — exhaustively grepped across all `k8s/*.yaml`) and ran all 30
against the 468 patterns making up those 102 groups, 2-way sharded
(60 pods total, `k8s/convprobe_jobs/`), 900s/pattern.

**Result: 294 of 468 previously-100%-unconvergeable patterns achieved a
real `CONVERGED_SANE` result** — every one of the 102 fully-blacked-out
groups now has at least a partial real anchor. Staged for review at
`../scratch_logs/v2_flag_completed_patterns_convprobe_rescue.tsv` (see
its companion README for merge instructions) rather than merged
directly, per standing practice of not editing the shared rules-model
inputs without an explicit go-ahead.

### The two configs that actually worked, and why

Only 2 of the 30 configs ever produced a SANE verdict — both from the
"untried `-a` " angle (tighter global accuracy target than any
previously-tried value, `-a` sets `FasterCap`'s auto-refinement stop
threshold, `-ap` lets it auto-pick Jacobi vs. Super preconditioner
rather than forcing one):

| Config | Flags | SANE rescues (of 294) |
|---|---|---|
| `a_0.001_ap` | `-a0.001 -ap` | 201 |
| `a_0.005_ap` | `-a0.005 -ap` | 93 |

The tighter target (`a_0.001_ap`, 0.001) won on more than twice as many
patterns as the looser one (`a_0.005_ap`, 0.005) — the opposite of what
"tighter tolerance == harder to hit == fewer wins" would predict. Read
together with the *secondary* signal below, this suggests these
patterns weren't failing because FasterCap couldn't converge tightly
enough; they were failing because the historically-used `-a` values
(0.01/0.05/0.1, all looser than either probed value) were stopping the
mesh refinement process *too early*, before the panel geometry was
resolved finely enough to avoid the near-degenerate-panel
negative-capacitance residuals documented in
`../scratch_logs/FASTERCAP_FINDINGS.md`. Refining further (smaller
`-a`) gives the solver more chances to get past that residual, hence
more SANE outcomes, not fewer.

None of the 28 other configs (Block/Hier preconditioner variants, `-d`
mesh-epsilon-ratio sweeps, `-s` absolute-panel-cap sweeps, and their
combinations) ever produced a single SANE verdict across all 468
patterns in this probe — a real, if negative, result: for these
specific dense-packing wc3/wc5 families, refinement aggressiveness
(the `-a` target) is what mattered, not choice of preconditioner or
mesh-shaping strategy. All 10 `-pH*` (hierarchical preconditioner) pods
crashed immediately (SIGFPE, rc=136) on every pattern attempted — a
genuine FasterCap bug in that code path, not a config-tuning result;
killed early rather than left to burn the full 900s per pattern.

Among patterns that still never went SANE, the Block-preconditioner
family (`block_precond_32/64/128`, `block64_d0.2`,
`stack_pb128_d01_s003`) was the most common *least-insane* runner-up
(69 of 165 still-insane patterns), and `s_0.15_control` (the loosest
historical `-s` value, run here as a control) unexpectedly won
"least-insane" on 23 more — both untried angles worth a dedicated
follow-up probe if further rescue effort is warranted.

### Rescue rate by family

**Scoped to round 1 only** (the original 468-pattern blackout set, as
of the first 30-config probe) — see "Current state, all families,
project-wide" above for the up-to-date, full-project numbers after
all 8 rounds. Kept here because the family-vs-config relationship it
shows (`Over`/`OverUnder` responding to the `-a` fix, `Under`/
`UnderDiag` not) was the actual finding that motivated every
subsequent round.

Family success rate varied far more than config choice did — attempted
counts are the ground truth from `BLACKOUT_PATTERNS.md`'s 468-pattern
list, not just "patterns reached" (all 468 were reached within the
900s budget across at least one of the 30 configs):

| stack | family | attempted | SANE | rate |
|---|---|---|---|---|
| backside | Over5 | 5 | 5 | 100% |
| backside | Over3 | 5 | 3 | 60% |
| frontside | Over3 | 80 | 57 | 71% |
| frontside | Over5 | 65 | 44 | 68% |
| frontside | OverUnder5 | 220 | 160 | 73% |
| backside | OverUnder5 | 15 | 6 | 40% |
| frontside | UnderDiag3 | 36 | 11 | 31% |
| frontside | UnderDiag5 | 27 | 5 | 19% |
| frontside | Under5 | 15 | 3 | 20% |

Two clusters emerge, cleanly separated by family type rather than by
stack or by size:

- **`Over`/`OverUnder` families rescue at 40-100%.** These are the
  families where the reference conductor has real coupling neighbors
  on both sides being swept together — exactly the geometry class
  `FASTERCAP_FINDINGS.md` already flags as prone to the
  near-degenerate-panel residual that a tighter `-a` target fixes.
- **`Under`/`UnderDiag`-only families rescue at only 19-31%**, despite
  getting the *same* 30-config treatment and the *same* `-a`-target
  fix that worked well elsewhere. Since these are the families with
  only one active coupling neighbor (no "over" conductor in the
  pattern at all), whatever residual is driving their non-convergence
  is evidently not the same one the `-a` refinement fix addresses —
  a genuinely distinct, still-unexplained failure mode, and the
  clearest candidate for a *fourth* investigation angle (distinct from
  `-a`, preconditioner choice, and mesh-shaping, all three of which
  this probe already covered without moving the needle on this
  family group).

The single largest blackout family, `OverUnder5` (47 of 102 groups),
also happened to have the largest rescue pool by raw count (166 of 294)
even though its rate (72.7% frontside) is unremarkable next to
backside `Over5`'s 100% — worth remembering when reading "294 rescued"
as a headline number: it is heavily weighted toward one family that was
already the least intrinsically-hard-relative-to-its-neighbors on this
list, not evenly spread across all 6 failing families.

### Round 4: unlimited-time probe on the timeout-only groups

3 rounds of rescue effort (294 + 346 + 24 = 664 patterns) left 18 fully
blacked-out groups. 15 were the `UnderDiag`/`Under` solver-crash cases
(see `UNDERDIAG_CRASH_INVESTIGATION.md`); the other 3 — `backside
OverUnder5 M4oM3uM5`, `frontside OverUnder5 M14oM13uM15`/`M7oM6uM8`,
`frontside Under5 M5uM6` — were confirmed genuine 900s timeouts, not
crashes, on every attempt. Ran those 4 groups' 20 patterns again with
the per-pattern time limit effectively removed (900s → ~1 year),
one pattern per pod (40 pods, 2 configs), and let them run ~a day.

**6 more patterns rescued** (`M7oM6uM8` 2/5, `M5uM6` 4/5), confirming
those specific points genuinely just needed more wall-clock (19-53
minutes, no config change). `M4oM3uM5` reached conclusive INSANE
verdicts on every point — a real result, done, not a timeout artifact
after all despite its earlier classification.

**`M14oM13uM15` (all 5 points) did not converge under `a_0.001_ap`/
`a_0.005_ap`, even with the time limit removed entirely.** Watched two
live attempts: FasterCap's inner GMRES solver was repeatedly
exhausting 1000 iterations without converging — residual plateaued at
0.04-0.11 against a 0.001 target, 16-20 outer refinement rounds deep,
with no trend toward the target between rounds. Consistent with a
genuine wall rather than slow progress: half of the 10 total attempts
on this pattern grew unboundedly in memory and were killed by the
pod's 128Gi limit after 16-17 hours, still stuck at the same residual.
A solve that grows memory without bound while its residual stays flat
is diverging, not converging slowly under *that* config.

Full writeup: `../scratch_logs/v2_flag_completed_patterns_convprobe_rescue_v4.README.md`.
Blackout tally as of round 4 (superseded by rounds 5-6 below):
360/468 patterns rescued, 16 groups still fully blacked out (15
solver-crash, 1 GMRES-non-convergence).

### Round 5-6: is `M14oM13uM15` really unconvergeable, or just under the wrong config?

Round 4's framing above ("dead end, stop probing") turned out to be
premature — it only ruled out the two tight-`-a` configs, not every
config. Went back to round 1's original 30-config sweep (900s budget)
and pulled every config's result for this exact pattern (5 spacing
points), which had been set aside as "irrelevant" once `a_0.001_ap`/
`a_0.005_ap` were identified as the overall best performers across the
full 468-pattern set. For *this specific pattern* they are not:

| config (no `-a` override) | S0.36 | S0.54 | S0.72 | S1.08 | S1.8 |
|---|---|---|---|---|---|
| `stack_pb128_d01_s003` (`-pB128 -d0.1 -s0.03`) | 0.0467 | 0.0348 | 0.0229 | **0.00015** | 0.0019 |
| `d_0.05` | 0.0459 | 0.0345 | 0.0232 | 0.000186 | 0.0018 |
| (all other 20 configs) | 0.045-0.049 | 0.034-0.036 | 0.022-0.024 | 0.0002-0.012 | 0.0016-0.0021 |

Every one of these 22 configs converged in ~5 seconds at round 0 —
they never entered the long adaptive-refinement loop that
`a_0.001_ap`/`a_0.005_ap` push into, and never destabilized. At the two
widest spacings (S1.08, S1.8) several landed within 0.0002-0.002 of
the sanity threshold — an order of magnitude closer to SANE than
anything the tight-`-a` configs ever produced under unlimited time.
At the three tightest spacings (S0.36-S0.72) every config is stuck
around 0.02-0.05, well short — a real remaining gap, not just missing
tuning.

**Hypothesis confirmed, with a real boundary, not a smooth gradient.**
The tight `-a0.001`/`-a0.005` targets were indeed causing the GMRES
instability. Ran medium `-a` values (0.005, 0.01, 0.02, 0.05, 0.1)
layered on `stack_pb128_d01_s003`'s exact base flags (`-pB128 -d0.1
-s0.03`, deliberately no `-ap` — `-ap`'s `AutoSetPrecondType()`
silently overrides an explicit `-pB*` choice back to Jacobi/Super,
confirmed earlier this session, so combining them would have
defeated the point), one pattern per pod, 2h budget:

| spacing | a0.005 | a0.01 | a0.02 | a0.05 | a0.1 |
|---|---|---|---|---|---|
| S0.36 | diverged | **SANE** (5s) | SANE | SANE | SANE |
| S0.54 | diverged | **SANE** (5s) | SANE | SANE | SANE |
| S0.72 | diverged | diverged | diverged | **SANE** (5s) | SANE |
| S1.08 | diverged | diverged | **SANE** (5s) | SANE | SANE |
| S1.8 | diverged | diverged | INSANE | INSANE | INSANE |

"diverged" here is a confirmed live observation, not a timeout guess:
watched `wires.log` directly and saw the same signature as the
original `a_0.001_ap`/`a_0.005_ap` failure — Frobenius norm oscillating
0.45-0.7 with no downward trend, round count nearly frozen (12→16
rounds over 30+ minutes) — and killed those runs once the signature
was unambiguous rather than burn the full budget. **The stability
boundary for this pattern sits at `a≈0.02`**: everything at or above
converges in 5-10 seconds; everything below (including 0.015, tested
in a follow-up) reproduces the divergence. Not a smooth gradient —
0.015 and 0.02 behave completely differently.

4 of 5 spacings rescued immediately at `a≥0.02`. **S1.8 needed one
more round**: `a0.02`/`0.05`/`0.1` all landed INSANE with small,
consistent negative CC2 (-0.0006 to -0.004) — close but not sane.
Varying mesh-shaping independent of `-a` (keeping `a0.02`, the
tightest stable value): `-s0.01` had **zero effect** (identical
residuals to plain `a0.02`, `max|CC2|=0.0019` — the panel side-length
cap wasn't the binding constraint), but `-d0.05` (tighter relative
mesh-epsilon than the default 0.1) nearly halved it to
`max|CC2|=0.00092`. Pushed further: `-d0.02` closed the gap to SANE;
`-d0.01` (tighter still) went back to INSANE — the same
non-monotonic-boundary pattern as `-a`, just in a different parameter.

**All 5 spacings of `M14oM13uM15` are now `CONVERGED_SANE`.** Full
per-spacing winning configs and raw data:
`../scratch_logs/v2_flag_completed_patterns_convprobe_rescue_v5.README.md`.
This closed the last non-`UnderDiag` gap that was still *fully*
blacked out (every spacing in the group unconverged) in the 468-pattern
blackout set as of round 6. As of round 7 below, 22 more of the
468-pattern set's *partially*-blacked-out patterns are also rescued
(387/468 total, see `BLACKOUT_PATTERNS.md` for the current
group-by-group tally) — round 7 worked from a broader, project-wide
scope than just this doc's 468-pattern set, so most of its 66 rescues
land outside it. `FASTERCAP_BUG_REPORT.md` has the fix-oriented
writeup of the confirmed crash bug (root cause, a verified standalone
reproduction, and a concrete starting point for a fix) — still the
correct next step for the 15 fully-`UnderDiag` blacked-out groups,
which round 7 deliberately did not touch (see below).

**Methodological note for future work**: neither `-a` nor `-d` was a
monotonic "tighter is better/worse" dial here — both had a real
stability cliff that only showed up via live inspection of round count
and Frobenius-norm trend, not from trying a few values and reading
pass/fail. When a globally-best config diverges on one specific
pattern, check whether looser configs from the original wide sweep
landed close to sane before concluding it's unconvergeable — that's
the signal that the aggressive target itself, not the geometry, is the
problem.

### Round 7: does the crash bug really explain everything else? The `convnc` probe

After round 6 closed `M14oM13uM15`, checked whether the confirmed
`UnderDiag` crash bug (`UNDERDIAG_CRASH_INVESTIGATION.md`) actually
accounts for every remaining unconverged pattern, project-wide (not
just the 468-pattern blackout-*group* set this doc otherwise tracks —
a broader universe of 369 still-unconverged patterns out of 7056
total, 6687 already `CONVERGED_SANE`). It does not, cleanly: only
155/369 belong to the two crash-prone families (`UnderDiag3`,
`UnderDiag5`). The other **214/369** belong to families that almost
never crash (`OverUnder5` 92, `OverUnder3` 51, `Under5` 36, `Under3`
14, `Over3` 11, `Over5` 10) — for these, more probing was worth doing.

Checked first whether "just retry with the known-best configs"
(`a_0.001_ap`/`a_0.005_ap`) would be worthwhile: 211/214 (98.6%) had
already failed under one or both of those exact configs in earlier
rounds. Blind retry was not justified. Residual-magnitude evidence
pulled from the cached per-pattern batch data was more promising:
median magnitude 0.000278 across these 214, 71.6% under 0.001, 85.8%
under 0.002 — closer to sane, on average, than `M14oM13uM15` was
before round 5-6 rescued it. That's the same signal that justified
`M14oM13uM15`'s medium-`-a` approach, so applied the same idea at
scale: single config `-pB128 -d0.1 -s0.03 -a0.02` (the exact winning
base-flags-plus-medium-`-a` combination from round 5-6), all 214
patterns, sharded across 40 pods (a hard cap set for this round — no
more than 40 pods, serialized within each shard rather than one pod
per pattern).

**Result: 66/214 rescued (31%)** — `OverUnder3` 21, `OverUnder5` 19,
`Over3` 11, `Under5` 9, `Over5` 3, `Under3` 3. Staged at
`../scratch_logs/v2_flag_completed_patterns_convprobe_rescue_v7.tsv`
(config label `convnc_a0.02`). Of the 148 not rescued: 125 landed a
conclusive `CONVERGED_INSANE` (a real result, not a timeout — mostly
concentrated in `OverUnder5`, 72/125), 5 hit the confirmed `SIGTRAP`
crash (4 `Under5` + 1 `Over5`, both backside — this is not a new
finding, both family types were already known occasional crash
triggers per `UNDERDIAG_CRASH_INVESTIGATION.md`'s original tally,
which now stands at 232 total crash occurrences project-wide, up from
227), and **18 (17 timeout + 1 memory-guard preemption) hit a third,
previously-uncharacterized failure mode** — see
`MESH_EXPLOSION_INVESTIGATION.md` for the full writeup. Short version:
these patterns' adaptive mesh refinement runs away exponentially in
panel count (60-90x growth over 12 rounds, confirmed via direct
`wires.log` inspection) while the residual oscillates without ever
settling below target, exhausting the 3600s/128GB budget without
either converging or crashing. 14/18 are `Under3`/`Under5` — the same
family shape that dominates the crash bug, but a mechanically distinct
problem (no `NaN`/`Inf`, nothing ever diverges numerically — the mesh
just never stops growing). A follow-up 18-pod probe testing a much
looser `-a0.1` target (the observed residuals plateau at 0.03-0.15,
suspiciously close to a loose target) **confirmed the fix decisively**:
18/18 resolved in 5-55 seconds each, zero timeouts, zero crashes, peak
memory down ~1000x (tens-hundreds of MB vs. 15-110GB). 5/18 landed
`CONVERGED_SANE`, staged in
`../scratch_logs/v2_flag_completed_patterns_convprobe_rescue_v8.tsv`.
Unlike the `UnderDiag` crash bug, this failure mode needed no upstream
fix — just a less aggressive target for this pattern population. See
`MESH_EXPLOSION_INVESTIGATION.md` for the full writeup.

Also hit 3 pod evictions mid-run (`Pod ephemeral local storage usage
exceeds the total limit of containers 150Gi`), each traced to the
same cause: a shard's first-assigned `Under3`/`Under5` pattern hitting
the full timeout while ballooning to 45-55GB peak memory. Fixed each
time with a per-shard "resume" taskfile excluding the already-timed-out
pattern rather than a blind full-shard retry — consistent with this
project's standing convention of not retrying deterministic solver
failures, only genuine infra failures, and preserving partial shard
progress when a retry is warranted.

### Round 8: the 138 conclusive-`INSANE` patterns — a fourth, tuning-only phenomenon

After rounds 7's two follow-ups (`convnc`, `convloose`), 138 of the 214
non-crash-family patterns remained `CONVERGED_INSANE` — a real,
conclusive result (small negative CC/CC2/FR values), not a timeout or
crash. Correcting an earlier miscount: this is 138, not 143 — 5 of
`convnc`'s "non-crash-family" patterns actually did hit the confirmed
`SIGTRAP` crash (see the crash-tally update above), and those 5 belong
with the crash-bug population, not this bucket.

Residual-magnitude analysis (parsing each `reason=INSANE:negative
values: ...` field) found this population's median magnitude is small
(0.0054) and family-skewed (`Under5` median 0.0015, closest;
`OverUnder5` 0.0066, largest and also the biggest single family at
72/125). Crucially, these patterns *converged* — FasterCap stopped
cleanly at `-a0.02`, in 3-55 seconds, at low round counts — it just
stopped with small sign-flipped coupling terms. That's a different
signature from both round-7 fixes: not solver instability (mesh
explosion), not a `NaN`/`Inf` crash — more consistent with
under-refinement leaving small-signal noise on weak coupling terms.
That points the opposite direction from the mesh-explosion fix:
*tighter* precision, not looser, was the natural thing to try first.

Took the 20 closest-to-sane patterns (magnitude < ~0.002) and re-ran
each single-pattern-per-pod at `-a0.01` and `-a0.005` (40 pods total,
at the established cap). **Result: 11/20 (55%) rescued to
`CONVERGED_SANE`**, zero new timeouts across most of the batch, zero
crashes. Staged at
`../scratch_logs/v2_flag_completed_patterns_convprobe_rescue_v9.tsv`,
tightest-successful-`-a` tie-break applied (same rule as
`M14oM13uM15`). Confirmed non-monotonic per-pattern again: some need
`a0.005` and fail at `a0.01`; others (e.g. `Under5/M7uM8/S0.057`) are
`SANE` at `a0.01` but *time out* at `a0.005` — tighter is not
uniformly better, consistent with everything else learned about `-a`
this session.

Of the remaining 9: 8 showed essentially **zero response** to `-a`
tightening at all (residual magnitude unchanged to the 4th decimal
across `0.02`/`0.01`/`0.005`) — suggesting `-a` isn't the relevant
lever for these specifically, and mesh-shaping (`-d`/`-s`) might be,
following the exact playbook that closed `M14oM13uM15`'s last
holdout spacing. The 9th (`Under5/M2uM6/S0.28`) was a clean, close
`INSANE` at `-a0.02` (magnitude 0.0004) but newly **timed out** at
both `a0.01` and `a0.005` — worth finding the boundary rather than
assuming tighter is safe. A 36-pod follow-up (these 9 patterns × 4
configs: `-d0.05`, `-d0.02`, `-a0.015`, `-d0.02 -s0.01`, base flags
`-pB128 -a0.02` otherwise) confirmed the `M14oM13uM15` lesson
generalizes: **7 of 9 rescued**, every one of them under `-d0.02`
(several also worked under `-d0.05`/`-d0.02 -s0.01`; `-d0.02` staged
as the consistent tie-break winner). Only 2 remain fully resistant
across all 4 configs — `OverUnder5/M4oM2uM5/S0.72` and
`OverUnder5/M4oM1uM5/S1.08`, also the two largest-magnitude residuals
in the original 20-pattern sample, so their resistance is consistent
rather than surprising. Staged in
`../scratch_logs/v2_flag_completed_patterns_convprobe_rescue_v10.tsv`.

**Scaling the tighter-`-a` fix to the full remainder**: the other 118
of the 138 `CONVERGED_INSANE` patterns had never been re-probed at
all (only the 20 closest-to-sane had). Given `convtight`'s 55% hit
rate, ran the same `-a0.01`/`-a0.005` sweep across all 118 (20 shards
per config, ~6 patterns/shard, 40 pods). **Result: 43/118 (36%)
rescued**, tightest-successful-`-a` tie-break applied (7 patterns had
both configs succeed). Staged in
`../scratch_logs/v2_flag_completed_patterns_convprobe_rescue_v11.tsv`.

Of the 75 not rescued: **10 hit a timeout**, and cross-checking
history shows **9 of these 10 are the literal same patterns from
round 7's original 18 mesh-explosion timeouts** — cleanly fixed (no
timeout at all) at the much looser `-a0.1` in `convloose`, but tighter
than the original `-a0.02` (down to `0.01`/`0.005`) reproduces the
identical runaway-mesh signature. Only 1 timeout
(`Over5/M2oM0/S0.112`) is genuinely new. **This is a real caveat for
this whole round's approach**: tightening `-a` to rescue weak-coupling
sign-flip noise trades off against reintroducing mesh-explosion
timeouts in `Under`-family patterns that a looser target had already
resolved — for that specific family shape, only a sufficiently loose
`-a` (around `0.1`) reliably avoids the runaway, not just "tighter
than the original 0.02." 2 more patterns crashed
(`Under5/M1uM3/S0.56`, `Over5/M1oM0/S0.224`, both backside) — new
instances, but of the already-known crash-prone family population, not
a new family (folded into `UNDERDIAG_CRASH_INVESTIGATION.md`'s tally,
232 → 234). The remaining 63 stayed a clean, conclusive
`CONVERGED_INSANE` under both configs, not yet tried with mesh-shaping.

**Running total after this whole round-8 exploration**: 50 more
patterns rescued (7 from `convtight2` + 43 from `convtight3`), on top
of round 8's initial 11 (`convtight`) — 61 total rescued this round.
Naive arithmetic (138 − 61) suggests 77 remaining, but that
double-counts: 2 of `convtight3`'s "unrescued" patterns actually
crashed (bug-related, not non-bug-`INSANE`) and were miscounted in an
earlier pass. **Verified directly against the master tracker files
(see "Current state, all families, project-wide" near the top of this
document): 74 patterns remain non-bug-related and non-`SANE`** — 62
clean `CONVERGED_INSANE` under every config tried (including
`convtight2`'s 2 fully-resistant holdouts, which never timed out,
just never went `SANE`) + 12 mesh-explosion timeouts (`Under5` 6,
`Under3` 2, `OverUnder3` 2, `OverUnder5` 1, `Over5` 1 — see
`MESH_EXPLOSION_INVESTIGATION.md`'s round-8 update for the confirmed
finding that several of these are the same patterns round 7's `-a0.1`
fix had already resolved, reproducing under `convtight3`'s tighter
targets).

### Round 9: scaling mesh-shaping to the full 63-pattern `-a`-resistant holdout, and a new mesh-explosion trigger

Round 8 left 74 non-bug patterns: 63 conclusively `CONVERGED_INSANE`
under both `-a0.01`/`-a0.005` in `convtight3` (never re-probed with
mesh-shaping — that lever had only been tried on `convtight2`'s much
smaller 9-pattern holdout), 9 already exhausted (2 from `convtight2`,
plus overlap already counted). Ran `convtight2`'s exact 4-config
playbook (`-d0.05`, `-d0.02`, `-a0.015`, `-d0.02 -s0.01`, all on
`-pB128 -a0.02` base) across all 63, sharded 40 pods (~1.6
patterns/shard on average, matching this session's established scale).

**Result: 40/63 (63.5%) rescued** — even better than `convtight2`'s
78% rate held up at 7x the population. `-d0.02` alone won the large
majority; tie-break priority `-d0.02` > `-d0.02 -s0.01` > `-d0.05` >
`-a0.015` (same convention as round 8). Staged in
`../scratch_logs/v2_flag_completed_patterns_convprobe_rescue_v12.tsv`.

**A genuinely new mesh-explosion trigger, confirmed deterministic**:
`OverUnder5/M5oM1uM9/S0.0315` hit a 150Gi ephemeral-storage eviction
under `-d0.05` — first observed during the main run, then re-run
standalone with a completely fresh storage budget and it evicted
again, identical cause. This is the first confirmed case of `-d`
tightening alone (independent of `-a`) triggering the runaway-mesh
failure mode from `MESH_EXPLOSION_INVESTIGATION.md`, previously only
seen under `-a` tightening. The pattern was still rescued overall —
`-d0.02` (tighter than the exploding `-d0.05`) converged cleanly in
20s — another non-monotonic boundary, this time confirming it applies
to `-d` exactly as it does to `-a`.

**A third distinct crash instance**: `Under5/M1uM3/S0.224` crashed
under `-a0.015` — a different spacing from the `Under5/M1uM3/S0.56`
crash `convtight3` found, same layer pair. Folded into
`UNDERDIAG_CRASH_INVESTIGATION.md`'s tally (234 → 235 pattern-attempts,
159 → 160 unique patterns).

**The 22 remaining non-bug patterns after this round are a tight
cluster**: 17 `OverUnder5`, 4 `OverUnder3`, 1 `Under5`. Notably
includes all 5 spacings of `OverUnder5 M4oM3uM5` — `BLACKOUT_PATTERNS.md`'s
"15th fully-blacked-out group," resistant across every config tried
this entire session (round 1's original 30 plus all of round 9's 4).
Every config tried across rounds 1-9 has varied `-a`/`-d`/`-s` on top
of a fixed `-pB128` (Block) preconditioner — preconditioner choice
itself has never been varied, and is the obvious remaining untried
lever for this cluster.

**Verified current total: 34 patterns remain non-bug-related and
non-`SANE`** (11 mesh-explosion timeout + 23 clean `CONVERGED_INSANE`)
— see "Current state, all families, project-wide" near the top of
this document, rebuilt from the master tracker files after this
round, not extended from round 8's arithmetic.

### Round 10: the first preconditioner-dimension probe

Every round since round 1 had only ever varied `-a` (refinement
target) and `-d`/`-s` (mesh shaping) — preconditioner choice had been
fixed at `-pB128` (Block) the entire session. Checked
`FasterCapConsole.cpp`'s actual command-line parser directly (not
assumed) and confirmed the real option set: `-pN` (none), `-pJ`
(Jacobi — the actual default when nothing is specified at all),
`-pB<dim>` (what this session has used throughout), `-pS<dim>`
(Super/two-level). `-pH` (Hierarchical) stays excluded — confirmed
broken in round 1 (SIGFPE crash on every pattern tried).

Ran all 34 remaining non-bug patterns under `-pJ`, `-pS128`, `-pS512`
(base `-d0.1 -s0.03 -a0.02` unchanged, isolating preconditioner choice
as the only variable), 13 shards/config, 39 pods.

**Result: 10/34 (29%) rescued.** No single preconditioner dominated —
`-pJ` won 7 (several tied with another config), `-pS128` won 6,
`-pS512` won 3. Staged in
`../scratch_logs/v2_flag_completed_patterns_convprobe_rescue_v13.tsv`.

**Headline finding: `OverUnder5 M4oM3uM5` partially resolved.** This is
`BLACKOUT_PATTERNS.md`'s "15th fully-blacked-out group" — resistant to
every config tried since round 1's original 30-config sweep. **2 of
its 5 spacings are now `CONVERGED_SANE`**: `S0.36` (unanimous — all 3
preconditioners converged it) and `S0.54` (`-pJ` and `-pS512`, not
`-pS128`). The other 3 spacings (`S0.72`, `S1.08`, `S1.8`) remain
`CONVERGED_INSANE` under all 3 preconditioners — a clean
spacing-dependent boundary: narrow spacing is fixable this way, wide
spacing is not, at least not by preconditioner choice alone.

**Confirms the mesh-explosion failure mode is preconditioner-independent
for at least one pattern**: `Under5/M2uM4/S0.112` was directly observed
(live `wires.log`/RSS inspection) hitting the identical 3600s timeout
under `-pJ` that it hits under every other config tried this session —
though 5 of the 11 previously-timeout patterns *did* get rescued this
round (a mix of `Under3/M4uM5` and `Under5/M4uM5`/`M2uM4`/`M2uM5`
spacings), so the failure mode isn't uniformly preconditioner-proof,
just proof against it for this specific pattern.

**Verified current total: 24 patterns remain non-bug-related and
non-`SANE`** (6 mesh-explosion timeout + 18 clean `CONVERGED_INSANE`)
— see "Current state, all families, project-wide" near the top of
this document.

### Round 11: combining the two proven levers — and a self-inflicted bug

Rounds 9-10 established two independently-successful but never-combined
levers: mesh-tightening (`-d0.02`, rescued 47 across rounds 9) and
preconditioner swap (round 10, 10/34). Round 11 combined them: the 18
clean-`CONVERGED_INSANE` patterns got preconditioner (`-pJ`/`-pS128`/
`-pS512`) *plus* `-d0.02`; the 6 mesh-explosion-timeout-prone patterns
got preconditioner *plus* the proven-safe loose `-a0.1` (round 7's
fix), testing whether preconditioner choice rescues more of this
population than `-a0.1` alone did.

**The first 36-pod launch was entirely wasted by a self-inflicted bug**:
the taskfile-generation script read `wc` values from a cached pickle
where they were already stored as `"wc5"`/`"wc3"`, then the taskfile
writer prepended another `"wc"` prefix, producing malformed
`"wcwc5"`/`"wcwc3"` fields that broke geometry conversion before
FasterCap ever ran for every single pattern (confirmed:
`stage=convert|rc=254` for the `-d0.02` set, zero output at all for
the `-a0.1` set). Caught by verifying actual solver output rather than
trusting job-phase "Complete" status, fixed the field position,
refreshed the ConfigMap, deleted all 36 jobs, and relaunched. Because
the results PVC path is reused across relaunches and the entrypoint
script appends rather than truncates its log, every `-d0.02` shard's
log carried one leftover malformed line from the failed attempt —
filtered out by excluding any line containing `wcwc`, verified this
cleanly isolated exactly the expected count of genuine new-run lines
with none lost or duplicated.

**Result (relaunched run): 7/24 (29%) rescued, zero timeouts, zero
crashes across all 72 attempts.** The loose-`-a` + preconditioner
combo on the 6 timeout-prone patterns did particularly well — **4 of 6
rescued** (`Over5/M2oM0/S0.112`, `Under5/M2uM4/S0.112`,
`Under5/M4uM5/S0.72`, `OverUnder3/M14oM13uM15/S0.54`), including the
exact `Under5/M2uM4/S0.112` that round 10 showed was
preconditioner-proof at the original `-a0.02`/`-d0.1` baseline —
combining the safe loose `-a` with a different preconditioner
succeeded where either alone had failed. The mesh-tightening set
rescued 3 of 18. No further `OverUnder5 M4oM3uM5` spacings resolved —
the 3 remaining (`S0.72`/`S1.08`/`S1.8`) stayed `CONVERGED_INSANE`
under every preconditioner combined with `-d0.02`, consistent with
that being a spacing-limited boundary rather than a lever gap.

**Verified current total: 17 patterns remain non-bug-related and
non-`SANE`** (2 mesh-explosion timeout + 15 clean `CONVERGED_INSANE`)
— see "Current state, all families, project-wide" near the top of
this document. With only 17 patterns left, spread thin across many
distinct layer-pairs/spacings rather than concentrated in a rescuable
cluster, and the two most-combinable levers already tried together,
returns from further probing on this specific population are likely
diminishing — a candidate stopping point for this line of
investigation, pending user direction on whether to continue. User
explicitly ruled out retrying `-pH` (confirmed broken, round 1).

### Round 12: GMRES tolerance and initial mesh density — a clean negative result

Two genuinely untried FasterCap dimensions, verified directly from
`FasterCapConsole.cpp`'s command-line parser rather than assumed:
`-t<tol>` (GMRES inner-iteration tolerance, default `0.01`, mechanically
distinct from `-a`/`-d`/`-s` — it controls the *linear solve* inside
each refinement round, not the refinement loop itself) and `-m<mesh>`
(initial mesh relative refinement, default `0.1`, the *starting* mesh
density before any auto-refinement begins, distinct from `-d`'s
refinement-ratio). Tested both tighter than default (`-t0.001`/
`-t0.0001`, `-m0.05`/`-m0.02`) plus one combo (`-d0.02` + `-t0.001`),
on all 17 remaining patterns (15 clean-`INSANE` at the standard
`-a0.02`, 2 timeout-prone at the safe `-a0.1`) — 33 pods, 83
pattern-attempts.

**Result: 0/83 (0%) rescued — a clean, unambiguous negative result,
not a parsing artifact** (verified: all 83 are genuine
`CONVERGED_INSANE`, zero timeouts, zero crashes, zero malformed data).
Neither linear-solve precision nor initial mesh density has any
measurable effect on this population. The residual magnitudes seen
here are notably larger and more varied (up to `CC≈-0.06`) than the
small weak-coupling noise that motivated round 8's tighter-`-a` fix —
consistent with this remaining population being a genuine geometric/
physical modeling limit rather than a numerical-precision gap, matching
`HOWTO.md`'s own documented prior finding: *"A residual negative-value
numerical artifact on weak, long-range coupling terms... No config
sweep resolves it; treat as a documented model gap."*

One infra note unrelated to the solver: one pod (`t2-shard0`) got stuck
in `Pending`/`ContainerCreating` because its assigned node was missing
a required CephFS CSI driver (`rook-system.cephfs.csi.ceph.com`),
causing repeated volume-mount failures — a cluster configuration issue
on that specific node, not a FasterCap or taskfile problem. Deleted and
recreated the job; it ran cleanly on a different node.

**Across rounds 8-12, every FasterCap CLI dimension has now been
tried on this remaining population**: `-a` (refinement target), `-d`/
`-s` (mesh shaping), preconditioner choice (`-pJ`/`-pB<dim>`/
`-pS<dim>`), `-t` (GMRES tolerance), `-m` (initial mesh density), and
combinations of the above. **Recommendation: stop probing this
specific 17-pattern population with further CLI-flag sweeps** — the
remaining gap looks like a genuine solver/physical limit this
project's own `HOWTO.md` already anticipated, not a configuration gap.
Verified current total unchanged: **17 patterns remain non-bug-related
and non-`SANE`.**
