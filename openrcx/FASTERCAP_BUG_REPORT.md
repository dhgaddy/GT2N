# FasterCap crash on `Under`/`UnderDiag` geometry: bug report + fix starter

This is a fix-oriented bug report, distinct from
`UNDERDIAG_CRASH_INVESTIGATION.md` (which is the working investigation
log this report is distilled from — read that for the full discovery
narrative, family/geometry statistics, and what's still open). This
document exists so someone can start fixing the actual FasterCap bug
without reading that history first.

## Summary

FasterCap (the `FasterCap_v2` fork at
`fastercap-v2-fork/FasterCap_v2` / `FasterCAP_v2/FasterCap_v2`, byte-
identical at the relevant files) crashes with `SIGTRAP` (exit code
133 under `/usr/bin/time`) on a specific, reproducible class of input
geometry: patterns where a reference conductor has a coupling
neighbor *below* it only (this project's `Under5`/`UnderDiag3`/
`UnderDiag5` pattern families), almost never on patterns with a
neighbor *above* or on both sides (`Over*`/`OverUnder*`). Confirmed
across 232 real pattern-attempts in production use (this project's
FasterCap-based OpenRCX calibration pipeline, across multiple
different `-a`/preconditioner configs — not specific to one flag
combination); see `UNDERDIAG_CRASH_INVESTIGATION.md` for the full
family/geometry breakdown.

The crash is a deliberate `wxASSERT` trap (not a segfault, not an
unhandled exception) firing because a computed potential or
accumulated panel charge has become `NaN`/non-finite/unboundedly
large — i.e., a real numerical divergence in the solver, not a
false-positive assert on legitimately large output.

## Minimal, verified, standalone reproduction

`openrcx/fastercap_bug_repro/` in this repo contains a complete,
self-contained reproduction — a real production input pulled from
this project's pipeline (not synthesized to trigger the bug
artificially), all its referenced geometry files, and no other
dependencies:

```
cd openrcx/fastercap_bug_repro
FasterCap -b wires.lst -g -a0.001 -ap
```

**Verified against a locally-built `FasterCap_v2` binary
(`FasterCAP_v2/build/FasterCap`, version 6.0.7 per its own banner) —
reproduces on every run, crashes within ~1-25 seconds, exit code 133.**
The `Wires/`/`Dielectrics/` geometry files in that directory are a mix
of originals (pulled from this project's saved crash artifacts) and a
handful reconstructed by hand from the project's own simple box-panel
text format (documented inline, trivial to verify: each file is a
rectangular prism's faces as `Q <name> x1 y1 z1  x2 y2 z2  x3 y3 z3
x4 y4 z4` quads) — reconstruction was necessary because a few of the
original files weren't retained locally; the reconstructed ones are
geometrically identical to what the original run used, confirmed by
first reproducing successfully with them included.

`wires.lst`'s header line names the exact source pattern:
`UnderDiag5/M5duM8/W0.021_W0.038/S0.042_S0.152_L10` (frontside, wc5),
originally solved with `-a0.001 -ap`. **Any `-a` value reproduces the
crash** — this is not specific to `-a0.001`; see
`TIMING_REGRESSION_INVESTIGATION.md`'s convergence-probe work, which
tried 30 distinct FasterCap configurations (preconditioners, mesh
parameters, refinement targets) against patterns in this same crash
population and never avoided this failure mode with any of them.

## Root cause: confirmed via direct source + log inspection, not inferred

Two independent crash sites, **both stemming from the same underlying
divergence and confirmed to cascade together in a single run** (not
two unrelated bugs — verified by reproducing and seeing both fire in
sequence in the same process, see below):

### Site 1 — `CAutoRefine::PotEstimateOpt()`, `Autorefine.cpp`

```cpp
// Autorefine.cpp:3647 (wrapper/dispatcher)
int CAutoRefine::PotEstimateOpt(CAutoElement *element1, CAutoElement *element2, double &potestim1)
{
    ...
    _ASSERT(!isnan(potestim1));       // line 3662
    _ASSERT(isfinite(potestim1));     // line 3663
    return ret;
}

// Autorefine.cpp:3671 (actual panel-pair implementation `PotEstimateOpt` calls into)
int CAutoRefine::PotEstimateOpt(CAutoPanel *panel1, CAutoPanel *panel2, double &potestim1, unsigned char computePrecond)
{
    ...
    _ASSERT(!isnan(potestim1));       // line 3885 -- same check, redundant with above
    _ASSERT(isfinite(potestim1));     // line 3886

    // *** this code already exists and already handles the NaN/Inf case gracefully ***
    if(isnan(potestim1) || !isfinite(potestim1) ) {
        if(m_clsGlobalVars.m_bWarnGivenNaN == false) {
            m_clsGlobalVars.m_bWarnGivenNaN = true;
            ErrMsg("Error: mutual-potential calculation failed.\n");
            ErrMsg("       Remark: the precision of the result is affected.\n");
        }
        ...
        return AUTOREFINE_ERROR_NAN_OR_INF;   // <-- this is UNREACHABLE in practice
    }
    return AUTOREFINE_NO_ERROR;
}
```

**This is the single most actionable finding in this report**: the
codebase *already contains* graceful degradation for exactly this
condition (print a one-time warning, return an error code, let the
caller decide what to do) — but it can never run, because the
`_ASSERT` two lines above it fires first and traps the process via
`wxTrap()`/`SIGTRAP` before execution ever reaches the `if` block.
`_ASSERT` here is literally `#define _ASSERT wxASSERT` (confirmed:
`Autorefine.h:42`, `Linalg.h:38`) — the same macro as `ASSERT` used at
the second crash site below (`GeoGlobal.h:53`: `#define ASSERT
wxASSERT`), just aliased under a different name depending on which
header a file includes. Both fire identically.

**A first fix to try**: delete or downgrade the two redundant
`_ASSERT` pairs at `Autorefine.cpp:3662-3663` and `:3885-3886` (e.g.
to a non-fatal log call, or simply remove them) and let the existing
`AUTOREFINE_ERROR_NAN_OR_INF` handling actually execute. This doesn't
fix the underlying numerical divergence, but it's the difference
between "FasterCap crashes" and "FasterCap emits a warning and
degrades gracefully" for this whole failure class — the graceful path
was clearly intended to handle this exact case and was likely only
ever exercised in configurations where the compiled-in assert didn't
fire.

### Site 2 — `CMultHier::ComputePanelCharges_fast()` / `ComputePanelPotentials_2fast()`, `MultiplyHierarchical.cpp`

```cpp
// MultiplyHierarchical.cpp:108
ASSERT(fabs(m_clsRecursVec[i]->m_dCharge) < 1E20);

// MultiplyHierarchical.cpp:215 (ComputePanelPotentials_2fast)
ASSERT(fabs(m_pNodes[i]->m_dPotential) < 1E20);
```

Unrolled recursive walk of the panel oct-tree during the hierarchical
multipole solve: each non-leaf node's charge is the sum of its two
children's charges, sanity-checked against a `1E20` magnitude bound
immediately after. No graceful-degradation code follows this assert
(unlike Site 1) — this one is a hard stop as written.

**Confirmed causal link, not two independent bugs**: reproducing this
exact input multiple times shows both sites firing *in the same
process*, in sequence — the `Autorefine.cpp` potential-estimate
divergence happens first (during mesh refinement), and the
`MultiplyHierarchical.cpp` charge/potential divergence happens later
in the same run (during the actual solve), consistent with a bad
potential estimate from Site 1 propagating forward and eventually
blowing up the accumulated charge/potential checked at Site 2. Which
one actually terminates the process first appears to vary between
runs (observed both orderings across repro attempts) — plausibly a
timing/thread-interleaving effect, since FasterCap's solve is heavily
multi-threaded (~300-500% CPU observed in every crash's `time -v`
output).

## What's confirmed vs. still open

**Confirmed:**
- Exact crash mechanism (`wxASSERT` → `wxTrap()` → `SIGTRAP`, exit
  133) — not a hypothesis, directly stated by `time -v`'s "Command
  terminated by signal 5" plus the assert message in FasterCap's own
  stdout.
- The divergence is real numerical blow-up (`NaN`/non-finite/`>1E20`
  magnitude), not a false-positive assert on legitimately large but
  valid output.
- Two related assert sites, causally linked in a single cascade (not
  independent bugs).
- One of the two sites already has unreachable graceful-degradation
  code — a concrete, low-risk starting point for a fix.
- Not fixable by any FasterCap command-line flag — 30 distinct
  configurations tried in production use, none avoided it.
- Family-shape correlation: essentially exclusive to `Under`-type
  geometry (reference conductor with a coupling neighbor below only),
  vs. `Over`/`OverUnder` (neighbor above, or both sides), which
  crashes almost never (2 stray exceptions out of 210+ occurrences).

**Still open** (see `UNDERDIAG_CRASH_INVESTIGATION.md` for what's been
ruled out so far — zero-diagonal-spacing and layer-separation distance
were both tested and rejected as the primary driver):
- *Why* the `Under`-only conductor arrangement specifically drives
  `PotEstimateOpt`'s formula (far-panel dipole approximation or
  near-panel numerical integration, depending on classification — see
  `Autorefine.cpp:3863-3879`) to diverge, when the same solver handles
  `Over`/`OverUnder` geometry fine. Candidate next step: instrument or
  step through `PotEstimateOpt`'s near/far panel classification and
  the two formula branches (`EnFieldNumerical`/`MutualD_2thOrd_FullNum`
  for near panels vs. the simple `dotprod1 / (4*pi*e0*r^3)` formula for
  far panels) on a real crashing `Under5` pattern to see which branch
  and which specific panel pair produces the first `NaN`/`Inf` value.
- Whether removing/downgrading the two `_ASSERT`s at Site 1 alone is
  sufficient, or whether Site 2's hard assert also needs the same
  treatment (likely yes, given the confirmed cascade) plus whatever
  numerical guard would need to accompany it (e.g., clamping,
  re-deriving the value via a fallback formula, or excluding the
  offending panel pair from the multipole tree).

## Files in this report

- `openrcx/fastercap_bug_repro/` — the minimal standalone reproduction
  (`wires.lst` + `Wires/` + `Dielectrics/`, run with `FasterCap -b
  wires.lst -g -a0.001 -ap`).
- `openrcx/UNDERDIAG_CRASH_INVESTIGATION.md` — the full investigation
  log: family/geometry statistics across 227 real occurrences, the two
  hypotheses tested and ruled out, and how this crash relates to the
  broader convergence-probe rescue effort.
