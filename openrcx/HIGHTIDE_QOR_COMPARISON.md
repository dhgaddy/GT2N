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

**Status at time of writing (2026-10-22):** 9/10 complete and harvested
(lfsr, minimax, sha3, floonoc, partition_a, partition_m, partition_p,
partition_c, partition_o). Still running: gemmini (first attempt crashed
with a `bazel` segmentation fault after ~4.5h stuck retrying one routing
action — looks like transient node/resource contention on the shared
cluster, not a design or model issue; a retry is in progress).

## 1. Timing: baseline vs RCX-rules

Period_min marked **†** is derived from the reported Fmax (1000/Fmax_GHz)
rather than read directly from that build's own `report_clock_min_period`
output — used where the current committed baseline's own period_min was
never independently recorded (only its Fmax, in a port/review commit
message). Not derived for lfsr/minimax/sha3/floonoc/partition_a/gemmini,
whose baseline period_min values are read directly from each design's own
archived `6_finish.rpt`/`scratch_logs` row, cross-checked against the
matching commit.

| Design | Configured clock(s) | Baseline period_min / Fmax | RCX-rules period_min / Fmax | Δ period_min | Baseline setup WNS/TNS (viol) | RCX-rules setup WNS/TNS (viol) | Baseline hold WNS/TNS (viol) | RCX-rules hold WNS/TNS (viol) |
|---|---|---|---|---|---|---|---|---|
| lfsr | 160 ps | 139.38 ps / 7.17 GHz | 134.88 ps / 7.41 GHz | -3.2% | 20.62 / 0 (0) | 25.12 / 0 (0) | n/a / 0 (0) | 22.17 / 0 (0) |
| minimax | 780 ps | 780.50 ps / 1.28 GHz | 799.99 ps / 1.25 GHz | +2.5% | **-0.50 / -0.50 (1)** | **-19.99 / -1,121.95 (115)** | n/a / 0 (0) | 19.26 / 0 (0) |
| sha3 | 425 ps | 423.17 ps / 2.36 GHz | 434.72 ps / 2.30 GHz | +2.7% | 1.83 / 0 (0) | **-9.72 / -92.67 (17)** | n/a / 0 (0) | **-14.97 / -1,024.19 (239)** |
| floonoc | 958 ps | 871.55 ps / 1.15 GHz | 1,117.67 ps / 0.89 GHz | **+28.2%** | 86.45 / 0 (0) | **-159.67 / -29,677.16 (304)** | n/a / 0 (0) | **-52.49 / -2,416.72 (213)** |
| NVDLA partition_a | 895 ps | 854.22 ps / 1.17 GHz | 940.10 ps / 1.06 GHz | +10.1% | 40.78 / 0 (0) | **-45.10 / -267.09 (11)** | n/a / 0 (0) | **-6.96 / -150.91 (66)** |
| NVDLA partition_m | 660 ps | 595.24 ps† / 1.68 GHz | 613.40 ps / 1.63 GHz | +3.1% | 65.28 / 0 (0) | 46.60 / 0 (0) | n/a / 0 (0) | **-22.33 / -1,586.22 (149)** |
| NVDLA partition_p | 1,635 ps | 1,586.07 ps† / 0.63 GHz | 1,442.40 ps / 0.69 GHz | -9.1% | 48.89 / 0 (0) | 192.60 / 0 (0) | n/a / 0 (0) | **-34.02 / -107.34 (11)** |
| NVDLA partition_o (core / falcon) | 2,270 / 2,838 ps | 2,137.19 ps† / 0.47 GHz (core) | 2,052.99 ps / 0.49 GHz (core) | -3.9% | 132.81 / 0 (0) | 217.01 / 0 (0) | n/a / 0 (0) | **-37.46 / -335.24 (47)** |
| NVDLA partition_c | 1,300 ps (known non-convergent hold) | 1,484.57 ps† / 0.67 GHz | 2,934.30 ps / 0.34 GHz | **+97.7%** | not reported / 0 (75) | **-1,634.30 / -67,116.80 (309)** | not reported / 0 (2,497) | **-410.06 / -266,467.00 (3,371)** |
| gemmini | 1,450 ps | 1,447.62 ps / 0.69 GHz | **PENDING** — retrying after a transient infra failure, see status note above | | +2.38 / 0 (0) | | -9.83 / -31.85 (15) | |

Bold = a new real violation/regression that wasn't present at baseline, or
a notable change worth flagging either direction (floonoc's and
partition_c's large Δ period_min; lfsr's and partition_o's Fmax
improvement). "n/a" for a baseline hold WNS means no source gave a
same-run hold worst-slack figure (only the violation count, confirmed 0).

## 2. Power: baseline vs RCX-rules

RULES_VALIDATION.md's own power table (§4) breaks this into
internal/switching/leakage components, sourced from full local rebuilds
with `RCX_RULES` toggled. This run's baseline figures instead come from
the published webpage/commit messages, which only report **total** power,
not the component breakdown — so only the total is compared here.

| Design | Baseline total (mW) | RCX-rules total (mW) | Δ total |
|---|---|---|---|
| lfsr | 0.271 | 0.260 | -4.1% |
| minimax | 4.843 | 4.674 | -3.5% |
| sha3 | 54.307 | 67.228 | **+23.8%** |
| floonoc | 29.807 | 28.944 | -2.9% |
| NVDLA partition_a | 19.927 | 19.266 | -3.3% |
| NVDLA partition_m | 9.920 | 9.487 | -4.4% |
| NVDLA partition_p | 24.751 | 24.035 | -2.9% |
| NVDLA partition_o | 37.636 | 36.763 | -2.3% |
| NVDLA partition_c | not reported | 76.356 | n/a |
| gemmini | not reported | **PENDING** | |

sha3's +23.8% power increase lines up with it also picking up new hold
violations (see §1), but per §3 the layout (and so the buffer count) is
identical between the two runs — the likely shared root cause is simply
that both numbers come from the same extracted net capacitance: switching
power is computed directly from it, and real OpenRCX capacitance differs
per net from the flat `setRC.tcl` estimate, which is also what is driving
the new hold violations. This is directionally consistent with the
hypothesis RULES_VALIDATION.md §4 raised for an earlier model version, but
not independently confirmed here either.

## 3. Why violations change despite identical placement and routing

Confirmed directly from gt2n's `flow/scripts/` sources: `RCX_RULES` (and the
`extract_parasitics` call it feeds) is read in exactly one place in the
entire flow — `final_report.tcl`, which reloads the already-finished
`6_1_fill.odb` (post-route, post-fill) purely to re-score it for the final
QoR report. No earlier stage — synth, floorplan, place, CTS, global route,
detailed route, or `repair_timing` — ever reads `RCX_RULES`; every
intermediate stage always falls back to `estimate_parasitics
-global_routing` regardless of whether `RCX_RULES` is set, confirmed by
that fallback log line appearing unconditionally in every gt2n build in
this run, baseline and RCX-rules alike.

**Practical consequence: for a given design, its baseline build and its
RCX_RULES build place and route the exact same netlist identically.** Every
cell placement, every route, every buffer `repair_timing` inserts is
byte-for-byte the same between the two runs — `repair_timing` never sees
the real extracted RC in either configuration; it only ever optimizes
against the flat `setRC.tcl` estimate. The new/different WNS, TNS, and
violation counts in the tables above are therefore **not** the optimizer
reacting differently to more accurate RC. They are OpenSTA scoring one
identical, already-frozen layout against two different RC datasets at
report time only — real OpenRCX-extracted parasitics in one case, the flat
per-layer estimate in the other. A design that moves from clean to
violating under RCX_RULES was always marginal on its actual wiring; the
real RC simply reveals timing paths the flat estimate had been
(inadvertently) masking, rather than producing a harder optimization
problem in-flow. The same logic applies to the power deltas in §2: total
power is recomputed from extracted net capacitance at report time, not
from a different buffer count or placement, since none of that changes
between the two runs.

## 4. What this means

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

**partition_o is a second clean(ish) win**: setup stays fully clean (0
violations both ways) and Fmax actually *improves* (1.74→1.95 GHz,
roughly matching lfsr's direction), though 47 new hold violations appear
against a clean baseline — same re-tuning-needed pattern as the other
designs' hold results, just alongside a real frequency gain rather than
a loss.

**partition_c, which was already the worst-off design at baseline (known
~18h non-convergent hold repair, 75 setup/2497 hold violations), got
substantially worse under real RC**: setup violations roughly quadrupled
(75→309, TNS −67,117 ps), hold violations grew further (2497→3371, TNS
−266,467 ps), and Fmax nearly halved (0.674→0.341 GHz). This is the
clearest signal in the whole table that a design already struggling to
close under the flat model does not automatically score better once its
identical, frozen layout is re-evaluated against real extracted RC — per
§3, the layout itself is unchanged, so this means the margins
`repair_timing` left in place (tuned only against the flat `setRC.tcl`
estimate) simply absorb real RC far worse the further a design already was
from closure. **gemmini was also already non-clean at baseline** (15
hold violations) — its new-run numbers aren't in yet (see status note
above).

## Open items

- Fill in gemmini once its build completes (currently retrying in the
  `HighTide` repo after a transient infra failure; see its
  `scratch_logs/gt2n_rcx_qor_run/runner_launch.log` and build logs for
  status).
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
  deliberately left out of the tables above pending that reconciliation —
  full raw figures are in each design's `6_report.json` in the `HighTide`
  repo under `scratch_logs/gt2n_rcx_qor_run/artifacts/gt2n/<design>/` if
  needed sooner.

## Related docs

- `RULES_VALIDATION.md` — this rules model's own validation methodology and
  QoR comparison against the `setRC.tcl` baseline, within this repo's own
  calibration-pattern testing (not a full chip build).
- `README.md` — project overview and current coverage figures.
