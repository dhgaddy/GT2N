# GT2N OpenRCX Rules: Calibration Coverage & Design QoR Tracking

Scope: this document tracks (1) how completely the FasterCap calibration
data underlying `openrcx/rules/gt2n_combined.rcx.model` actually
converged, broken down by geometric pattern family, and (2) real
before/after QoR results for HighTide gt2n designs built with the rules
file wired in via `RCX_RULES`, as we run them.

Numbers in section 1 and 2 are computed directly from
`scratch_logs/v2_flag_completed_patterns.tsv`,
`scratch_logs/v2_flag_completed_patterns_RDL_bonus.tsv`,
`scratch_logs/insane_converged_patterns_queue.tsv`, and
`scratch_logs/insane_converged_patterns_queue_RDL.tsv` — not
hand-copied from prose elsewhere — so they can be regenerated and
checked against this doc if the source files change. For the
authoritative Stack × WC breakdown (a different, complementary slice of
the same data), see `scratch_logs/V2_FLAG_PROGRESS_TRACKER.md`.

"Family" here means the geometric pattern family the FasterCap solve
was run as — `Over`, `Under`, `OverUnder`, `UnderDiag` — the same
grouping `gen_rules_tcl.py` uses for `read_rcx_tables -over/-under/
-over_under/-diag`. This is a different axis than "WC" (wire count:
wc1/wc2/wc3/wc5, which controls `-wire_index`) — a single WC bucket can
contain multiple families.

## 1. Calibration pattern convergence, by family

Combined across non-RDL and RDL/BRDL (v2-scoped) patterns — i.e. the
full set of patterns that actually feed `gt2n_{frontside,backside}.caps`
today via `build_combined_caps.py`.

| Family | Converged (CONVERGED_SANE) | Confirmed unconvergeable | Total attempted | % Converged |
|---|---|---|---|---|
| Over | 1,142 | 218 | 1,360 | 84.0% |
| Under | 920 | 104 | 1,024 | 89.8% |
| OverUnder | 2,413 | 467 | 2,880 | 83.8% |
| UnderDiag | 1,537 | 255 | 1,792 | 85.8% |
| **TOTAL** | **6,012** | **1,044** | **7,056** | **85.2%** |

Split by scope, for context:

| Scope | Converged | Confirmed unconvergeable | Total | % Converged |
|---|---|---|---|---|
| Non-RDL (main v2 scope) | 5,230 | 898 | 6,128 | 85.3% |
| RDL/BRDL (v2-scoped) | 782 | 146 | 928 | 84.3% |

**Every RDL/BRDL pattern in the true v2-scoped universe has been
attempted.** The canonical universe (deduped (stack, wc, pattern)
triples from `all_patterns_v2.txt`) is **928** unique patterns, matching
782 + 146 = 928 exactly, zero remaining. The 1 confirmed-unconvergeable
RDL pattern was escalated through the full 3-config experimental round
and 7-config D-bracket round, failing identically at every tier (same
negative-FR/CC2 signature as the non-RDL failures).

## 2. Patterns that never converged sane

These are not "not yet tried" — every one of these was run through the
full escalation pipeline (nonstop auto-refine → 3-config experimental
round → 7-config D-bracket round) and still produced a negative
CC/FR/TC/CC2 on every attempt.

| Family | Confirmed unconvergeable | % of that family's attempts |
|---|---|---|
| OverUnder | 467 | 16.2% |
| UnderDiag | 255 | 14.2% |
| Over | 218 | 16.0% |
| Under | 104 | 10.2% |
| **TOTAL** | **1,044** | **14.8%** |

**Root cause (not a config or parsing gap):** confirmed to be a real
FastCap solver-precision limitation on weak/long-range coupling terms
— reproduced directly against raw solver output. See
`scratch_logs/FASTERCAP_FINDINGS.md`, "Root-caused the negative-FR/
negative-CC2 residual" section, for the full investigation. Practical
effect on the rules file: these specific (family, width, spacing)
combinations have no real measured point in `gt2n_{frontside,
backside}.caps`; OpenRCX's own interpolation across the surrounding
measured points fills the gap rather than erroring.

## 3. GT2N design QoR: analytical baseline vs. RCX rules

All RCX-rules entries below use `gt2n_combined.rcx.model` generated
2026-09-15 after both crash fixes (real-routing-level remap + Over/
Under swap for backside; two-distance-sample resistance rows to
satisfy `readRules_res2`'s ≥2-group requirement). Scope: every gt2n
HighTide design that reaches `_final` cleanly on real routing, macro-
containing or not (lfsr, minimax, sha3, floonoc; NVDLA partition_a/m/
p/o; gemmini) — excluding only `bp_uno` (still WIP, explicitly out of
scope) and designs that failed on real, RCX-unrelated global-route
congestion before extraction is ever reached (snitch_cluster, NVDLA
partition_c). All RCX-rules builds produced a real, non-stub
`6_final.spef` (240 KB – 258 MB), confirming genuine extraction ran.

**Baseline = the actual config HighTide adopted**, not a fresh local
rebuild, for every design with an archived comparison doc. Pulled from
each design's own `scratch_logs/<design>_gt2n/
<design>_gt2n_qor_comparison.md` (the row explicitly marked `FINAL`,
which is not always the highest-numbered or most-recently-dated run —
lfsr's is v6, minimax's is v1, sha3's and floonoc's are both v22) and
its matching archived `6_finish.rpt`/`6_report.json` under that same
directory's `reports/`. gemmini has no such archived comparison doc
(its port is documented directly in `designs/src/gemmini/DECISIONS.md`
instead), so its baseline row below comes from a fresh local build with
`RCX_RULES` temporarily removed from `BUILD.bazel`, read via the same
`6_report.json` fields — its setup/hold WNS and period_min match
DECISIONS.md's documented baseline exactly (+2.38 ps setup, 15 residual
hold violations, TNS −31.85 ps), confirming this rebuild reproduces the
adopted config rather than drifting from it.

**Field sourcing, verified against HighTide's own `update-results`
skill** (`.claude/skills/update-results/SKILL.md`), which documents
exactly what `results.html` reads from each design's `6_report.json`:
Slack = `finish__timing__setup__ws`, Fmax = `finish__timing__fmax`
(÷1e9 for GHz), Power = `finish__power__total` (×1000 for mW). Every
number below (both baseline and RCX-rules) is pulled from these same
fields — Fmax/period_min numerically coincide with `report_clock_min_
period`'s own printed output, confirmed directly. TNS is included here
in addition to what `results.html` shows (it drops TNS as "always 0,
redundant with Slack" for HighTide's own all-clean baseline rows — not
true for some of our RCX-rules rows, so it's kept).

| Design | Configured clock | Baseline period_min / Fmax | RCX-rules period_min / Fmax | Δ period_min | Baseline setup WNS/TNS | RCX-rules setup WNS/TNS | Baseline hold WNS/TNS | RCX-rules hold WNS/TNS |
|---|---|---|---|---|---|---|---|---|
| lfsr | 160 ps | 139.38 ps / 7.17 GHz | 138.27 ps / 7.23 GHz | −0.8% | 20.62 / 0 | 0 / 0 | 24.32 / 0 | 0 / 0 |
| minimax | 780 ps | 780.50 ps / 1.28 GHz | 712.43 ps / 1.40 GHz | −8.7% | **−0.50 / −0.50** (1 violation) | 0 / 0 | 0 violations | 0 violations |
| sha3 | 425 ps | 423.17 ps / 2.36 GHz | 398.58 ps / 2.51 GHz | −5.8% | 1.83 / 0 | 0 / 0 | 0 violations | **−9.32 / −231.35** (92 violations) |
| floonoc | 958 ps | 871.55 ps / 1.15 GHz | 1102.53 ps / 0.91 GHz | +26.5% | 86.45 / 0 | **−144.53 / −13,767.7** (190 violations) | 7.49 / 0 | **−16.82 / −147.5** (27 violations) |
| NVDLA partition_a | 895 ps | 854.22 ps / 1.05 GHz | 1036.28 ps / 0.96 GHz | +21.3% | 0 / 0 | **−141.28 / −2,549.19** (23 violations) | 0 violations | 25 violations |
| NVDLA partition_m | 660 ps | 589.63 ps / 1.70 GHz | 551.08 ps / 1.81 GHz | −6.5% | 0 / 0 | 0 / 0 (0 violations) | 0 violations | **63 violations** |
| NVDLA partition_p | 1635 ps | 1428.89 ps / 0.70 GHz | 1542.33 ps / 0.65 GHz | +7.9% | 0 / 0 | 0 / 0 (0 violations) | 0 violations | **8 violations** |
| NVDLA partition_o (core / falcon, multi-clock) | 2270 / 2838 ps | 2229.07 / 845.18 ps (0.45 / 1.18 GHz) | 2224.49 / 818.47 ps (0.45 / 1.22 GHz) | −0.2% / −3.2% | 0 / 0 | 0 / 0 (0 violations) | 8 violations | **2 violations** |
| gemmini | 1450 ps | 1447.62 ps / 0.69 GHz | 1509.86 ps / 0.66 GHz | +4.3% | 0 / 0 | **−59.86 / −477.47** (19 violations) | −9.83 / −31.85 (15 violations) | **−77.16 / −15,009.1** (751 violations) |

partition_p's model version is not fully confirmed (its build reached
the final extraction stage right as `gt2n_combined.rcx.model` was
regenerated to close the RDL gap, +5 patterns out of ~7,056 total, RDL
family only) — negligible in practice, but noted for completeness.
Every other row uses the model at commit `cfa94b11`.

lfsr, minimax, sha3, and NVDLA partition_m show a lower (better)
achievable period under RCX rules than the baseline analytical model.
floonoc and NVDLA partition_a both show a real setup and hold
regression against a baseline that was fully clean (0 violations of
either kind) at the same configured clock. partition_m and partition_p
are a third pattern on their own: setup stays clean (partition_m even
improves: period_min 589.63→551.08 ps; partition_p regresses slightly:
1428.89→1542.33 ps but with 0 violations either way) while new hold
violations appear against a clean baseline (63 for partition_m, 8 for
partition_p) — 5 of 8 designs (sha3, floonoc, partition_m, partition_p,
gemmini) picking up new or worsened hold violations under RCX rules,
independent of which direction setup moves. NVDLA partition_o breaks
that pattern in the other direction: both its clocks tighten slightly
(core −0.2%, falcon −3.2%) *and* hold actually improves — the baseline
already carried 8 pre-existing hold violations (documented and
accepted in its own `partition_o_gt2n_qor_comparison.md` as within this
design's hold tolerance), and RCX rules bring that down to 2. gemmini
is the inverse of partition_o on the same starting point: its baseline
also carries pre-existing hold violations (15, documented in its own
DECISIONS.md as not yet closed), but RCX rules drive that to 751 (and
newly break setup, which was clean at baseline) rather than improving
it — the largest regression of any design in this table. So it isn't
simply "RCX rules add hold violations," nor "a design with pre-existing
hold violations improves under RCX rules" — both directions occur
starting from the same kind of baseline. "RCX rules universally improve
(or worsen) gt2n timing" is not a safe conclusion at this point in
either direction.

## 4. GT2N design power: analytical baseline vs. RCX rules

Kept as a separate table from section 3 so neither gets too dense to
scan. Same baseline-sourcing rule as section 3: pulled from HighTide's
own adopted `FINAL` build for each design, not a fresh rebuild.
`report_power` runs unconditionally in `report_metrics.tcl` regardless
of `RCX_RULES` — power numbers existed under the baseline too. What
changes is the switching-power term's accuracy: baseline computes it
off `setRC.tcl`'s flat per-layer analytical capacitance, RCX-rules
computes it off the real per-net capacitance in the actual extracted
`6_final.spef` (loaded via `read_spef`, only reached inside the
`RCX_RULES`-gated branch of `final_report.tcl`).

| Design | Baseline internal (W) | RCX internal (W) | Baseline switching (W) | RCX switching (W) | Baseline leakage (W) | RCX leakage (W) | Baseline total (W) | RCX total (W) | Δ total |
|---|---|---|---|---|---|---|---|---|---|
| lfsr | 1.623e-04 | 1.649e-04 | 1.057e-04 | 1.209e-04 | 3.32e-06 | 3.59e-06 | 2.713e-04 | 2.895e-04 | +6.7% |
| minimax | 2.580e-03 | 2.462e-03 | 1.700e-03 | 1.530e-03 | 5.65e-04 | 5.49e-04 | 4.840e-03 | 4.542e-03 | −6.2% |
| sha3 | 2.050e-02 | 2.614e-02 | 3.320e-02 | 4.250e-02 | 6.73e-04 | 6.84e-04 | 5.430e-02 | 6.933e-02 | +27.7% |
| floonoc | 1.636e-02 | 2.214e-02 | 1.147e-02 | 1.064e-02 | 1.980e-03 | 1.952e-03 | 2.981e-02 | 3.474e-02 | +16.5% |
| NVDLA partition_a | 9.83e-03 | 9.77e-03 | 8.71e-03 | 8.12e-03 | 1.39e-03 | 1.45e-03 | 1.99e-02 | 1.93e-02 | −3.0% |
| NVDLA partition_m | 4.18e-03 | 4.20e-03 | 4.88e-03 | 4.50e-03 | 8.34e-04 | 8.70e-04 | 9.90e-03 | 9.57e-03 | −3.3% |
| NVDLA partition_p | 1.95e-02 | 1.73e-02 | 5.69e-03 | 4.23e-03 | 2.97e-03 | 2.88e-03 | 2.82e-02 | 2.44e-02 | −13.5% |
| NVDLA partition_o | 2.03e-02 | 2.23e-02 | 8.60e-03 | 7.68e-03 | 9.01e-03 | 8.73e-03 | 3.79e-02 | 3.87e-02 | +2.1% |
| gemmini | 2.800e-01 | 2.770e-01 | 4.976e-01 | 4.661e-01 | 2.224e-02 | 2.224e-02 | 7.998e-01 | 7.653e-01 | −4.3% |

**Reading this alongside section 3:** the two designs with the biggest
power increases (sha3 +27.7%, floonoc +16.5%) are also the two with new
hold violations — plausible common cause, since hold fixing (more/
bigger buffers on short paths) and higher measured switching
capacitance can both stem from RCX rules reporting more real
capacitance on the same nets than the analytical model assumed. Not
confirmed — would need the actual per-net cap deltas, not just the
aggregate power number, to say this is the mechanism rather than a
coincidence. lfsr's small increase and minimax's actual decrease don't
fit that story as cleanly, and gemmini directly breaks it: the largest
hold-violation increase in the whole table (15→751) pairs with a power
*decrease* (−4.3%), not an increase. Treat this as a hypothesis to
check, not a conclusion.

## Possible future additions

- **DRC violation count** (routing DRC, not timing) — confirming it
  stays at 0 both ways would rule out an unrelated regression getting
  attributed to the rules file by mistake.
- **Instance/cell count**, using the same per-class field (`class:*`,
  excluding filler_cell/tap_cell/antenna_cell) on both sides — a
  secondary, quieter QoR signal alongside period_min. (Comparing a raw
  total on one side against a filtered count on the other gives a
  false ~3× discrepancy — use matching fields.)
- **Build/extraction wall-clock time** — the analytical model is
  effectively free; real `extract_parasitics` is not. Relevant if this
  needs to run at scale (full HighTide suite, or bp_processor once a
  macro strategy exists).
- **Worst-path identification** (which net/layer/cell dominates) as a
  column or linked note for any row with a violation.
- **Which family/layer a design's critical path routes through**,
  cross-referenced against section 1's per-family convergence rates —
  would connect section 1 and section 3 instead of leaving them
  separate.
