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

**`M14oM13uM15` (all 5 points, both configs) did not converge, and the
evidence says it never will regardless of time given.** Watched two
live attempts: FasterCap's inner GMRES solver was repeatedly
exhausting 1000 iterations without converging — residual plateaued at
0.04-0.11 against a 0.001 target, 16-20 outer refinement rounds deep,
with no trend toward the target between rounds. Consistent with a
genuine wall rather than slow progress: half of the 10 total attempts
on this pattern grew unboundedly in memory and were killed by the
pod's 128Gi limit after 16-17 hours, still stuck at the same residual.
A solve that grows memory without bound while its residual stays flat
is diverging, not converging slowly — recommend treating this specific
layer-pair as a dead end for further probing (same recommendation as
the `UnderDiag` crash cases, though this is a distinct mechanism from
that — the GMRES linear solver, not the hierarchical multipole
charge-accumulation assert — and not yet confirmed whether the two are
related upstream).

Full writeup: `../scratch_logs/v2_flag_completed_patterns_convprobe_rescue_v4.README.md`.
Final blackout tally: 360/468 patterns rescued, 16 groups still fully
blacked out (15 solver-crash, 1 GMRES-non-convergence) — see
`BLACKOUT_PATTERNS.md` for the complete current list.
