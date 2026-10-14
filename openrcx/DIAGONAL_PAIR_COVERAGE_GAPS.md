# Remaining diagonal-under coverage gaps after the crash-bug patch

Fix-oriented reference for the 14 metal-pair relationships that still
have zero `CONVERGED_SANE` data at any spacing, even after the
`PotEstimateOpt`/`SIGTRAP` crash bug was patched (see
`FASTERCAP_BUG_REPORT.md`/`UNDERDIAG_CRASH_INVESTIGATION.md` for that
fix) and validated against the full crash-bug-family population. This
document covers what's actually being served for these 14 at runtime,
how that compares to the alternatives considered, and why none of
those alternatives were adopted. It does not duplicate the general
historical blackout-rescue narrative in `BLACKOUT_PATTERNS.md`, or the
crash mechanism itself.

## Background: the patch worked, but didn't rescue everything

A 162-pattern, 11-config NRP sweep (`UnderDiag5`/`UnderDiag3`/`Under5`,
the full crash-bug family) against the patched `fastercap-fork`
confirmed the crash is fixed (0/1,782 attempts crashed, `rc=133`
never seen) but found 0/1,782 attempts produced a `CONVERGED_SANE`
result. Every result landed in the same already-documented
negative-`FR`/`CC2` precision-artifact failure mode (see
`scratch_logs/FASTERCAP_FINDINGS.md`'s root-cause section) at a rate
indistinguishable from what that investigation already found
unfixable by any of the same 11 configs.

Of the 162 patterns, 29 unique metal-pair relationships are affected.
**14 of those 29 have zero `CONVERGED_SANE` data at any spacing, in
any wire-count family** (a total coverage gap, not just missing
individual spacing points within an otherwise-sampled sweep). The
other 15 have partial coverage (3-8 sane spacing samples each) and
are not a concern here; normal distance-based interpolation handles
those.

**The 14 (frontside, `UnderDiag3`/`UnderDiag5`, reference metal M5 or
M7):**

| family | missing pairs |
|---|---|
| UnderDiag3 | M5-M6, M5-M7, M5-M8, M5-M9, M7-M8, M7-M9, M7-M10, M7-M11 |
| UnderDiag5 | M5-M6, M5-M8, M5-M9, M7-M8, M7-M9, M7-M10 |

(UnderDiag5's M5-M7 and M7-M11 do have real coverage: 2 and 7
`CONVERGED_SANE` rows respectively. UnderDiag3 has zero coverage for
any M5- or M7-anchored pair.)

## What OpenRCX actually serves for these today: not null, not zero

Confirmed by reading `src/rcx/src/extRCmodel.cpp` directly (in the
`openroad-fork` checkout), not inferred:

- `extDistRCTable::readRules` (lines 558-603) reads a `DIST count N`
  header and allocates a table regardless of N; `getComputeRC`
  (lines 667-675) returns `nullptr` only when the table is truly
  empty (`getCnt() <= 0`).
- `extMeasure::getDiagUnderCC` (lines 2125-2145, 2147-2165) returns
  `0.0` silently, with no warning, when that lookup is `nullptr`.
  Callers (`extmeasure.cpp:1979`, `:2146`) use it directly as an
  additive capacitance term.

**For these 14 pairs specifically, the table isn't empty.** The
rules-generation pipeline (`openrcx/scripts/build_combined_caps.py` +
`gen_rules_combined.tcl`) pools every wire-count variant of the
`UnderDiag` family (isolated `UnderDiag1`/`2` patterns alongside
densely-coupled `UnderDiag3`/`5` patterns) into one per-metal-pair
distance table. Since `UnderDiag1`/`2` data exists for all 14 pairs
(simpler, 1-2 wire isolated patterns, unaffected by the crash bug),
the compiled table ends up populated entirely with that data instead
of being empty. Confirmed directly in the regenerated
`gt2n_combined.rcx.model` (2026-10-11 regen, see below): e.g. `Metal
13 DIAGUNDER 14` (the compiled slot for `M7duM8`; combined-model
indices are `frontside M<n>` -> `Metal <n+6>`) has `DIST count 120`,
all attributable to `UnderDiag1`/`2` rows in `gt2n_frontside.caps`.

So extraction does not silently drop this term to zero for real
designs. It silently substitutes a value measured from a physically
different (fewer-neighboring-wire) pattern, with no warning either
way.

## How wrong is the substitute, actually?

Checked directly rather than assumed, using `M6duM7` (a pair where
both isolated and densely-coupled data exist, so the two can be
compared on the same physical geometry):

| family | n | avg FR | avg TC |
|---|---|---|---|
| UnderDiag1 | 1 | 0.026473 | 0.026473 |
| UnderDiag2 | 18 | 0.017567 | 0.031781 |
| UnderDiag3 | 27 | 0.016809 | 0.033392 |
| UnderDiag5 | 45 | 0.016286 | 0.035958 |

A clean, monotonic trend as wire count increases: `FR` drops ~8%
and `TC` rises ~13% from the isolated case to the densest case. This
is the charge-sharing/shielding effect the wc3/wc5 sweep exists to
capture. Not a controlled same-spacing comparison, but a real,
directionally consistent signal, not noise.

**Conclusion**: the pooled substitute for these 14 pairs is biased by
something in the same 8-13% ballpark (for this specific pair; may
differ for others), toward the isolated-wire regime, for real
densely-routed nets. This is a real, known limitation, not a
negligible one.

## Alternatives considered and why they weren't adopted

**Fall back to GT2N's existing analytical wire-length model
(`setRC.tcl`/`set_layer_rc`) for just these 14.** Ruled out
architecturally. Confirmed via `src/est/src/EstimateParasitics.tcl`
(lines 33-120, 176-384, 430-443): this model is a single flat
resistance/capacitance-per-unit-length scalar *per layer*, derived
from the tech LEF's area and edge capacitance. It has no concept of
which neighbor a wire couples to, no distance-dependence, and no
coupling-type distinction (over/under/diagonal) at all. There is no
"M7-M8 diagonal value" to extract from it, for any spacing. The
project's own docs already describe it as cruder than real
per-net extraction (`README.md:225`, `:321`; `RULES_VALIDATION.md:204`
contrasts it against the real extracted SPEF, with -6% to +28%
total-power deltas cited in `RULES_VALIDATION.md` section 4).

Compared to the pooled substitute already in use (real simulated
physics of the correct geometry and distance-dependence, off by
~8-13% on wire-count context), a flat per-layer scalar with zero
per-pair or per-distance granularity is a strictly worse
approximation. **The existing accidental fallback already beats this
alternative**, so there is nothing to gain by switching to it for
these 14.

**Manually approximate/interpolate values from physically similar,
already-covered pairs.** This requires knowing which pattern-name
metals are actually physically identical. **Important correction**:
pattern names use a table-position offset from the `.pro`-declared
conductor names, confirmed empirically (`M6duM7`'s embedded width is
`W0.021_W0.038`, which only matches `.pro` M5/M6, not M6/M7, which
are both 0.038) -- **pattern-name `M<n>` is `.pro`-declared
`M<n-1>`**. An earlier draft of this document got this wrong (claimed
pattern-names M6/M7/M8/M9 were one identical physical tier); the real
tiers, re-derived from `gt2n_process_frontside.pro` directly, are:

- Tier A (pattern-names 5, 6): `.pro` M4/M5, thickness 0.042/width
  0.021 -- only 2 members.
- Tier B (pattern-names 7, 8, 9, 10): `.pro` M6-M9, thickness
  0.076/width 0.038 -- 4 members.
- Tier C (pattern-names 11, 12): `.pro` M10/M11.

Under this corrected mapping, `M7duM8`, `M7duM9`, and `M7duM10` are
all *within* tier B (not crossing into a different tier at M10, as
the earlier draft claimed). `M5duM6` is the *only possible* pair
within tier A (2 members). `M5-M7`/`M5-M8`/`M5-M9` are tier-A-to-tier-B
crossings.

**Tested the "physically identical conductor -> interchangeable
coupling" assumption directly, across a tier boundary, and it
failed.** `M5-M7` (gap=2, real covered `UnderDiag5` data, n=10) vs.
`M6-M8` (gap=2, the "shift by one tier-A position" analog, n=70)
should agree closely if physical identity transfers across the A/B
boundary -- they don't: `avgTC` ratio is **0.42**, not ~1.0. So this
method, however physically plausible-sounding, is empirically wrong
for tier-crossing pairs in this dataset (plausibly because a thinner
reference conductor diagonally coupling into a thicker neighbor tier
behaves differently depending on which side changes thickness, not
just the gap distance; or because the small `n=10` sample for
`M5-M7` is itself not very representative, given M5/M7 as *reference*
conductors are part of the same general "Under"-type geometry class
already known to be numerically marginal).

**What does hold up: within-tier-B self-consistency.** The two
independent gap=1 analogs inside tier B agree closely, per family:

| family | M8-M9 (gap1) | M9-M10 (gap1) | M8-M10 (gap2) |
|---|---|---|---|
| UnderDiag3 | 0.05710 (n=19) | 0.05740 (n=21) | 0.05421 (n=19) |
| UnderDiag5 | 0.06091 (n=45) | 0.06078 (n=45) | 0.05895 (n=45) |

Both families' two independent gap=1 measurements agree to within
0.5%, and gap=2 is only mildly (3-5%) lower, a gentle, plausible
decay with distance. This is genuine, validated self-consistency,
unlike the cross-tier case above.

**Resulting confidence per pair:**

| pair | basis | confidence |
|---|---|---|
| M7-M8 (gap1), M7-M9 (gap2) | within-tier-B analogs above, cross-validated to within 0.5% | Strong |
| M7-M10 (gap3) | within tier B, no same-gap analog (tier B only has 4 members) but the gap1-to-gap2 trend is gentle enough to extrapolate (~UD3 0.051, ~UD5 0.057) | Moderate |
| M5-M6 | only possible tier-A pair; no other tier-A member to compare against | None |
| M5-M7, M5-M8, M5-M9 | cross-tier shift method tested and empirically disproven (0.42 ratio) | None |
| M7-M11 (UnderDiag3 only) | cross-tier (B-to-C), same failure mode plausible, untested | Unknown |

**Implemented (2026-10-13)** for `M7duM8`/`M7duM9` (both families).
`scratch_logs/v2_flag_manual_approx_within_tier.tsv` (36 synthetic
rows: 2 pairs x 2 families x 9 W/S combos) borrows the matched-W/S
raw measurement from the within-tier-B analog(s) -- `avg(M8duM9,
M9duM10)` for `M7duM8` (gap=1, averaging the two independent
analogs), `M8duM10` directly for `M7duM9` (gap=2) -- rewriting only
the `Metal`/`DiagUnder` index fields and the pattern name to the
target pair; every geometry field (`Dist`, `Width`, `DiagDist`,
`DiagWidth`, `LEN`) is identical by construction since the W/S match
was exact. `build_combined_caps.py` now also excludes the old
`UnderDiag1`/`2` isolated rows for these two pairs specifically
(`EXCLUDE_PATTERNS`), confirmed necessary first: traced
`extRCmodel.cpp`'s table-building code and found that leaving old and
new rows mixed would not average them -- at a shared distance only
the last file-order row survives (unpredictable), and at distinct
nearby distances they'd blend via linear interpolation across the
transition (distorting values near the boundary). Clean replacement
was the only safe option.

Verified after regenerating: `Metal 13 DIAGUNDER 14`/`15` (the
compiled `M7duM8`/`M7duM9` slots) changed as expected, and every
unrelated pair checked (`M8duM9`, `M9duM10`, `M7duM11`) is
byte-identical to before the change -- confirming the edit is
correctly scoped to just these two pairs.

`M7duM10` was deliberately left untouched (not implemented) --
moderate confidence only, and treating it the same way would need an
extrapolated (not directly matched) analog. `M5duM6`, `M5duM8`,
`M5duM9` (both families), plus `UnderDiag3`'s `M5duM7` and
`M7duM11`, have no working interpolation method found, not for lack
of a plausible-sounding argument (there were two: same-tier
substitution and cross-tier ratio-scaling) but because the one the
data could actually test failed. They would need either a dedicated
convergence investigation (is there something about M5/M7
specifically, as reference conductors, that a targeted fix could
resolve) or should stay documented as a gap.

## Rules file regeneration (2026-10-11)

Regenerated `openrcx/scripts/gt2n_combined.rcx.model` from the
current `gt2n_frontside.caps`/`gt2n_backside.caps` (which already
include the convprobe-rescue v2-v14 rounds; `build_combined_caps.py`
was updated to include v12-v14, which it was missing before). Clean
run, no errors, loads without parse errors in a full 21-layer
(`met_cnt=21`, backside 1-6 + frontside 7-21) model.

A full anomaly scan (1,096 empty leaf tables found file-wide) traced
every one down: all resolve to either cross-stack combinations
(pairing a backside layer index with a frontside one, which the
per-stack pattern generation structurally never produces) or
same-stack pairs beyond the generator's own `over_dist`/`under_dist`
sweep limit (gap >= 5). None represent a new, previously-unknown
coverage problem beyond the 14 pairs already described above.

One item flagged but not fully confirmed: `Metal 6` (backside's
topmost layer) and `Metal 7` (frontside's bottommost layer, M1) have
entire family sections empty (`UNDER`/`OVERUNDER` and width variants),
not just individual distance slots. Very plausibly the same
cross-stack-boundary explanation (an `OVERUNDER` triple at a boundary
layer needs a neighbor from the *other* stack, which can't be
generated from either stack's `.pro` file alone), but this wasn't
independently verified the way the OVER/UNDER/DIAGUNDER distance-limit
explanation was. Worth a quick dedicated check before assuming it's
benign.

**Deployed (2026-10-13)**: copied to `openrcx/rules/gt2n_combined.rcx.model`
(the canonical, previously-deployed location), after the `M7duM8`/
`M7duM9` approximation above was folded in. Nothing in this whole
document's worth of changes has been committed yet.

## M7duM10: measured-but-possibly-large vs. modeled-but-unverified

Revisited whether leaving `M7duM10` on the isolated substitute is
actually the safer default, now that we have better data than the
single cross-tier `M6duM7` estimate used earlier.

**Measured the isolated-vs-dense bias specifically within tier B**
(using the pairs that actually anchor `M7duM8`/`M7duM9`, not a
cross-tier pair):

| pair | gap | isolated avgTC | dense avgTC | bias |
|---|---|---|---|---|
| M8-M9 | 1 | 0.05663 | 0.05978 | +5.6% |
| M9-M10 | 1 | 0.05725 | 0.05971 | +4.3% |
| M8-M10 | 2 | 0.05067 | 0.05754 | +13.6% |

Bias is always positive (dense > isolated, consistent with more
neighboring wires adding more coupling paths) and grows with gap,
4-14% across what's measurable within this tier.

**`M7-M10`'s own isolated value looks anomalously low** against this
backdrop: `0.04303`, versus `0.0507`-`0.0573` for its physically
identical tier-mates at the same or smaller gaps. If `M7` behaved
like `M8`/`M9`/`M10` do, its isolated value should be in that same
range, not meaningfully below it.

**This is not a one-off.** It's the same pattern already found
earlier in this document: `M5-M7` (gap=2, real data) failed to agree
with its "shift by one tier-A position" analog `M6-M8` by more than
2x. Both findings point the same way: `M7` (and `M5`) specifically,
when acting as the *reference* conductor, produce anomalous results
in a context that otherwise behaves consistently for `M8`/`M9`/`M10`
as reference. Not yet explained -- see the open investigation below.

**Practical consequence**: the isolated substitute currently served
for `M7duM10` isn't simply "the known 4-14% bias" -- it likely carries
extra, unquantified error specific to `M7` as reference on top of
that. The not-yet-implemented extrapolated estimate has its own
different, unverified-but-plausibly-smaller uncertainty (one modeled
step past the validated `M8-M9`/`M9-M10`/`M8-M10` data, versus a
substitute with a demonstrated anomaly). Neither option has a clean
advantage; this is a genuine toss-up, not a "leave it alone, it's
known-good" situation.

## Open investigation: why does M7 (and M5) specifically misbehave?

Not yet explained. Two independent pieces of evidence that `M7` (and
`M5`) do something different from their tier-mates specifically when
acting as the *reference* conductor:

1. `M5-M7`'s real value disagreeing with the `M6-M8` shift-analog by
   2.4x (section above).
2. `M7-M10`'s isolated value sitting well below where its tier-mates'
   isolated values would predict (this section).

Candidate angle not yet checked: `M5` and `M7` are each the *first*
member of their tier, sitting immediately above a thickness/width
step-up from the layer below (`M4`->`M5`: 0.028/0.014 -> 0.042/0.021;
`M6`->`M7`: 0.042/0.021 -> 0.076/0.038, in `.pro` terms). `M6`, `M8`,
`M9`, `M10` are not at a tier boundary in this sense. Whether that
structural position actually explains the anomaly, versus a data/
sampling artifact or something connected to the same "Under"-type
geometry the original crash bug was already rooted in, is the open
question -- see the investigation that follows.

## Bottom line

Of the 14 pairs, `M7duM8`/`M7duM9` (both families, 4 of the 14) now
have the within-tier-B approximation implemented and deployed (see
above), replacing their isolated-pattern substitute with real
densely-coupled data borrowed from a validated, physically-identical
analog. `M7duM10` (both families) is a genuine toss-up, not a clear
"leave it" call: a measured-but-possibly-M7-anomaly-inflated
substitute versus a modeled-but-unverified extrapolation, pending the
open investigation into why `M7`/`M5` misbehave as reference
conductors. The remaining 9 (`M5duM6`, `M5duM8`, `M5duM9` in
both families, plus `UnderDiag3`'s `M5duM7` and `M7duM11`) still get
the isolated-pattern substitute -- a real, quantified (~8-13% on the
one pair directly checked, directionally toward under-counting
dense-routing coupling) but bounded and better-than-the-wire-length-
model limitation, not a silent zero and not an unbounded error -- and
have no working approximation method found despite two genuine
attempts. They should stay documented as an accepted model gap unless
a dedicated convergence investigation into M5/M7 as reference
conductors turns up something new.
