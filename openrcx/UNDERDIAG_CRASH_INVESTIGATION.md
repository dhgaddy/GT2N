# Investigating the FasterCap hard-crash on Under/UnderDiag patterns

Working investigation log (not a validation doc, see
`TIMING_REGRESSION_INVESTIGATION.md`'s framing for the same convention).
Companion to that doc's convergence-probe section: across the
convresume/convexpand/convretry batches, 210 pattern-attempts ended in
`stage=fastercap|rc=133` (a genuine crash, not a timeout) — 92
`UnderDiag5`, 66 `UnderDiag3` (both frontside), 16 `Under5` and 14
`UnderDiag5` (backside), 2 stray `Over5` (backside).

**Update, final tally after the last harvest round (round 3):** the
crash count across every `a_0.001_ap`/`a_0.005_ap` job run in this
entire effort (all three probe/resume/expand/retry rounds combined) is
**227 pattern-attempts** — the extra 17 came from the round-3
`convexpand-a0001-gap` job's continued run. Same signature throughout
(`rc=133`, low elapsed time, few rounds), same root cause below. No new
family types affected; the distribution stays concentrated in
`Under`/`UnderDiag`.

## The question

Why does this crash concentrate almost entirely in `Under`/`UnderDiag`
families, at very low elapsed time (15-90s) and very few solver rounds
(6-8), when `Over`/`OverUnder` families essentially never hit it?

## Root cause: confirmed, not a guess

Pulled the actual saved crash detail for a real instance
(`gt2n-fastercap-convexpand-a0001-shard0`'s
`UnderDiag5/M5duM8/W0.021_W0.038/S0.042_S0.152_L10`, via
`save_detail()`'s copy to the PVC). Two pieces of direct evidence:

**`time.log`** (the `/usr/bin/time -v` wrapper around the FasterCap
invocation) says explicitly:
```
Command terminated by signal 5
Exit status: 0
```
Signal 5 = SIGTRAP. `128 + 5 = 133` — this is exactly where the `rc=133`
in every crash's `SKIPPED|...|stage=fastercap|rc=133` line comes from.
Not a hypothesis; the wrapper says so directly.

**`wires.log`** (raw FasterCap stdout, 7.6 MB for this one pattern) is
almost entirely one repeated line:
```
/work/FasterCap/Solver/MultiplyHierarchical.cpp(108): assert
"fabs(m_clsRecursVec[i]->m_dCharge) < 1E20" failed in
ComputePanelCharges_fast().
```
followed once, near the very end, by:
```
/work/FasterCap/Solver/MultiplyHierarchical.cpp(216): assert
"fabs(m_pNodes[i]->m_dPotential) < 1E20" failed in
ComputePanelPotentials_2fast().
```

Confirmed against the actual FasterCap source (both
`fastercap-v2-fork/FasterCap_v2` and `FasterCAP_v2/FasterCap_v2` — byte
identical at this file) at
`FasterCap/Solver/MultiplyHierarchical.cpp:108` and `:215` (off-by-one
from the log's `:216`, immaterial — same `ASSERT`, same file). The
surrounding code (`CMultHier::ComputePanelCharges_fast()`, lines
~70-115) is an unrolled recursive walk of the panel oct-tree: each
non-leaf node's charge is the sum of its two children's charges,
immediately followed by this exact assert as a sanity check. Its
firing means a panel's accumulated charge has blown past `1E20` in
magnitude — nowhere near a physically real value for these
(sub-micron-scale, low-count) patterns, so this is genuine numerical
divergence in the hierarchical multipole charge solve, not a
false-positive on legitimately large output.

`ASSERT` here is `wxASSERT` (`Geometry/GeoGlobal.h:53`,
`FasterCap/AutomationHelper.h:47`), wxWidgets' own assertion macro,
which on failure calls `wxTrap()` — documented wxWidgets behavior is
`raise(SIGTRAP)` under Unix. That's the exact mechanism connecting "an
`ASSERT` failed" to "the process died on signal 5": not a segfault, not
an uncaught C++ exception, a deliberate (if blunt, in a non-interactive
context) debug trap on a value that's already numerically insane.

**Conclusion: this is a real, reproducible FasterCap numerical-stability
bug in the hierarchical multipole solver (`CMultHier`), triggered by
something about these patterns' geometry that drives panel charges to
diverge during the recursive charge-accumulation pass — not a
tolerance/time problem, and not fixable by any `-a`/`-d`/`-s`/
preconditioner flag tried in the convprobe work.** More time or a
different config cannot help a run that's actively diverging toward
infinity, only different solver behavior (or fixed input geometry)
could.

## What geometric property actually predicts a crash: still open

Tested and ruled out two tidy hypotheses rather than assume either:

**"Zero diagonal spacing" (`S<x>_S0_L10`)** — several crashing patterns
do have a literal `S0` second-spacing value (a geometrically
degenerate/touching diag-neighbor placement, which would be a clean
story). But only 5 of 124 sampled crashes have it. **Ruled out as the
primary driver** — real, but a minor contributor at most.

**"Large vertical layer separation"** (the `Under`-only families'
defining trait is a *distant* coupling neighbor rather than an adjacent
one, so a wide metal-index gap seemed plausible) — computed the metal
index gap (`|met - under_neighbor_index|`) across the same 124 sampled
crashes: gap=1 accounts for 39/124, gap=2 for 24, gap=3 for 43, gap=4
for 18. No clean threshold; adjacent-layer crashes are actually the
single largest bucket. **Ruled out as the sole driver.**

What does hold up, cleanly, across all 210 occurrences: it is
essentially exclusive to the `Under`-type family shape (a reference
conductor with a coupling neighbor *below* it only — `Under5`,
`UnderDiag3`, `UnderDiag5` — vs. `Over`/`OverUnder`'s neighbor-above or
sandwiched geometry, which crashes almost never, 2 stray `Over5`
instances out of 210). That's a family-shape correlation, not yet a
geometric mechanism — i.e., confirmed *which* patterns are exposed, not
yet confirmed *why* that specific conductor arrangement destabilizes
`CMultHier`'s multipole tree construction. Plausible next-step
candidates, not yet checked: panel aspect ratio or oct-tree depth
specific to how the mesher subdivides a lone below-neighbor versus a
symmetric over+under sandwich, or something about how the mesh
generator sizes panels differently when there's no "over" conductor to
bound the geometry above. Would need to instrument or step through
`CMultHier`'s tree-build (not just the charge-compute assert site) on
a real crashing vs. a real non-crashing `Under5` pattern of otherwise
similar dimensions to pin this down further — not attempted here.

## Practical implication

Not a config-tuning problem. Filtering `Under`/`UnderDiag` patterns out
of future convprobe-style sweeps (or accepting they need a genuinely
different FasterCap invocation, e.g. a non-hierarchical solver mode, if
one exists) would avoid wasting wall-clock on a class of attempts that
can't be fixed by retrying with more time or a different `-a`/`-d`/`-s`
value.
