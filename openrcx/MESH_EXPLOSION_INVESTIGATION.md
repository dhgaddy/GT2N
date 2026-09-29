# A third FasterCap failure mode: runaway panel-mesh refinement on `Under3`/`Under5`

Working investigation log, same convention as `UNDERDIAG_CRASH_INVESTIGATION.md`
and `TIMING_REGRESSION_INVESTIGATION.md`. This is a genuinely distinct failure
mode from both of those — not the `SIGTRAP`/`wxASSERT` crash
(`UNDERDIAG_CRASH_INVESTIGATION.md`, `FASTERCAP_BUG_REPORT.md`), and not the
bounded-memory oscillating-residual case found on `M14oM13uM15`
(`TIMING_REGRESSION_INVESTIGATION.md`'s round 5). Found during the 214-pattern
non-crash-family rescue probe (`convnc`, `-pB128 -d0.1 -s0.03 -a0.02`, 40
shards, 2026-09).

## The symptom

18 of 214 patterns in the `convnc` probe (17 `SKIPPED|...|stage=timeout`, 1
`PREEMPTED` at the 85%-of-pod-memory-limit guard) never converged and never
crashed — they simply ran until the wall clock (`TIME_LIMIT_SEC=3600`) or the
memory guard stopped them:

| family | count |
|---|---|
| `Under5` | 9 |
| `Under3` | 5 |
| `OverUnder3` | 3 |
| `OverUnder5` | 1 |

14/18 (78%) are `Under3`/`Under5` — reference conductor with a coupling
neighbor *below only*, no conductor above (same family shape that also
dominates the confirmed crash bug, though the two failure modes are otherwise
unrelated — see "Relationship to the crash bug" below). Elapsed time clusters
tightly at 3603-3616s (i.e., exactly the timeout, plus a few seconds of
teardown) — these are not slow-but-progressing runs cut off arbitrarily early,
they are stuck. Round counts are similarly clustered and low (8-12) despite
the long wall-clock time. Peak memory varies enormously but is often massive:
from ~16GB up to **110GB** (against a 128GB pod limit) — several of these are
exactly what triggered the ephemeral-storage-eviction incidents earlier in
this probe (see `TIMING_REGRESSION_INVESTIGATION.md`'s `convnc` section).

## Root cause: confirmed via direct `wires.log` inspection

Pulled the per-pattern `wires.log` (saved by `save_detail()` for every
pattern regardless of outcome) for two of the 18 timeouts and grepped every
`Number of panels after refinement` and `Weighted Frobenius norm...` line —
the same live-inspection method used to characterize the `M14oM13uM15`
oscillation in `TIMING_REGRESSION_INVESTIGATION.md`.

**`Under3/M2uM4/W0.056_W0.056/S0.084_S0.084_L10`** (backside, from an earlier
`shard5` attempt on this same pattern before the taskfile was trimmed to
exclude it on retry):

```
panels:     3130 → 3707 → 4780 → 5733 → 6776 → 9815 → 13136 → 17028 → 25365 → 34191 → 52099 → 68068 → 115916
Frobenius:      -  0.876   0.184   0.114   0.155  0.037   0.051   0.048   0.105   0.114   0.060   0.045   0.040
```

**`Under5/M4uM5/W0.36_W0.36/S1.08_S1.08_L10`** (backside, the actual
convnc-probe timeout, 110GB peak):

```
panels:     3546 → 4121 → 4985 → 6228 → 7083 → 9922 → 12596 → 17098 → 25093 → 32076 → 51723 → 68288 → 122198 → 216113
Frobenius:      -  0.834   0.125   0.104  0.074  0.060   0.031   0.030   0.084   0.068   0.031   0.081   0.120
```

Both show the same signature: **panel count grows exponentially every round
(roughly 1.3-1.6x compounding, 61-90x total over 12-13 rounds) while the
Frobenius-norm convergence criterion never settles below the `-a0.02`
target** — it drops promisingly for a few rounds (0.83 → 0.03-0.06) then
*bounces back up* (0.12, 0.08) rather than continuing to decrease. This is
not "slow but monotonic progress that more time would finish" — it's the
auto-refiner interpreting "residual still above target" as "subdivide more
panels," round after round, without the finer mesh actually buying it a
lower residual. Memory and per-round runtime scale with panel count, so this
compounds into the huge peak-memory figures (16-110GB) and the ever-longer
per-round times that eventually exhaust the 3600s budget.

**This is mechanically distinct from both other known failure modes:**

- **Not** the `UnderDiag` crash bug: no `NaN`/`Inf`/`>1E20` divergence, no
  `wxASSERT`, no `SIGTRAP`. The computed values stay numerically sane
  throughout (the Frobenius norm itself is a small, well-behaved float the
  whole time) — the problem is the refinement never terminates, not that a
  computation blew up.
- **Not** the bounded `M14oM13uM15`-style oscillation: that case (round 5-6 of
  `TIMING_REGRESSION_INVESTIGATION.md`) showed the Frobenius norm bouncing in
  the same 0.45-0.7 range for many rounds with the round count "nearly
  frozen" — i.e., the *mesh* wasn't running away, the *solve* just wasn't
  converging at a fixed problem size, and the memory growth from that case
  was comparatively modest ("multi-GB", not tens-to-hundreds of GB). Here the
  panel count itself is the runaway quantity — a genuinely different
  mechanism (uncontrolled adaptive mesh growth) rather than a stuck linear
  solve.

## Relationship to the crash bug

`Under3`/`Under5` also appear in the confirmed crash population (16 `Under5`
instances noted in `UNDERDIAG_CRASH_INVESTIGATION.md`'s original tally, plus
4 more `Under5` and 1 stray `Over5` seen fresh in this same `convnc` probe —
see the crash-tally update below). That's the *same family shape*
(reference-with-neighbor-below-only) producing *two different* failure
modes depending on the specific geometry/config: sometimes the potential
estimate diverges to `NaN`/`Inf` and crashes fast (15-90s), other times the
adaptive mesh refinement itself runs away without ever diverging numerically.
Both point at the same underlying suspect — something about how `CAutoRefine`
handles this conductor arrangement's mesh/potential estimation — but they are
different code paths misbehaving in different ways, not the same bug
surfacing twice. Worth keeping in mind if anyone eventually instruments
`CAutoRefine`'s refinement-decision logic (the open item from
`FASTERCAP_BUG_REPORT.md`): a fix for the crash divergence would not
necessarily fix this mesh-explosion behavior, and vice versa.

## What was tried: a much looser `-a` target

Both sampled patterns show the Frobenius norm oscillating in the 0.03-0.15
range against a `-a0.02` target — i.e., the achieved residual is only
2-8x looser than the target, and it briefly touches within ~1.5x of it
(0.030-0.031) before bouncing back up. That's suspiciously close to "this
would actually converge if the target were merely undemanding rather than
essentially unreachable," in contrast to the `M14oM13uM15` case where the
residual sat 20-30x above a much tighter target.

Launched a follow-up probe: all 18 timeout/preempted patterns, single
pattern per pod (18 pods, no sharding — small enough that per-pattern
isolation avoids any repeat of the shared-shard storage-eviction risk from
the main `convnc` probe), same base flags, `-a0.1` (5x looser than the
original `-a0.02`) in place of `-a0.02`. `TIME_LIMIT_SEC=3600` unchanged, in
case the hypothesis was wrong and these still didn't settle even with a
loose target.

**Result: confirmed, decisively.** All 18/18 resolved cleanly — **zero
timeouts, zero crashes, zero memory-guard preemptions.** Every pattern
finished in 5-55 seconds (vs. hitting the full 3600s budget every time
before), with peak memory in the tens-to-hundreds of MB (vs. 15-110GB
before) — roughly a 1000x reduction. 5/18 (28%) landed `CONVERGED_SANE`,
staged in `../scratch_logs/v2_flag_completed_patterns_convprobe_rescue_v8.tsv`;
the other 13 landed a conclusive `CONVERGED_INSANE`, a real result. One pod
(`shard8`) separately hit an unrelated 30-minute `apt-get` hang inside the
job's setup step — a genuine cluster/mirror infra issue, resolved by
deleting and recreating that one job; nothing to do with FasterCap or this
failure mode.

## Practical implication: confirmed fixable by config alone

Unlike the `UnderDiag` crash bug, **this failure mode does not need an
upstream FasterCap fix** — it's a target-tightness problem, not a geometry
problem. `-a0.02` is simply too aggressive for this population of
`Under3`/`Under5` (and a few `OverUnder`) patterns: their residual plateaus
somewhere in the 0.03-0.15 range, and pushing below that with a
hierarchical adaptive solver just triggers unbounded mesh subdivision
rather than genuine refinement. A looser target (`-a0.1` here, though the
true boundary between "converges cleanly" and "runs away" wasn't bisected —
0.1 was chosen because it was safely above the observed plateau, not
because it's the tightest value that works) lets the same solver settle in
a handful of rounds.

**Practical guidance for future probes**: when a pattern population's
residual is observed to plateau well above a given `-a` target (rather
than diverging to `NaN`/`Inf`, and rather than oscillating at a roughly
*constant* mesh size the way `M14oM13uM15` did), suspect mesh-refinement
runaway before assuming it's unconvergeable or crash-prone — check panel
count growth across rounds directly in `wires.log`, and if it's compounding
without bound, try a target closer to the observed plateau rather than the
project's globally-best-performing tight config.
