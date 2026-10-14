# Fully-blacked-out calibration patterns

Companion list to `TIMING_REGRESSION_INVESTIGATION.md`. These are the
individual patterns behind the 102 `(stack, family, layer-pair)`
combinations where **every** spacing point in that combination's sweep
failed to converge (0 real measurements — see the investigation doc's
"Rules-file gap structure" section for how these were found and what
the extraction flow does with them: silently contributes zero
capacitance for that specific coupling term, not a crash, not an
interpolation for the specific families/pairs at the edges of this
population (see below) — **but note the diag families specifically**
(`UnderDiag3`/`UnderDiag5`, the only families with groups still 100%
blacked out as of this writing): every `OpenRCX` family pools its wc3
(3-wire) and wc5 (5-wire) measurements into one shared table with no
way to tell them apart (confirmed even on fully-converged pairs), but
diag additionally pools the isolated (wc1) and one-side-open (wc2)
patterns into that *same* table — the other families keep those two
in their own dedicated tables. So a blacked-out wc3/wc5 diag pair
doesn't fall through to a silent zero like the other families would;
it silently gets served the surviving isolated-pattern's value
instead — a much larger context gap (zero neighbors vs. dense-packed)
than the wc3/wc5 mixing every family has. These 14 groups are the
total-loss extreme of that diag-specific gap, not a separate
mechanism — see the investigation doc's "What the flow falls back to"
section for the source-verified mechanism and worked examples from
both a blacked and a converged pair).

468 patterns total across 102 groups. Format per line:
`stack<TAB>wc<TAB>pattern` (exact fields from
`insane_converged_patterns_queue.tsv` / `_RDL.tsv`), grouped under a
`### stack family layer-pair` header. Recovering even a single point
per group would give that group its first real anchor instead of zero.

**Final update (convprobe rounds 1-11, through round 11's combined
preconditioner+mesh-tightening/safe-loose-`-a` probe — see
`TIMING_REGRESSION_INVESTIGATION.md`'s "Convergence-probe results"
section): 390 of 468 patterns rescued — 64 of 102 groups now fully
converged, 24 partially (at least one real anchor), 14 still 100%
blacked out.** Rescued lines are marked `**SANE (convprobe)**`
(rounds 1-6, tight `-a` targets), `**SANE (convnc)**` (round 7's
214-pattern probe), `**SANE (convprecond)**` (round 10's preconditioner
probe), or `**SANE (convprecond2)**` (round 11) below; group headers
show each group's current rescued/missing split. `v1`-`v11` are
merged into the real rules model as of commit `b6326acc`; `v12`
(round 9), `v13` (round 10), and `v14` (round 11) are staged but not
yet merged. This doc's own `**SANE (...)**` markers were set by
directly checking each rescued row against this doc's 468-pattern
list, not assumed:
`../scratch_logs/v2_flag_completed_patterns_convprobe_rescue{,_v2,_v3,_v4,_v5,_v6,_v7,_v8,_v9,_v10,_v11,_v12,_v13,_v14}.tsv`
(`_v7` is the `convnc` batch, 66 rows, 22 of which land in groups
tracked by *this* doc; `_v8`-`_v12` are rounds 8-9, 0 of which land
here — this doc only lists groups where *every* spacing failed, and
that population came from groups that already had at least one real
anchor before the 468-pattern blackout set was drawn up; `_v13` is
round 10, 10 rows, 2 of which land here; `_v14` is round 11, 7 rows, 1
of which lands here — see below). See
`TIMING_REGRESSION_INVESTIGATION.md`'s "Current state, all families,
project-wide" section for the up-to-date, full-project tally.

**Round 4 gave 4 timeout-only groups an unlimited per-pattern time
budget (900s → ~1 year) instead of a fixed longer retry.** 3 of 4
groups just needed more wall-clock, rescuing 2/5 of `frontside
OverUnder5 M7oM6uM8` (19-31 min) and 4/5 of `frontside Under5 M5uM6`
(19-53 min) *at the time* — `M7oM6uM8` has since picked up a 3rd point
via round 7's `convnc` probe (now 3/5; see its group listing below for
the current split). `backside OverUnder5 M4oM3uM5` reached a genuine
conclusive INSANE verdict on every point instead — a real result, not
a timeout artifact, at the time (round 10 later rescued 2 of its 5
spacings, see below). `frontside OverUnder5 M14oM13uM15` diverged
under unlimited time on both tight-`-a` configs (GMRES stuck
oscillating, half the attempts eventually memory-killed) — round 4
read this as a likely dead end.

**Rounds 5-6 proved that reading wrong.** Cross-checking round 1's
original 30-config data for this exact pattern showed the *other* 22
configs (no aggressive `-a` override) converged in ~5s and landed
within 0.0002-0.002 of sane at the wide spacings — real evidence the
tight-`-a` target itself, not the pattern, was destabilizing. A
targeted probe (medium `-a` 0.005-0.1 on `stack_pb128_d01_s003`'s base
flags, no `-ap`) found a genuine stability boundary: `a≥0.02` converges
cleanly in seconds, `a≤0.015` reproduces the same divergence. That
rescued 4 of 5 spacings immediately. The 5th (S1.8) needed one more
round varying mesh-shaping independent of `-a`: `-s` had zero effect,
but tightening `-d` from 0.1→0.05→0.02 closed the gap (0.01 was too
tight again — another non-monotonic boundary). **All 5 spacings of
`M14oM13uM15` are now rescued** — see
`../scratch_logs/v2_flag_completed_patterns_convprobe_rescue_v5.README.md`
for the full methodology and per-spacing winning configs.

**14 groups now remain fully blacked out, all `UnderDiag3`/`UnderDiag5`**
(8 + 6, all frontside, concentrated on M5/M7 as the primary metal) —
blocked by the confirmed FasterCap hierarchical-multipole-solver crash
(real bug, `rc=133` SIGTRAP, see `UNDERDIAG_CRASH_INVESTIGATION.md`
for the discovery narrative or `FASTERCAP_BUG_REPORT.md` for a
fix-oriented writeup with a verified standalone reproduction), not a
time or tuning problem. No further probing of these 14 is worthwhile
until that bug is fixed or worked around upstream.

**`backside OverUnder5 M4oM3uM5` — the one non-`UnderDiag` group that
used to be the "15th" fully-blacked-out group — is now partially
resolved.** It resisted round 1's original 30 configs and round 9's 4
mesh-shaping variants entirely, but round 10's preconditioner probe
(the first in this whole effort to vary preconditioner choice away
from the fixed `-pB128` used everywhere else) rescued 2 of its 5
spacings: `S0.36` (unanimous across all 3 preconditioners tried —
`-pJ`, `-pS128`, `-pS512`) and `S0.54` (`-pJ`/`-pS512` only). The other
3 spacings (`S0.72`, `S1.08`, `S1.8`) remain `CONVERGED_INSANE` under
every preconditioner tried — a clean spacing-dependent boundary, not a
preconditioner-dependent one. See its group listing below for the
current split, and `TIMING_REGRESSION_INVESTIGATION.md`'s round 10
section for the full writeup.

**The `convnc` probe also surfaced a third, previously-uncharacterized
FasterCap failure mode** — 18 of its 214 patterns (mostly `Under3`/
`Under5`) never converged and never crashed; they ran away in panel
count (exponential mesh growth every round, 60-90x over 12 rounds)
while the residual oscillated without settling, exhausting the
3600s/128GB budget instead. Mechanically distinct from both the
`UnderDiag` crash bug and the bounded `M14oM13uM15`-style oscillation.
**Unlike the crash bug, this one is fixable by config alone** — a
follow-up probe with a much looser `-a0.1` target resolved all 18/18
cleanly (zero timeouts, ~1000x less peak memory, 5/18 newly `SANE`).
None of the 5 newly-rescued patterns happen to fall in a group tracked
by this doc (see `../scratch_logs/v2_flag_completed_patterns_convprobe_rescue_v8.tsv`
for those 5). See `MESH_EXPLOSION_INVESTIGATION.md` for the full
writeup.

**A fourth phenomenon, this one pure config-tuning rather than a
distinct failure mode**: of the 214 `convnc`-probe patterns, 138
landed a conclusive `CONVERGED_INSANE` (a real, clean stop — small
negative coupling terms, not a crash or timeout). Round 8's three
sub-rounds worked through all 138: the 20 closest-to-sane at tighter
`-a0.01`/`-a0.005` (11/20 rescued, `v9.tsv`), the resulting 9
`-a`-resistant holdouts at mesh-shaping configs (7/9 rescued via
`-d0.02`, `v10.tsv`), and the remaining 118 never-before-reprobed
patterns at the same tighter-`-a` sweep (43/118 rescued, `v11.tsv`).
**Round 8 total: 61/138 rescued (44%), 74 remained non-`SANE` and
unrelated to the crash bug.** Round 9 scaled `convtight2`'s
mesh-shaping fix (`-d`/`-s` variants) to the 63 of those 74 that had
never been tried with anything but `-a` — 40 more rescued (63.5%), 34
remaining. Round 10 tried the first preconditioner-dimension probe
(`-pJ`/`-pS128`/`-pS512` in place of the `-pB128` fixed everywhere
else) on all 34 — 10 more rescued (29%), 34 patterns became 24
remaining. **Round 11 then combined the two proven levers** —
preconditioner swap with `-d0.02` mesh-tightening on the 18 clean-
`CONVERGED_INSANE` patterns, and preconditioner swap with the
proven-safe loose `-a0.1` on the 6 mesh-explosion-timeout-prone
patterns — **7 more rescued (29%), 17 patterns now remain non-`SANE`
and unrelated to the crash bug** (verified directly against the master
tracker files each time — see `TIMING_REGRESSION_INVESTIGATION.md`'s
"Current state" table). 2 of round 10's rescues and 1 of round 11's
land in this doc's tracked set (the `M4oM3uM5`/`M5oM4uM6` spacings
above); none of rounds 8-9's did. Round 11's initial 36-pod launch was
fully wasted by a taskfile-generation bug (a double-prefixed `wc`
field broke geometry conversion for every pattern) — caught, fixed,
and relaunched cleanly; see `v14.README.md` for the full account. Real
caveats surfaced across rounds 8-11: tightening `-a` below the original
`0.02` reproduces round 7's mesh-explosion timeout in most of the
`Under`-family patterns a looser `-a0.1` had already fixed (round 8);
round 9 found `-d` tightening alone can trigger the same failure mode;
round 10 found that failure mode is preconditioner-independent for at
least one pattern (`Under5/M2uM4/S0.112` timed out identically under
`-pJ`) even though 5 of the 11 previously-timeout patterns did get
rescued by a different preconditioner; and round 11 found that
combining preconditioner swap with the safe loose `-a0.1` rescued 4 of
the remaining 6 timeout-prone patterns, including that same
`Under5/M2uM4/S0.112` — see `TIMING_REGRESSION_INVESTIGATION.md`'s
round 8-11 sections and `MESH_EXPLOSION_INVESTIGATION.md` for the full
writeups.


### backside Over3 M2oM1 (5 patterns, ALL RESCUED)

- `backside	wc3	Over3/M2oM1/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `backside	wc3	Over3/M2oM1/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `backside	wc3	Over3/M2oM1/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convnc)**
- `backside	wc3	Over3/M2oM1/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `backside	wc3	Over3/M2oM1/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### backside Over5 M2oM1 (5 patterns, ALL RESCUED)

- `backside	wc5	Over5/M2oM1/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `backside	wc5	Over5/M2oM1/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `backside	wc5	Over5/M2oM1/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `backside	wc5	Over5/M2oM1/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `backside	wc5	Over5/M2oM1/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### backside OverUnder5 M2oM1uM3 (5 patterns, 4 rescued, 1 still missing)

- `backside	wc5	OverUnder5/M2oM1uM3/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `backside	wc5	OverUnder5/M2oM1uM3/W0.056_W0.056/S0.084_S0.084_L10`
- `backside	wc5	OverUnder5/M2oM1uM3/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `backside	wc5	OverUnder5/M2oM1uM3/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `backside	wc5	OverUnder5/M2oM1uM3/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### backside OverUnder5 M2oM1uM6 (5 patterns, 4 rescued, 1 still missing)

- `backside	wc5	OverUnder5/M2oM1uM6/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `backside	wc5	OverUnder5/M2oM1uM6/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `backside	wc5	OverUnder5/M2oM1uM6/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convnc)**
- `backside	wc5	OverUnder5/M2oM1uM6/W0.056_W0.056/S0.168_S0.168_L10`
- `backside	wc5	OverUnder5/M2oM1uM6/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### backside OverUnder5 M4oM3uM5 (5 patterns, 2 rescued, 3 still missing)

- `backside	wc5	OverUnder5/M4oM3uM5/W0.36_W0.36/S0.36_S0.36_L10`  **SANE (convprecond)**
- `backside	wc5	OverUnder5/M4oM3uM5/W0.36_W0.36/S0.54_S0.54_L10`  **SANE (convprecond)**
- `backside	wc5	OverUnder5/M4oM3uM5/W0.36_W0.36/S0.72_S0.72_L10`
- `backside	wc5	OverUnder5/M4oM3uM5/W0.36_W0.36/S1.08_S1.08_L10`
- `backside	wc5	OverUnder5/M4oM3uM5/W0.36_W0.36/S1.8_S1.8_L10`

### frontside Over3 M11oM10 (5 patterns, ALL RESCUED)

- `frontside	wc3	Over3/M11oM10/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM10/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM10/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM10/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM10/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside Over3 M11oM8 (5 patterns, ALL RESCUED)

- `frontside	wc3	Over3/M11oM8/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM8/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM8/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM8/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM8/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convnc)**

### frontside Over3 M11oM9 (5 patterns, ALL RESCUED)

- `frontside	wc3	Over3/M11oM9/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM9/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM9/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM9/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M11oM9/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside Over3 M12oM10 (5 patterns, ALL RESCUED)

- `frontside	wc3	Over3/M12oM10/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM10/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM10/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM10/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM10/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convnc)**

### frontside Over3 M12oM11 (5 patterns, ALL RESCUED)

- `frontside	wc3	Over3/M12oM11/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM11/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM11/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM11/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM11/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside Over3 M12oM8 (5 patterns, ALL RESCUED)

- `frontside	wc3	Over3/M12oM8/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM8/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM8/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM8/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM8/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convnc)**

### frontside Over3 M12oM9 (5 patterns, ALL RESCUED)

- `frontside	wc3	Over3/M12oM9/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM9/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM9/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM9/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M12oM9/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convnc)**

### frontside Over3 M5oM0 (5 patterns, ALL RESCUED)

- `frontside	wc3	Over3/M5oM0/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM0/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM0/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM0/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM0/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside Over3 M5oM1 (5 patterns, ALL RESCUED)

- `frontside	wc3	Over3/M5oM1/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM1/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM1/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM1/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM1/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside Over3 M5oM2 (5 patterns, ALL RESCUED)

- `frontside	wc3	Over3/M5oM2/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM2/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM2/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM2/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM2/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside Over3 M5oM3 (5 patterns, ALL RESCUED)

- `frontside	wc3	Over3/M5oM3/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM3/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM3/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM3/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM3/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convnc)**

### frontside Over3 M5oM4 (5 patterns, ALL RESCUED)

- `frontside	wc3	Over3/M5oM4/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM4/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM4/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM4/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M5oM4/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside Over3 M7oM0 (5 patterns, ALL RESCUED)

- `frontside	wc3	Over3/M7oM0/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM0/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM0/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convnc)**
- `frontside	wc3	Over3/M7oM0/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM0/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside Over3 M7oM3 (5 patterns, ALL RESCUED)

- `frontside	wc3	Over3/M7oM3/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM3/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM3/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM3/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM3/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside Over3 M7oM4 (5 patterns, ALL RESCUED)

- `frontside	wc3	Over3/M7oM4/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM4/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM4/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM4/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM4/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside Over3 M7oM6 (5 patterns, ALL RESCUED)

- `frontside	wc3	Over3/M7oM6/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM6/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM6/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM6/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc3	Over3/M7oM6/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside Over5 M11oM10 (5 patterns, ALL RESCUED)

- `frontside	wc5	Over5/M11oM10/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM10/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM10/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM10/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM10/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside Over5 M11oM8 (5 patterns, ALL RESCUED)

- `frontside	wc5	Over5/M11oM8/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM8/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM8/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM8/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM8/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside Over5 M11oM9 (5 patterns, ALL RESCUED)

- `frontside	wc5	Over5/M11oM9/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM9/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM9/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM9/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M11oM9/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside Over5 M12oM10 (5 patterns, ALL RESCUED)

- `frontside	wc5	Over5/M12oM10/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM10/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM10/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM10/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM10/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside Over5 M12oM8 (5 patterns, ALL RESCUED)

- `frontside	wc5	Over5/M12oM8/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM8/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM8/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM8/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM8/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside Over5 M12oM9 (5 patterns, ALL RESCUED)

- `frontside	wc5	Over5/M12oM9/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM9/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM9/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM9/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M12oM9/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside Over5 M5oM0 (5 patterns, ALL RESCUED)

- `frontside	wc5	Over5/M5oM0/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM0/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM0/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM0/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM0/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside Over5 M5oM1 (5 patterns, ALL RESCUED)

- `frontside	wc5	Over5/M5oM1/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM1/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM1/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM1/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM1/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside Over5 M5oM2 (5 patterns, ALL RESCUED)

- `frontside	wc5	Over5/M5oM2/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM2/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM2/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM2/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM2/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside Over5 M5oM4 (5 patterns, ALL RESCUED)

- `frontside	wc5	Over5/M5oM4/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM4/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM4/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM4/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M5oM4/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside Over5 M7oM0 (5 patterns, ALL RESCUED)

- `frontside	wc5	Over5/M7oM0/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM0/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM0/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM0/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM0/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside Over5 M7oM3 (5 patterns, ALL RESCUED)

- `frontside	wc5	Over5/M7oM3/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM3/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM3/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM3/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM3/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside Over5 M7oM4 (5 patterns, ALL RESCUED)

- `frontside	wc5	Over5/M7oM4/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM4/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM4/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM4/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	Over5/M7oM4/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM10uM12 (5 patterns, 2 rescued, 3 still missing)

- `frontside	wc5	OverUnder5/M11oM10uM12/W0.056_W0.056/S0.056_S0.056_L10`
- `frontside	wc5	OverUnder5/M11oM10uM12/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM10uM12/W0.056_W0.056/S0.112_S0.112_L10`
- `frontside	wc5	OverUnder5/M11oM10uM12/W0.056_W0.056/S0.168_S0.168_L10`
- `frontside	wc5	OverUnder5/M11oM10uM12/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM10uM13 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M11oM10uM13/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM10uM13/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM10uM13/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM10uM13/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM10uM13/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM10uM14 (5 patterns, 4 rescued, 1 still missing)

- `frontside	wc5	OverUnder5/M11oM10uM14/W0.056_W0.056/S0.056_S0.056_L10`
- `frontside	wc5	OverUnder5/M11oM10uM14/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM10uM14/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM10uM14/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM10uM14/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM7uM12 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M11oM7uM12/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM12/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM12/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM12/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM12/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM7uM13 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M11oM7uM13/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM13/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM13/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM13/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM13/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM7uM14 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M11oM7uM14/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM14/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM14/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM14/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM7uM14/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM8uM12 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M11oM8uM12/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM12/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM12/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM12/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM12/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM8uM13 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M11oM8uM13/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM13/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM13/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM13/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM13/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM8uM14 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M11oM8uM14/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM14/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM14/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM14/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM8uM14/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM9uM13 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M11oM9uM13/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM13/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM13/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM13/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM13/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM9uM14 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M11oM9uM14/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM14/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM14/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM14/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM14/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M11oM9uM15 (5 patterns, 4 rescued, 1 still missing)

- `frontside	wc5	OverUnder5/M11oM9uM15/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM15/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M11oM9uM15/W0.056_W0.056/S0.112_S0.112_L10`
- `frontside	wc5	OverUnder5/M11oM9uM15/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convnc)**
- `frontside	wc5	OverUnder5/M11oM9uM15/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM10uM13 (5 patterns, 4 rescued, 1 still missing)

- `frontside	wc5	OverUnder5/M12oM10uM13/W0.056_W0.056/S0.056_S0.056_L10`
- `frontside	wc5	OverUnder5/M12oM10uM13/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM13/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM13/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM13/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM10uM14 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M12oM10uM14/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM14/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM14/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM14/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM14/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM10uM15 (5 patterns, 4 rescued, 1 still missing)

- `frontside	wc5	OverUnder5/M12oM10uM15/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM15/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM15/W0.056_W0.056/S0.112_S0.112_L10`
- `frontside	wc5	OverUnder5/M12oM10uM15/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM10uM15/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM11uM13 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M12oM11uM13/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM11uM13/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM11uM13/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM11uM13/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM11uM13/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM11uM15 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M12oM11uM15/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM11uM15/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM11uM15/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM11uM15/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM11uM15/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM8uM13 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M12oM8uM13/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM8uM13/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM8uM13/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM8uM13/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM8uM13/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM8uM14 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M12oM8uM14/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM8uM14/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM8uM14/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM8uM14/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM8uM14/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM9uM13 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M12oM9uM13/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM13/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM13/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM13/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM13/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM9uM14 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M12oM9uM14/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM14/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM14/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM14/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM14/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M12oM9uM15 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M12oM9uM15/W0.056_W0.056/S0.056_S0.056_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM15/W0.056_W0.056/S0.084_S0.084_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM15/W0.056_W0.056/S0.112_S0.112_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM15/W0.056_W0.056/S0.168_S0.168_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M12oM9uM15/W0.056_W0.056/S0.28_S0.28_L10`  **SANE (convprobe)**

### frontside OverUnder5 M14oM13uM15 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M14oM13uM15/W0.36_W0.36/S0.36_S0.36_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M14oM13uM15/W0.36_W0.36/S0.54_S0.54_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M14oM13uM15/W0.36_W0.36/S0.72_S0.72_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M14oM13uM15/W0.36_W0.36/S1.08_S1.08_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M14oM13uM15/W0.36_W0.36/S1.8_S1.8_L10`  **SANE (convprobe)**

### frontside OverUnder5 M5oM1uM7 (5 patterns, 4 rescued, 1 still missing)

- `frontside	wc5	OverUnder5/M5oM1uM7/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM1uM7/W0.021_W0.021/S0.0315_S0.0315_L10`
- `frontside	wc5	OverUnder5/M5oM1uM7/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM1uM7/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM1uM7/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside OverUnder5 M5oM1uM8 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M5oM1uM8/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convnc)**
- `frontside	wc5	OverUnder5/M5oM1uM8/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM1uM8/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM1uM8/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM1uM8/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside OverUnder5 M5oM1uM9 (5 patterns, 4 rescued, 1 still missing)

- `frontside	wc5	OverUnder5/M5oM1uM9/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM1uM9/W0.021_W0.021/S0.0315_S0.0315_L10`
- `frontside	wc5	OverUnder5/M5oM1uM9/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM1uM9/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM1uM9/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside OverUnder5 M5oM2uM7 (5 patterns, 4 rescued, 1 still missing)

- `frontside	wc5	OverUnder5/M5oM2uM7/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM2uM7/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM2uM7/W0.021_W0.021/S0.042_S0.042_L10`
- `frontside	wc5	OverUnder5/M5oM2uM7/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM2uM7/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside OverUnder5 M5oM2uM8 (5 patterns, 4 rescued, 1 still missing)

- `frontside	wc5	OverUnder5/M5oM2uM8/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM2uM8/W0.021_W0.021/S0.0315_S0.0315_L10`
- `frontside	wc5	OverUnder5/M5oM2uM8/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM2uM8/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM2uM8/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside OverUnder5 M5oM2uM9 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M5oM2uM9/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convnc)**
- `frontside	wc5	OverUnder5/M5oM2uM9/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM2uM9/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM2uM9/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM2uM9/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside OverUnder5 M5oM3uM6 (5 patterns, 1 rescued, 4 still missing)

- `frontside	wc5	OverUnder5/M5oM3uM6/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM3uM6/W0.021_W0.021/S0.0315_S0.0315_L10`
- `frontside	wc5	OverUnder5/M5oM3uM6/W0.021_W0.021/S0.042_S0.042_L10`
- `frontside	wc5	OverUnder5/M5oM3uM6/W0.021_W0.021/S0.063_S0.063_L10`
- `frontside	wc5	OverUnder5/M5oM3uM6/W0.021_W0.021/S0.105_S0.105_L10`

### frontside OverUnder5 M5oM3uM8 (5 patterns, 4 rescued, 1 still missing)

- `frontside	wc5	OverUnder5/M5oM3uM8/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM3uM8/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM3uM8/W0.021_W0.021/S0.042_S0.042_L10`
- `frontside	wc5	OverUnder5/M5oM3uM8/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM3uM8/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside OverUnder5 M5oM4uM6 (5 patterns, 3 rescued, 2 still missing)

- `frontside	wc5	OverUnder5/M5oM4uM6/W0.021_W0.021/S0.021_S0.021_L10`
- `frontside	wc5	OverUnder5/M5oM4uM6/W0.021_W0.021/S0.0315_S0.0315_L10`
- `frontside	wc5	OverUnder5/M5oM4uM6/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convprecond2)**
- `frontside	wc5	OverUnder5/M5oM4uM6/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convnc)**
- `frontside	wc5	OverUnder5/M5oM4uM6/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside OverUnder5 M5oM4uM9 (5 patterns, 2 rescued, 3 still missing)

- `frontside	wc5	OverUnder5/M5oM4uM9/W0.021_W0.021/S0.021_S0.021_L10`
- `frontside	wc5	OverUnder5/M5oM4uM9/W0.021_W0.021/S0.0315_S0.0315_L10`
- `frontside	wc5	OverUnder5/M5oM4uM9/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convnc)**
- `frontside	wc5	OverUnder5/M5oM4uM9/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M5oM4uM9/W0.021_W0.021/S0.105_S0.105_L10`

### frontside OverUnder5 M7oM3uM10 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M7oM3uM10/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM3uM10/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM3uM10/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM3uM10/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM3uM10/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM3uM11 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M7oM3uM11/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM3uM11/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM3uM11/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM3uM11/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM3uM11/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM4uM10 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M7oM4uM10/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM4uM10/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM4uM10/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM4uM10/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM4uM10/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM4uM9 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M7oM4uM9/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM4uM9/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM4uM9/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM4uM9/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM4uM9/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM5uM10 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M7oM5uM10/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM10/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convnc)**
- `frontside	wc5	OverUnder5/M7oM5uM10/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convnc)**
- `frontside	wc5	OverUnder5/M7oM5uM10/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM10/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM5uM11 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M7oM5uM11/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM11/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM11/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM11/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM11/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM5uM8 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M7oM5uM8/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM8/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM8/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM8/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM8/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM5uM9 (5 patterns, ALL RESCUED)

- `frontside	wc5	OverUnder5/M7oM5uM9/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM9/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM9/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM9/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM5uM9/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM6uM10 (5 patterns, 4 rescued, 1 still missing)

- `frontside	wc5	OverUnder5/M7oM6uM10/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM6uM10/W0.038_W0.038/S0.057_S0.057_L10`
- `frontside	wc5	OverUnder5/M7oM6uM10/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM6uM10/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convnc)**
- `frontside	wc5	OverUnder5/M7oM6uM10/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM6uM11 (5 patterns, 4 rescued, 1 still missing)

- `frontside	wc5	OverUnder5/M7oM6uM11/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM6uM11/W0.038_W0.038/S0.057_S0.057_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM6uM11/W0.038_W0.038/S0.076_S0.076_L10`
- `frontside	wc5	OverUnder5/M7oM6uM11/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convnc)**
- `frontside	wc5	OverUnder5/M7oM6uM11/W0.038_W0.038/S0.19_S0.19_L10`  **SANE (convprobe)**

### frontside OverUnder5 M7oM6uM8 (5 patterns, 3 rescued, 2 still missing)

- `frontside	wc5	OverUnder5/M7oM6uM8/W0.038_W0.038/S0.038_S0.038_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM6uM8/W0.038_W0.038/S0.057_S0.057_L10`
- `frontside	wc5	OverUnder5/M7oM6uM8/W0.038_W0.038/S0.076_S0.076_L10`  **SANE (convprobe)**
- `frontside	wc5	OverUnder5/M7oM6uM8/W0.038_W0.038/S0.114_S0.114_L10`  **SANE (convnc)**
- `frontside	wc5	OverUnder5/M7oM6uM8/W0.038_W0.038/S0.19_S0.19_L10`

### frontside Under5 M5uM6 (5 patterns, 4 rescued, 1 still missing)

- `frontside	wc5	Under5/M5uM6/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convprobe)**
- `frontside	wc5	Under5/M5uM6/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	Under5/M5uM6/W0.021_W0.021/S0.042_S0.042_L10`
- `frontside	wc5	Under5/M5uM6/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	Under5/M5uM6/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convprobe)**

### frontside Under5 M5uM7 (5 patterns, 3 rescued, 2 still missing)

- `frontside	wc5	Under5/M5uM7/W0.021_W0.021/S0.021_S0.021_L10`
- `frontside	wc5	Under5/M5uM7/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convprobe)**
- `frontside	wc5	Under5/M5uM7/W0.021_W0.021/S0.042_S0.042_L10`  **SANE (convnc)**
- `frontside	wc5	Under5/M5uM7/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	Under5/M5uM7/W0.021_W0.021/S0.105_S0.105_L10`

### frontside Under5 M5uM9 (5 patterns, 4 rescued, 1 still missing)

- `frontside	wc5	Under5/M5uM9/W0.021_W0.021/S0.021_S0.021_L10`  **SANE (convnc)**
- `frontside	wc5	Under5/M5uM9/W0.021_W0.021/S0.0315_S0.0315_L10`  **SANE (convnc)**
- `frontside	wc5	Under5/M5uM9/W0.021_W0.021/S0.042_S0.042_L10`
- `frontside	wc5	Under5/M5uM9/W0.021_W0.021/S0.063_S0.063_L10`  **SANE (convprobe)**
- `frontside	wc5	Under5/M5uM9/W0.021_W0.021/S0.105_S0.105_L10`  **SANE (convnc)**

### frontside UnderDiag3 M11duM14 (3 patterns, ALL RESCUED)

- `frontside	wc3	UnderDiag3/M11duM14/W0.056_W0.36/S0.056_S1.44_L10`  **SANE (convprobe)**
- `frontside	wc3	UnderDiag3/M11duM14/W0.056_W0.36/S0.084_S1.44_L10`  **SANE (convprobe)**
- `frontside	wc3	UnderDiag3/M11duM14/W0.056_W0.36/S0.112_S1.44_L10`  **SANE (convprobe)**

### frontside UnderDiag3 M11duM15 (3 patterns, ALL RESCUED)

- `frontside	wc3	UnderDiag3/M11duM15/W0.056_W1.6/S0.056_S6.4_L10`  **SANE (convprobe)**
- `frontside	wc3	UnderDiag3/M11duM15/W0.056_W1.6/S0.084_S6.4_L10`  **SANE (convprobe)**
- `frontside	wc3	UnderDiag3/M11duM15/W0.056_W1.6/S0.112_S6.4_L10`  **SANE (convprobe)**

### frontside UnderDiag3 M12duM14 (3 patterns, 2 rescued, 1 still missing)

- `frontside	wc3	UnderDiag3/M12duM14/W0.056_W0.36/S0.056_S1.44_L10`
- `frontside	wc3	UnderDiag3/M12duM14/W0.056_W0.36/S0.084_S1.44_L10`  **SANE (convprobe)**
- `frontside	wc3	UnderDiag3/M12duM14/W0.056_W0.36/S0.112_S0.72_L10`  **SANE (convprobe)**

### frontside UnderDiag3 M12duM15 (3 patterns, ALL RESCUED)

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

### frontside UnderDiag5 M11duM12 (3 patterns, ALL RESCUED)

- `frontside	wc5	UnderDiag5/M11duM12/W0.056_W0.056/S0.056_S0.224_L10`  **SANE (convprobe)**
- `frontside	wc5	UnderDiag5/M11duM12/W0.056_W0.056/S0.084_S0.224_L10`  **SANE (convprobe)**
- `frontside	wc5	UnderDiag5/M11duM12/W0.056_W0.056/S0.112_S0_L10`  **SANE (convprobe)**

### frontside UnderDiag5 M5duM6 (3 patterns, all missing)

- `frontside	wc5	UnderDiag5/M5duM6/W0.021_W0.021/S0.021_S0_L10`
- `frontside	wc5	UnderDiag5/M5duM6/W0.021_W0.021/S0.0315_S0_L10`
- `frontside	wc5	UnderDiag5/M5duM6/W0.021_W0.021/S0.042_S0_L10`

### frontside UnderDiag5 M5duM7 (3 patterns, 2 rescued, 1 still missing)

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

### frontside UnderDiag5 M7duM11 (3 patterns, ALL RESCUED)

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
