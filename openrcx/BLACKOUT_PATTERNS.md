# Fully-blacked-out calibration patterns

Companion list to `TIMING_REGRESSION_INVESTIGATION.md`. These are the
individual patterns behind the 102 `(stack, family, layer-pair)`
combinations where **every** spacing point in that combination's sweep
failed to converge (0 real measurements — see the investigation doc's
"Rules-file gap structure" section for how these were found and what
the extraction flow does with them: silently contributes zero
capacitance for that specific coupling term, not a crash, not an
interpolation).

468 patterns total across 102 groups. Format per line:
`stack<TAB>wc<TAB>pattern` (exact fields from
`insane_converged_patterns_queue.tsv` / `_RDL.tsv`), grouped under a
`### stack family layer-pair` header. Recovering even a single point
per group would give that group its first real anchor instead of zero.

**Final update (convprobe, all 4 rescue rounds — see
`TIMING_REGRESSION_INVESTIGATION.md`'s "Convergence-probe results"
section): 360 of 468 patterns rescued — 53 of 102 groups now fully
converged, 33 partially (at least one real anchor), 16 still 100%
blacked out.** Rescued lines are marked `**SANE (convprobe)**` below;
group headers show each group's current rescued/missing split. The
rescued rows are staged (not yet merged) across
`../scratch_logs/v2_flag_completed_patterns_convprobe_rescue{,_v2,_v3,_v4}.tsv`.

**Round 4 gave these 4 timeout-only groups an unlimited per-pattern
time budget (900s → ~1 year) instead of a fixed longer retry, and let
them run for ~a day.** Result: confirmed the hypothesis was right for
3 of 4 groups, wrong for the 4th:

- `frontside OverUnder5 M7oM6uM8`: 2/5 rescued (needed 19-31 min, well
  past 900s — genuinely just needed time).
- `frontside Under5 M5uM6`: 4/5 rescued (needed 19-53 min — same
  story).
- `backside OverUnder5 M4oM3uM5`: 0/5 rescued, but reached a genuine
  conclusive INSANE verdict on every point — a real result, not a
  timeout artifact.
- `frontside OverUnder5 M14oM13uM15`: **0/5 rescued on all 5 spacing
  points across both configs, and evidence points to this being
  unconvergeable at any time budget, not merely slow.** Watched two
  attempts live: FasterCap's inner GMRES solver was repeatedly
  exhausting 1000 iterations without converging (residual plateaued at
  0.04-0.11 vs. a 0.001 target, 16-20 outer rounds deep, no trend
  toward the target), and 5 of the 10 total attempts on this group hit
  the pod's 128Gi memory ceiling and were killed after 16-17 hours,
  still stuck at the same residual. Memory growing unboundedly while
  the residual stays flat is the signature of a solve that will not
  converge regardless of time or memory given — recommend **not**
  spending further probe effort here; see
  `../scratch_logs/v2_flag_completed_patterns_convprobe_rescue_v4.README.md`
  for the full writeup.

**16 groups now remain fully blacked out**, split into two distinct,
unrelated failure modes — not one problem:

- **15 of 16 are `UnderDiag3`/`UnderDiag5`** (8 + 7, all frontside,
  all concentrated on M5/M7 as the primary metal) — these are blocked
  by the confirmed FasterCap hierarchical-multipole-solver crash (real
  bug, `rc=133` SIGTRAP, see `UNDERDIAG_CRASH_INVESTIGATION.md`), not a
  time or tuning problem. No further probing of these specific groups
  is worthwhile until that bug is fixed or worked around upstream.
- **1 of 16** (`frontside OverUnder5 M14oM13uM15`) is the GMRES
  non-convergence case described above — a distinct, also-not-fixable-
  by-more-time mechanism, possibly related to the same underlying
  solver instability but not yet confirmed as such.

`backside OverUnder5 M4oM3uM5` moved from "fully blacked out" to
"reached real INSANE verdicts, not rescued" — it's no longer a timeout
gap, just a pattern that genuinely doesn't sanity-check under either
config tried.


### backside Over3 M2oM1 (5 patterns, 4 rescued by convprobe, 1 still missing)

- `backside	wc3	Over3/M2oM1/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `backside	wc3	Over3/M2oM1/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `backside	wc3	Over3/M2oM1/W0.056_W0.056/S0.112_S0.112_L10`
- `backside	wc3	Over3/M2oM1/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `backside	wc3	Over3/M2oM1/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### backside Over5 M2oM1 (5 patterns, ALL RESCUED by convprobe)

- `backside	wc5	Over5/M2oM1/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `backside	wc5	Over5/M2oM1/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `backside	wc5	Over5/M2oM1/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `backside	wc5	Over5/M2oM1/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `backside	wc5	Over5/M2oM1/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### backside OverUnder5 M2oM1uM3 (5 patterns, 4 rescued by convprobe, 1 still missing)

- `backside	wc5	OverUnder5/M2oM1uM3/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `backside	wc5	OverUnder5/M2oM1uM3/W0.056_W0.056/S0.084_S0.084_L10`
- `backside	wc5	OverUnder5/M2oM1uM3/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `backside	wc5	OverUnder5/M2oM1uM3/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `backside	wc5	OverUnder5/M2oM1uM3/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### backside OverUnder5 M2oM1uM6 (5 patterns, 3 rescued by convprobe, 2 still missing)

- `backside	wc5	OverUnder5/M2oM1uM6/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `backside	wc5	OverUnder5/M2oM1uM6/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `backside	wc5	OverUnder5/M2oM1uM6/W0.056_W0.056/S0.112_S0.112_L10`
- `backside	wc5	OverUnder5/M2oM1uM6/W0.056_W0.056/S0.168_S0.168_L10`
- `backside	wc5	OverUnder5/M2oM1uM6/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### backside OverUnder5 M4oM3uM5 (5 patterns, all missing)

- `backside	wc5	OverUnder5/M4oM3uM5/W0.36_W0.36/S0.36_S0.36_L10`
- `backside	wc5	OverUnder5/M4oM3uM5/W0.36_W0.36/S0.54_S0.54_L10`
- `backside	wc5	OverUnder5/M4oM3uM5/W0.36_W0.36/S0.72_S0.72_L10`
- `backside	wc5	OverUnder5/M4oM3uM5/W0.36_W0.36/S1.08_S1.08_L10`
- `backside	wc5	OverUnder5/M4oM3uM5/W0.36_W0.36/S1.8_S1.8_L10`

### frontside Over3 M11oM10 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc3	Over3/M11oM10/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM10/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM10/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM10/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM10/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside Over3 M11oM8 (5 patterns, 4 rescued by convprobe, 1 still missing)

- `frontside	wc3	Over3/M11oM8/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM8/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM8/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM8/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM8/W0.056_W0.056/S0.28_S0.28_L10`

### frontside Over3 M11oM9 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc3	Over3/M11oM9/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM9/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM9/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM9/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM9/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside Over3 M12oM10 (5 patterns, 4 rescued by convprobe, 1 still missing)

- `frontside	wc3	Over3/M12oM10/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM10/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM10/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM10/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM10/W0.056_W0.056/S0.28_S0.28_L10`

### frontside Over3 M12oM11 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc3	Over3/M12oM11/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM11/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM11/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM11/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM11/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside Over3 M12oM8 (5 patterns, 4 rescued by convprobe, 1 still missing)

- `frontside	wc3	Over3/M12oM8/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM8/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM8/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM8/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM8/W0.056_W0.056/S0.28_S0.28_L10`

### frontside Over3 M12oM9 (5 patterns, 4 rescued by convprobe, 1 still missing)

- `frontside	wc3	Over3/M12oM9/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM9/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM9/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM9/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM9/W0.056_W0.056/S0.28_S0.28_L10`

### frontside Over3 M5oM0 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc3	Over3/M5oM0/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM0/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM0/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM0/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM0/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside Over3 M5oM1 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc3	Over3/M5oM1/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM1/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM1/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM1/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM1/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside Over3 M5oM2 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc3	Over3/M5oM2/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM2/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM2/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM2/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM2/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside Over3 M5oM3 (5 patterns, 4 rescued by convprobe, 1 still missing)

- `frontside	wc3	Over3/M5oM3/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM3/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM3/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM3/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM3/W0.021_W0.021/S0.105_S0.105_L10`

### frontside Over3 M5oM4 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc3	Over3/M5oM4/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM4/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM4/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM4/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM4/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside Over3 M7oM0 (5 patterns, 4 rescued by convprobe, 1 still missing)

- `frontside	wc3	Over3/M7oM0/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM0/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM0/W0.038_W0.038/S0.076_S0.076_L10`
- `frontside	wc3	Over3/M7oM0/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM0/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside Over3 M7oM3 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc3	Over3/M7oM3/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM3/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM3/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM3/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM3/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside Over3 M7oM4 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc3	Over3/M7oM4/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM4/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM4/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM4/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM4/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside Over3 M7oM6 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc3	Over3/M7oM6/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM6/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM6/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM6/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM6/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside Over5 M11oM10 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	Over5/M11oM10/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM10/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM10/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM10/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM10/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside Over5 M11oM8 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	Over5/M11oM8/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM8/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM8/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM8/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM8/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside Over5 M11oM9 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	Over5/M11oM9/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM9/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM9/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM9/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM9/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside Over5 M12oM10 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	Over5/M12oM10/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM10/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM10/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM10/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM10/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside Over5 M12oM8 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	Over5/M12oM8/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM8/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM8/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM8/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM8/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside Over5 M12oM9 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	Over5/M12oM9/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM9/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM9/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM9/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM9/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside Over5 M5oM0 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	Over5/M5oM0/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM0/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM0/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM0/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM0/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside Over5 M5oM1 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	Over5/M5oM1/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM1/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM1/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM1/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM1/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside Over5 M5oM2 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	Over5/M5oM2/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM2/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM2/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM2/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM2/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside Over5 M5oM4 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	Over5/M5oM4/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM4/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM4/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM4/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM4/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside Over5 M7oM0 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	Over5/M7oM0/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM0/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM0/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM0/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM0/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside Over5 M7oM3 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	Over5/M7oM3/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM3/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM3/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM3/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM3/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside Over5 M7oM4 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	Over5/M7oM4/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM4/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM4/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM4/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM4/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM10uM12 (5 patterns, 2 rescued by convprobe, 3 still missing)

- `frontside	wc5	OverUnder5/M11oM10uM12/W0.056_W0.056/S0.056_S0.056_L10`
- `frontside	wc5	OverUnder5/M11oM10uM12/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM10uM12/W0.056_W0.056/S0.112_S0.112_L10`
- `frontside	wc5	OverUnder5/M11oM10uM12/W0.056_W0.056/S0.168_S0.168_L10`
- `frontside	wc5	OverUnder5/M11oM10uM12/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM10uM13 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M11oM10uM13/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM10uM13/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM10uM13/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM10uM13/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM10uM13/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM10uM14 (5 patterns, 4 rescued by convprobe, 1 still missing)

- `frontside	wc5	OverUnder5/M11oM10uM14/W0.056_W0.056/S0.056_S0.056_L10`
- `frontside	wc5	OverUnder5/M11oM10uM14/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM10uM14/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM10uM14/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM10uM14/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM7uM12 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M11oM7uM12/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM12/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM12/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM12/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM12/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM7uM13 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M11oM7uM13/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM13/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM13/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM13/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM13/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM7uM14 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M11oM7uM14/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM14/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM14/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM14/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM14/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM8uM12 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M11oM8uM12/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM12/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM12/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM12/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM12/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM8uM13 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M11oM8uM13/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM13/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM13/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM13/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM13/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM8uM14 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M11oM8uM14/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM14/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM14/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM14/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM14/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM9uM13 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M11oM9uM13/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM13/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM13/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM13/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM13/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM9uM14 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M11oM9uM14/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM14/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM14/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM14/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM14/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM9uM15 (5 patterns, 3 rescued by convprobe, 2 still missing)

- `frontside	wc5	OverUnder5/M11oM9uM15/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM15/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM15/W0.056_W0.056/S0.112_S0.112_L10`
- `frontside	wc5	OverUnder5/M11oM9uM15/W0.056_W0.056/S0.168_S0.168_L10`
- `frontside	wc5	OverUnder5/M11oM9uM15/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM10uM13 (5 patterns, 4 rescued by convprobe, 1 still missing)

- `frontside	wc5	OverUnder5/M12oM10uM13/W0.056_W0.056/S0.056_S0.056_L10`
- `frontside	wc5	OverUnder5/M12oM10uM13/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM13/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM13/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM13/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM10uM14 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M12oM10uM14/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM14/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM14/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM14/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM14/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM10uM15 (5 patterns, 4 rescued by convprobe, 1 still missing)

- `frontside	wc5	OverUnder5/M12oM10uM15/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM15/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM15/W0.056_W0.056/S0.112_S0.112_L10`
- `frontside	wc5	OverUnder5/M12oM10uM15/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM15/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM11uM13 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M12oM11uM13/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM11uM13/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM11uM13/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM11uM13/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM11uM13/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM11uM15 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M12oM11uM15/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM11uM15/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM11uM15/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM11uM15/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM11uM15/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM8uM13 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M12oM8uM13/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM8uM13/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM8uM13/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM8uM13/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM8uM13/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM8uM14 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M12oM8uM14/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM8uM14/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM8uM14/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM8uM14/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM8uM14/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM9uM13 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M12oM9uM13/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM13/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM13/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM13/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM13/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM9uM14 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M12oM9uM14/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM14/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM14/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM14/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM14/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM9uM15 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M12oM9uM15/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM15/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM15/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM15/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM15/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M14oM13uM15 (5 patterns, all missing)

- `frontside	wc5	OverUnder5/M14oM13uM15/W0.36_W0.36/S0.36_S0.36_L10`
- `frontside	wc5	OverUnder5/M14oM13uM15/W0.36_W0.36/S0.54_S0.54_L10`
- `frontside	wc5	OverUnder5/M14oM13uM15/W0.36_W0.36/S0.72_S0.72_L10`
- `frontside	wc5	OverUnder5/M14oM13uM15/W0.36_W0.36/S1.08_S1.08_L10`
- `frontside	wc5	OverUnder5/M14oM13uM15/W0.36_W0.36/S1.8_S1.8_L10`

### frontside OverUnder5 M5oM1uM7 (5 patterns, 4 rescued by convprobe, 1 still missing)

- `frontside	wc5	OverUnder5/M5oM1uM7/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM1uM7/W0.021_W0.021/S0.0315_S0.0315_L10`
- `frontside	wc5	OverUnder5/M5oM1uM7/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM1uM7/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM1uM7/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside OverUnder5 M5oM1uM8 (5 patterns, 4 rescued by convprobe, 1 still missing)

- `frontside	wc5	OverUnder5/M5oM1uM8/W0.021_W0.021/S0.021_S0.021_L10`
- `frontside	wc5	OverUnder5/M5oM1uM8/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM1uM8/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM1uM8/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM1uM8/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside OverUnder5 M5oM1uM9 (5 patterns, 4 rescued by convprobe, 1 still missing)

- `frontside	wc5	OverUnder5/M5oM1uM9/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM1uM9/W0.021_W0.021/S0.0315_S0.0315_L10`
- `frontside	wc5	OverUnder5/M5oM1uM9/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM1uM9/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM1uM9/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside OverUnder5 M5oM2uM7 (5 patterns, 4 rescued by convprobe, 1 still missing)

- `frontside	wc5	OverUnder5/M5oM2uM7/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM2uM7/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM2uM7/W0.021_W0.021/S0.042_S0.042_L10`
- `frontside	wc5	OverUnder5/M5oM2uM7/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM2uM7/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside OverUnder5 M5oM2uM8 (5 patterns, 4 rescued by convprobe, 1 still missing)

- `frontside	wc5	OverUnder5/M5oM2uM8/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM2uM8/W0.021_W0.021/S0.0315_S0.0315_L10`
- `frontside	wc5	OverUnder5/M5oM2uM8/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM2uM8/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM2uM8/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside OverUnder5 M5oM2uM9 (5 patterns, 4 rescued by convprobe, 1 still missing)

- `frontside	wc5	OverUnder5/M5oM2uM9/W0.021_W0.021/S0.021_S0.021_L10`
- `frontside	wc5	OverUnder5/M5oM2uM9/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM2uM9/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM2uM9/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM2uM9/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside OverUnder5 M5oM3uM6 (5 patterns, 1 rescued by convprobe, 4 still missing)

- `frontside	wc5	OverUnder5/M5oM3uM6/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM3uM6/W0.021_W0.021/S0.0315_S0.0315_L10`
- `frontside	wc5	OverUnder5/M5oM3uM6/W0.021_W0.021/S0.042_S0.042_L10`
- `frontside	wc5	OverUnder5/M5oM3uM6/W0.021_W0.021/S0.063_S0.063_L10`
- `frontside	wc5	OverUnder5/M5oM3uM6/W0.021_W0.021/S0.105_S0.105_L10`

### frontside OverUnder5 M5oM3uM8 (5 patterns, 4 rescued by convprobe, 1 still missing)

- `frontside	wc5	OverUnder5/M5oM3uM8/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM3uM8/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM3uM8/W0.021_W0.021/S0.042_S0.042_L10`
- `frontside	wc5	OverUnder5/M5oM3uM8/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM3uM8/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside OverUnder5 M5oM4uM6 (5 patterns, 1 rescued by convprobe, 4 still missing)

- `frontside	wc5	OverUnder5/M5oM4uM6/W0.021_W0.021/S0.021_S0.021_L10`
- `frontside	wc5	OverUnder5/M5oM4uM6/W0.021_W0.021/S0.0315_S0.0315_L10`
- `frontside	wc5	OverUnder5/M5oM4uM6/W0.021_W0.021/S0.042_S0.042_L10`
- `frontside	wc5	OverUnder5/M5oM4uM6/W0.021_W0.021/S0.063_S0.063_L10`
- `frontside	wc5	OverUnder5/M5oM4uM6/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside OverUnder5 M5oM4uM9 (5 patterns, 1 rescued by convprobe, 4 still missing)

- `frontside	wc5	OverUnder5/M5oM4uM9/W0.021_W0.021/S0.021_S0.021_L10`
- `frontside	wc5	OverUnder5/M5oM4uM9/W0.021_W0.021/S0.0315_S0.0315_L10`
- `frontside	wc5	OverUnder5/M5oM4uM9/W0.021_W0.021/S0.042_S0.042_L10`
- `frontside	wc5	OverUnder5/M5oM4uM9/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM4uM9/W0.021_W0.021/S0.105_S0.105_L10`

### frontside OverUnder5 M7oM3uM10 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M7oM3uM10/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM3uM10/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM3uM10/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM3uM10/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM3uM10/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM3uM11 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M7oM3uM11/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM3uM11/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM3uM11/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM3uM11/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM3uM11/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM4uM10 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M7oM4uM10/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM4uM10/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM4uM10/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM4uM10/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM4uM10/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM4uM9 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M7oM4uM9/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM4uM9/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM4uM9/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM4uM9/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM4uM9/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM5uM10 (5 patterns, 3 rescued by convprobe, 2 still missing)

- `frontside	wc5	OverUnder5/M7oM5uM10/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM10/W0.038_W0.038/S0.057_S0.057_L10`
- `frontside	wc5	OverUnder5/M7oM5uM10/W0.038_W0.038/S0.076_S0.076_L10`
- `frontside	wc5	OverUnder5/M7oM5uM10/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM10/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM5uM11 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M7oM5uM11/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM11/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM11/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM11/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM11/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM5uM8 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M7oM5uM8/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM8/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM8/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM8/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM8/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM5uM9 (5 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	OverUnder5/M7oM5uM9/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM9/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM9/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM9/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM9/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM6uM10 (5 patterns, 3 rescued by convprobe, 2 still missing)

- `frontside	wc5	OverUnder5/M7oM6uM10/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM6uM10/W0.038_W0.038/S0.057_S0.057_L10`
- `frontside	wc5	OverUnder5/M7oM6uM10/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM6uM10/W0.038_W0.038/S0.114_S0.114_L10`
- `frontside	wc5	OverUnder5/M7oM6uM10/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM6uM11 (5 patterns, 3 rescued by convprobe, 2 still missing)

- `frontside	wc5	OverUnder5/M7oM6uM11/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM6uM11/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM6uM11/W0.038_W0.038/S0.076_S0.076_L10`
- `frontside	wc5	OverUnder5/M7oM6uM11/W0.038_W0.038/S0.114_S0.114_L10`
- `frontside	wc5	OverUnder5/M7oM6uM11/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM6uM8 (5 patterns, 2 rescued by convprobe, 3 still missing)

- `frontside	wc5	OverUnder5/M7oM6uM8/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM6uM8/W0.038_W0.038/S0.057_S0.057_L10`
- `frontside	wc5	OverUnder5/M7oM6uM8/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM6uM8/W0.038_W0.038/S0.114_S0.114_L10`
- `frontside	wc5	OverUnder5/M7oM6uM8/W0.038_W0.038/S0.19_S0.19_L10`

### frontside Under5 M5uM6 (5 patterns, 4 rescued by convprobe, 1 still missing)

- `frontside	wc5	Under5/M5uM6/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	Under5/M5uM6/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	Under5/M5uM6/W0.021_W0.021/S0.042_S0.042_L10`
- `frontside	wc5	Under5/M5uM6/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	Under5/M5uM6/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside Under5 M5uM7 (5 patterns, 2 rescued by convprobe, 3 still missing)

- `frontside	wc5	Under5/M5uM7/W0.021_W0.021/S0.021_S0.021_L10`
- `frontside	wc5	Under5/M5uM7/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	Under5/M5uM7/W0.021_W0.021/S0.042_S0.042_L10`
- `frontside	wc5	Under5/M5uM7/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	Under5/M5uM7/W0.021_W0.021/S0.105_S0.105_L10`

### frontside Under5 M5uM9 (5 patterns, 1 rescued by convprobe, 4 still missing)

- `frontside	wc5	Under5/M5uM9/W0.021_W0.021/S0.021_S0.021_L10`
- `frontside	wc5	Under5/M5uM9/W0.021_W0.021/S0.0315_S0.0315_L10`
- `frontside	wc5	Under5/M5uM9/W0.021_W0.021/S0.042_S0.042_L10`
- `frontside	wc5	Under5/M5uM9/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	Under5/M5uM9/W0.021_W0.021/S0.105_S0.105_L10`

### frontside UnderDiag3 M11duM14 (3 patterns, ALL RESCUED by convprobe)

- `frontside	wc3	UnderDiag3/M11duM14/W0.056_W0.36/S0.056_S1.44_L10`  **SANE (convprobe)**
- `frontside	wc3	UnderDiag3/M11duM14/W0.056_W0.36/S0.084_S1.44_L10`  **SANE (convprobe)**
- `frontside	wc3	UnderDiag3/M11duM14/W0.056_W0.36/S0.112_S1.44_L10`  **SANE (convprobe)**

### frontside UnderDiag3 M11duM15 (3 patterns, ALL RESCUED by convprobe)

- `frontside	wc3	UnderDiag3/M11duM15/W0.056_W1.6/S0.056_S6.4_L10`  **SANE (convprobe)**
- `frontside	wc3	UnderDiag3/M11duM15/W0.056_W1.6/S0.084_S6.4_L10`  **SANE (convprobe)**
- `frontside	wc3	UnderDiag3/M11duM15/W0.056_W1.6/S0.112_S6.4_L10`  **SANE (convprobe)**

### frontside UnderDiag3 M12duM14 (3 patterns, 2 rescued by convprobe, 1 still missing)

- `frontside	wc3	UnderDiag3/M12duM14/W0.056_W0.36/S0.056_S1.44_L10`
- `frontside	wc3	UnderDiag3/M12duM14/W0.056_W0.36/S0.084_S1.44_L10`  **SANE (convprobe)**
- `frontside	wc3	UnderDiag3/M12duM14/W0.056_W0.36/S0.112_S0.72_L10`  **SANE (convprobe)**

### frontside UnderDiag3 M12duM15 (3 patterns, ALL RESCUED by convprobe)

- `frontside	wc3	UnderDiag3/M12duM15/W0.056_W1.6/S0.056_S3.2_L10`  **SANE (convprobe)**
- `frontside	wc3	UnderDiag3/M12duM15/W0.056_W1.6/S0.084_S6.4_L10`  **SANE (convprobe)**
- `frontside	wc3	UnderDiag3/M12duM15/W0.056_W1.6/S0.112_S6.4_L10`  **SANE (convprobe)**

### frontside UnderDiag3 M5duM6 (3 patterns, all missing)

- `frontside	wc3	UnderDiag3/M5duM6/W0.021_W0.021/S0.021_S0_L10`
- `frontside	wc3	UnderDiag3/M5duM6/W0.021_W0.021/S0.0315_S0_L10`
- `frontside	wc3	UnderDiag3/M5duM6/W0.021_W0.021/S0.042_S0_L10`

### frontside UnderDiag3 M5duM7 (3 patterns, all missing)

- `frontside	wc3	UnderDiag3/M5duM7/W0.021_W0.038/S0.021_S0_L10`
- `frontside	wc3	UnderDiag3/M5duM7/W0.021_W0.038/S0.0315_S0_L10`
- `frontside	wc3	UnderDiag3/M5duM7/W0.021_W0.038/S0.042_S0_L10`

### frontside UnderDiag3 M5duM8 (3 patterns, all missing)

- `frontside	wc3	UnderDiag3/M5duM8/W0.021_W0.038/S0.021_S0_L10`
- `frontside	wc3	UnderDiag3/M5duM8/W0.021_W0.038/S0.0315_S0_L10`
- `frontside	wc3	UnderDiag3/M5duM8/W0.021_W0.038/S0.042_S0_L10`

### frontside UnderDiag3 M5duM9 (3 patterns, all missing)

- `frontside	wc3	UnderDiag3/M5duM9/W0.021_W0.038/S0.021_S0_L10`
- `frontside	wc3	UnderDiag3/M5duM9/W0.021_W0.038/S0.0315_S0_L10`
- `frontside	wc3	UnderDiag3/M5duM9/W0.021_W0.038/S0.042_S0_L10`

### frontside UnderDiag3 M7duM10 (3 patterns, all missing)

- `frontside	wc3	UnderDiag3/M7duM10/W0.038_W0.038/S0.038_S0_L10`
- `frontside	wc3	UnderDiag3/M7duM10/W0.038_W0.038/S0.057_S0_L10`
- `frontside	wc3	UnderDiag3/M7duM10/W0.038_W0.038/S0.076_S0_L10`

### frontside UnderDiag3 M7duM11 (3 patterns, all missing)

- `frontside	wc3	UnderDiag3/M7duM11/W0.038_W0.056/S0.038_S0_L10`
- `frontside	wc3	UnderDiag3/M7duM11/W0.038_W0.056/S0.057_S0_L10`
- `frontside	wc3	UnderDiag3/M7duM11/W0.038_W0.056/S0.076_S0_L10`

### frontside UnderDiag3 M7duM8 (3 patterns, all missing)

- `frontside	wc3	UnderDiag3/M7duM8/W0.038_W0.038/S0.038_S0_L10`
- `frontside	wc3	UnderDiag3/M7duM8/W0.038_W0.038/S0.057_S0_L10`
- `frontside	wc3	UnderDiag3/M7duM8/W0.038_W0.038/S0.076_S0_L10`

### frontside UnderDiag3 M7duM9 (3 patterns, all missing)

- `frontside	wc3	UnderDiag3/M7duM9/W0.038_W0.038/S0.038_S0_L10`
- `frontside	wc3	UnderDiag3/M7duM9/W0.038_W0.038/S0.057_S0.076_L10`
- `frontside	wc3	UnderDiag3/M7duM9/W0.038_W0.038/S0.076_S0_L10`

### frontside UnderDiag5 M11duM12 (3 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	UnderDiag5/M11duM12/W0.056_W0.056/S0.056_S0.224_L10`  **SANE (convprobe)**
- `frontside	wc5	UnderDiag5/M11duM12/W0.056_W0.056/S0.084_S0.224_L10`  **SANE (convprobe)**
- `frontside	wc5	UnderDiag5/M11duM12/W0.056_W0.056/S0.112_S0_L10`  **SANE (convprobe)**

### frontside UnderDiag5 M5duM6 (3 patterns, all missing)

- `frontside	wc5	UnderDiag5/M5duM6/W0.021_W0.021/S0.021_S0_L10`
- `frontside	wc5	UnderDiag5/M5duM6/W0.021_W0.021/S0.0315_S0_L10`
- `frontside	wc5	UnderDiag5/M5duM6/W0.021_W0.021/S0.042_S0_L10`

### frontside UnderDiag5 M5duM7 (3 patterns, 2 rescued by convprobe, 1 still missing)

- `frontside	wc5	UnderDiag5/M5duM7/W0.021_W0.038/S0.021_S0_L10`  **SANE (convprobe)**
- `frontside	wc5	UnderDiag5/M5duM7/W0.021_W0.038/S0.0315_S0_L10`  **SANE (convprobe)**
- `frontside	wc5	UnderDiag5/M5duM7/W0.021_W0.038/S0.042_S0_L10`

### frontside UnderDiag5 M5duM8 (3 patterns, all missing)

- `frontside	wc5	UnderDiag5/M5duM8/W0.021_W0.038/S0.021_S0_L10`
- `frontside	wc5	UnderDiag5/M5duM8/W0.021_W0.038/S0.0315_S0_L10`
- `frontside	wc5	UnderDiag5/M5duM8/W0.021_W0.038/S0.042_S0_L10`

### frontside UnderDiag5 M5duM9 (3 patterns, all missing)

- `frontside	wc5	UnderDiag5/M5duM9/W0.021_W0.038/S0.021_S0_L10`
- `frontside	wc5	UnderDiag5/M5duM9/W0.021_W0.038/S0.0315_S0_L10`
- `frontside	wc5	UnderDiag5/M5duM9/W0.021_W0.038/S0.042_S0.152_L10`

### frontside UnderDiag5 M7duM10 (3 patterns, all missing)

- `frontside	wc5	UnderDiag5/M7duM10/W0.038_W0.038/S0.038_S0_L10`
- `frontside	wc5	UnderDiag5/M7duM10/W0.038_W0.038/S0.057_S0_L10`
- `frontside	wc5	UnderDiag5/M7duM10/W0.038_W0.038/S0.076_S0_L10`

### frontside UnderDiag5 M7duM11 (3 patterns, ALL RESCUED by convprobe)

- `frontside	wc5	UnderDiag5/M7duM11/W0.038_W0.056/S0.038_S0.224_L10`  **SANE (convprobe)**
- `frontside	wc5	UnderDiag5/M7duM11/W0.038_W0.056/S0.057_S0_L10`  **SANE (convprobe)**
- `frontside	wc5	UnderDiag5/M7duM11/W0.038_W0.056/S0.076_S0_L10`  **SANE (convprobe)**

### frontside UnderDiag5 M7duM8 (3 patterns, all missing)

- `frontside	wc5	UnderDiag5/M7duM8/W0.038_W0.038/S0.038_S0_L10`
- `frontside	wc5	UnderDiag5/M7duM8/W0.038_W0.038/S0.057_S0_L10`
- `frontside	wc5	UnderDiag5/M7duM8/W0.038_W0.038/S0.076_S0_L10`

### frontside UnderDiag5 M7duM9 (3 patterns, all missing)

- `frontside	wc5	UnderDiag5/M7duM9/W0.038_W0.038/S0.038_S0_L10`
- `frontside	wc5	UnderDiag5/M7duM9/W0.038_W0.038/S0.057_S0.152_L10`
- `frontside	wc5	UnderDiag5/M7duM9/W0.038_W0.038/S0.076_S0_L10`
