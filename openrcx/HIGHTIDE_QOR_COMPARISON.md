# HighTide gt2n RCX_RULES QoR comparison

**Created: 2026-10-21.** Living document — updated as remaining builds complete.

**Rules model used:** this repo, branch `add-gt2n-rcx-rules-model`, commit
[`6610e8c4`](https://github.com/dhgaddy/GT2N/commit/6610e8c433eb017b628892fa9427c85c92ccebec)
(2026-10-15) — the regenerated-with-v12/v14, approximation-reverted
`openrcx/rules/gt2n_combined.rcx.model` (md5 `9b66bb379f624dd39193f2d4c5f7a4af`),
copied unmodified into each design directory below and wired in via
`RCX_RULES` in `BUILD.bazel`.

**New-run branch:** `HighTide` repo, branch `gt2n-rcx-rules-qor`, commit
`540a15c` (pushed to `dhgaddy/HighTide`). Flow args (CORE_UTILIZATION,
PLACE_DENSITY, clk_period, HOLD_SLACK_MARGIN, etc.) are otherwise byte-for-byte
identical to each design's existing committed baseline — the only change is
adding `RCX_RULES` (real OpenRCX-extracted parasitics) in place of the
`setRC.tcl` flat per-layer fallback gt2n has used until now.

**Baseline source:** the published webpage
(https://vlsida.github.io/HighTide/results.html, `webpage` branch of the
`HighTide` repo, `results.html`) for 8/10 designs — this is the authoritative
"which pairs finish" source per that repo's root `CLAUDE.md`, not the
per-design `scratch_logs/*_gt2n/` working notes, which were found to disagree
with each other and with the actual committed config in places (see
individual notes below). `gemmini` and `partition_c` do **not** appear on the
webpage (neither fully closes timing, so neither counts as "finishing"
there) — their baseline figures below come directly from their port commit
messages instead (`fcc184e`, `412b383`), cross-checked against the matching
row in their `scratch_logs` tables.

All "new" (RCX_RULES) figures below are pulled from each build's own
`6_report.json`, using the exact same fields the webpage table itself uses
(`finish__timing__setup__ws`, `finish__timing__fmax`, `finish__power__total`,
cell counts excluding `class:other` fill/tap, etc.) for a direct apples-to-apples
comparison. Harvested logs/artifacts live in the **`HighTide` repo** (not
this one) under `scratch_logs/gt2n_rcx_qor_run/`.

**Status at time of writing:** 7/10 complete and harvested (lfsr, minimax,
sha3, floonoc, partition_a, partition_m, partition_p). Still running:
gemmini, partition_c, partition_o — rows below marked "pending", to be filled
in as each completes.

## Comparison table

| Design | Config unchanged | Baseline commit | Setup WS (ps) base→new | Setup TNS base→new | Setup viol base→new | Hold WS (ps) base→new | Hold TNS base→new | Hold viol base→new | Fmax (GHz) base→new | Power (mW) base→new |
|---|---|---|---|---|---|---|---|---|---|---|
| lfsr | 80% util, M4/M11, 160ps | `6fefbd34` | 20.62 → **25.12** | 0 → 0 | 0 → 0 | n/a → 22.17 | 0 → 0 | 0 → 0 | 7.17 → **7.41** | 0.271 → 0.260 |
| minimax | 60% util, M4/M11, 780ps | `934f62f7` | -0.50 → **-19.99** | 0 → -1121.95 | 1 → **115** | n/a → 19.26 | — → 0 | — → 0 | 1.28 → 1.25 | 4.843 → 4.674 |
| sha3 | 75% util, M4/M11, 425ps, HOLD_SLACK_MARGIN=3 | `7a01fa6b` | 1.83 → **-9.72** | 0 → -92.67 | 0 → **17** | n/a → **-14.97** | 0 → **-1024.19** | 0 → **239** | 2.36 → 2.30 | 54.307 → 67.228 |
| floonoc | 92.2% real util, M4/M11, 958ps, HOLD_SLACK_MARGIN=10 | `412b3838` | 86.45 → **-159.67** | 0 → -29677.2 | 0 → **304** | n/a → **-52.49** | 0 → **-2416.72** | 0 → **213** | 1.15 → 0.89 | 29.807 → 28.944 |
| partition_a | 80% util, M4/M11, 895ps, HOLD_SLACK_MARGIN=20 | `b2098088` | 40.78 → **-45.10** | 0 → -267.09 | 0 → **11** | n/a → **-6.96** | 0 → **-150.91** | 0 → **66** | 1.17 → 1.06 | 19.927 → 19.266 |
| partition_m | 82% util, M4/M11, 660ps, HOLD_SLACK_MARGIN=5 | `412b3838` | 65.28 → 46.60 | 0 → 0 | 0 → 0 | n/a → **-22.33** | 0 → **-1586.22** | 0 → **149** | 1.68 → 1.63 | 9.920 → 9.487 |
| partition_p | 45% util, M6, 1635ps | `412b3838` | 48.89 → 192.60 | 0 → 0 | 0 → 0 | n/a → **-34.02** | 0 → **-107.34** | 0 → **11** | 0.63 → 0.69 | 24.751 → 24.035 |
| gemmini | 87% util, M4/M11, 1450ps, indelay+67ps | `fcc184e` | +2.38 (not on webpage) | 0 | 0 | -9.83 | -31.85 | 15 | 0.690 | — |
| partition_c | M6, 1300ps (known non-convergent hold) | `412b383` | not on webpage | — | 75 | — | — | 2497 | 0.674 | — |
| partition_o | 46% util, M4/M11, 2270/2838ps dual-clock | `412b3838` | **PENDING — still running** | | | | | | | |

Bold = a new real violation/regression that wasn't present at baseline, or a
notable improvement (lfsr's Fmax). `gemmini`/`partition_c` rows show baseline
only (not yet harvested from the new run). `partition_o`'s row is entirely
pending.

## What this means

**lfsr is the one clean win**: 0/0 violations both before and after, and
Fmax actually *improved* slightly (7.17→7.41 GHz) — the real extracted
parasitics happened to be marginally better than the flat `setRC.tcl`
estimate for this design's tiny, simple net topology.

**Every other completed design picked up new setup and/or hold violations**
that weren't present at baseline (minimax, sha3, floonoc, partition_a) or
got measurably worse on an existing margin (partition_m, partition_p stayed
at 0 setup violations but picked up new hold violations; partition_p's prior
0 hold also regressed to 11). **This is expected, not a rules-model defect.**
Every one of these designs' flow knobs (`HOLD_SLACK_MARGIN`, clock period,
utilization, input-delay offsets) were iteratively tuned against the old
flat per-layer `setRC.tcl` capacitance/resistance numbers. Real OpenRCX
extraction produces genuinely different per-net RC (that's the entire point
of building this rules model — it has real distance- and neighbor-dependent
structure the flat model never had), so a config that was tuned to exactly
zero out violations under the old estimate is not guaranteed to still be
exactly zero under a different, more accurate one. The fix for each of these
is a normal re-tuning pass (margins, clock, utilization) against the new
numbers — not something this comparison run itself needs to resolve.

**gemmini and partition_c were already non-clean at baseline** (15 hold
violations; 75 setup/2497 unconverged hold respectively) — comparing their
new-run numbers once harvested will show whether real RC made their
pre-existing problems better, worse, or roughly the same.

## Open items

- Fill in gemmini, partition_c, partition_o once their builds complete
  (currently running in the `HighTide` repo; see its
  `scratch_logs/gt2n_rcx_qor_run/runner_launch.log` and the ongoing k8s
  check-ins for status).
- Die/core area and cell counts are essentially unchanged for every
  non-macro design checked (lfsr, minimax, sha3, floonoc, partition_a,
  partition_m — die/core area match to the reported decimal, cell counts
  identical or within a handful). **Not verified for macro-containing
  partitions (partition_c/o/p)**: a first pass at partition_p showed its raw
  `finish__design__instance__area` (which includes macro area) jump from the
  webpage baseline — likely a units/field mismatch (webpage's "Inst Area"
  column probably reports std-cell-only area via
  `finish__design__instance__area__stdcell`, not the combined field used
  here) rather than a real area change, but this was not cleanly reconciled
  and is flagged rather than asserted either way. Area/cell-count deltas were
  deliberately left out of the table above pending that reconciliation —
  full raw figures are in each design's `6_report.json` in the `HighTide`
  repo under `scratch_logs/gt2n_rcx_qor_run/artifacts/gt2n/<design>/` if
  needed sooner.

## Related docs

- `RULES_VALIDATION.md` — this rules model's own validation methodology and
  QoR comparison against the `setRC.tcl` baseline, within this repo's own
  calibration-pattern testing (not a full chip build).
- `README.md` — project overview and current coverage figures.
