# How to generate OpenRCX extraction rules for a new process

This is a how-to for the process used to build `rules/gt2n_combined.rcx.model`
from GT2N's own PDK data (`nxtgrd/GT2.itf`, `qrc/GT2.ict`) via FasterCap-based
field-solver calibration. It documents the files, formats, parameters, and
FasterCap limitations involved, so the same process can be repeated for
another process node. For GT2N-specific validation results (convergence
rates, QoR impact), see `RULES_VALIDATION.md`. For the full experimental
record behind the FasterCap findings summarized here, see
`../scratch_logs/FASTERCAP_FINDINGS.md`.

## Pipeline overview

```
PDK deck (ITF/ICT)
  -> [1] process-stack files (.pro)           gt2n_process_{frontside,backside}.pro
  -> [2] pattern generation (gen_solver_patterns)   per-pattern "wires" geometry
  -> [3] geometry conversion (UniversalFormat2FasterCap)  wires.lst
  -> [4] field solve (FasterCap)               wires.log
  -> [5] result parsing (fasterCapParse)       per-pattern .caps text + tracking TSV
  -> [6] resistance table (analytical, no solver)   resistance_*.TYP
  -> [7] rules assembly (build_combined_caps + gen_rules_tcl)  gt2n_combined.rcx.model
  -> [8] consumption in OpenROAD (set_extraction_rules_file + extract_parasitics)
```

Steps 2-5 run once per (pattern, corner) combination — for GT2N, ~7,000
patterns across both stacks — and are the only steps that need a field
solver. Steps 6-7 are cheap, deterministic post-processing over already-
harvested data and re-run in seconds any time new results come in.

## Why this process exists at all

OpenRCX has no reader for a PDK's native extraction deck format (ITF, ICT,
or otherwise). The only way to get real per-net parasitics out of
`extract_parasitics` is a `.rcx.model` rules file, and the only way to
build one from scratch is OpenRCX's own field-solver calibration flow:
generate calibration geometry (`gen_solver_patterns`), solve each pattern's
capacitance with an external 3D field solver (FasterCap), and re-assemble
the harvested per-pattern values into the rules-file format
(`read_rcx_tables` / `write_rcx_model`). Resistance does not need this —
it's a closed-form function of sheet resistance and geometry — but every
line item in this document that involves capacitance goes through the
field-solver path.

If a target process already ships an OpenRCX rules file upstream (most
mature PDKs do), skip this entire document and use that instead. This
process is only needed when one doesn't exist, as was the case for GT2N.

## Stage 1 — Process-stack translation (`.pro` files)

**Input**: the PDK's own extraction deck (ITF, ICT, or equivalent).
**Output**: `gt2n_process_frontside.pro`, `gt2n_process_backside.pro` — one
file per independent field-solver domain (see "frontside/backside split"
below).

`.pro` files are OpenRCX's process-stack input format, consumed by
`gen_solver_patterns -process_file <file>`. Structure:

```
CONDUCTOR <name> {
    distance     <ILD thickness below this conductor, um>
    thickness    <conductor thickness, um>
    min_width    <um>
    min_spacing  <um>
    resistivity  <ohm*um>   # = sheet_resistance(ohm/sq) * thickness(um)
}
DIELECTRIC <name>_diel {
    epsilon    <relative permittivity>
    thickness  <um>
    next_met   <1-based conductor index this ILD sits directly beneath>
}
```

Conductors are listed bottom-to-top in the stack. Parameters that come
straight from the PDK deck: `distance`, `thickness`, `min_width`,
`min_spacing`, `resistivity`, `epsilon`. Two parameters are **process-
file-author judgment calls, not PDK values**, and need to be set
deliberately:

- **Topside capping dielectric** (above the last real conductor): PDK
  decks often don't specify what's above the top metal. Use whatever the
  PDK's own field-solver deck (QRC/StarRC) documents as its background
  dielectric constant if available; air (`epsilon=1.0`) is the common
  fallback convention if not.
- **Topside dielectric thickness**: not a PDK value — pick something
  generous enough that the solver's outer boundary doesn't truncate
  fringing capacitance to the top conductor (a rule of thumb: ~10x the top
  layer's own min_width/min_spacing). This is a solver-accuracy-vs-runtime
  tradeoff, not something to derive from the deck.

**Parser quirk to know about**: `DIELECTRIC` blocks must have exactly one
key/value pair per line. Multiple fields crammed onto one line parse
silently as `epsilon=0`/`thickness=0` — no error, no warning — corrupting
every pattern that touches that layer. Verify by inspecting the
`process.out` echo `gen_solver_patterns` produces, not just by eyeballing
the `.pro` file.

**Frontside/backside split**: if the target process is backside-power
(BSPDN) or otherwise has two physically-separated conductor stacks with no
shared conductor, each stack is its own field-solver domain and needs its
own `.pro` file, own pattern generation, own FasterCap runs, and own
`.caps` file. They get combined into one rules file only at the final
assembly stage (Stage 7) — see the layer-numbering note there, which is
the main complication this split introduces.

## Stage 2 — Pattern generation

```
gen_solver_patterns -process_file <stack>.pro -wire_cnt <N> -version <1|2> \
    [-over_dist <n>] [-under_dist <n>]
```

Run once per `(stack, wire_cnt)` combination. Key parameter:

- **`-wire_cnt`**: how many identical target-metal wires are placed in the
  pattern (the "replica count" for that layer). This determines which
  `wire_index` category the resulting data feeds into the final rules file
  (see Stage 7's `wire_index` note) — `wire_cnt=1` and `2` both feed
  `wire_index=1` (open-ended patterns), `wire_cnt=3` feeds `wire_index=2`
  (fully coupled on both sides), `wire_cnt=5` feeds `wire_index=3` (dense
  packing). Skipping `wire_cnt=5` leaves the model with no data for dense-
  packing scenarios — not a rare corner case in real digital routing.
- **`-over_dist`/`-under_dist`** (default 4 if unset): how many layers away
  from the target metal the generator reaches when building the
  over/under/diag neighbor context. Left at the tool default here; if a
  process has an usually thick/large top-of-stack layer (e.g. a
  redistribution layer), check whether this default causes a disproportionate
  number of patterns to involve that layer — see Stage 3's "RDL-class
  layers" limitation below.

Each pattern's raw geometry lands in a directory tree keyed by
`family/pair/W/S` (e.g. `Over1/M1oM0/W0.032_W0.032/S0.112_S0.112/`) — this
depth matters for Stage 3's converter (see its hardcoded-path gotcha).

## Stage 3 — Running FasterCap

### What and why

FasterCap is a boundary-element (field-solver) capacitance extraction tool
— the reference solver OpenRCX's own calibration flow (`src/rcx/calibration/
fasterCap/` in the OpenROAD source tree) is built around. Two forks exist:
`ediloren/FasterCap` (upstream original) and `george-goudroumanis/
FasterCAP_v2`. Neither is a strictly safer default — evaluate both if
runtime/memory cost matters. On GT2N's dataset, the two forks agreed within
~5-6% on capacitance once each fork's own known bugs (below) were
controlled for; the real, confirmed difference between them was resource
cost (memory could differ by multiple orders of magnitude on the same
pattern in either direction), not accuracy.

### Build

Both forks need `libwxgtk-dev` and Eigen (Eigen ships with recent Debian/
Ubuntu; wxWidgets version must match `wx-config --version` exactly in the
CMake config, which may need editing if it's hardcoded to a different
minor version than what's installed) and OpenMP (`#include <omp.h>` may be
missing in `FasterCapConsole.cpp` depending on fork/version). Delete any
committed `CMakeCache.txt`/`CMakeFiles` before configuring fresh — these
commonly ship pointing at the original author's build paths. Configure
headless (no GUI) for batch/cluster use:
```
cmake -G"Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DFASTFIELDSOLVERS_HEADLESS=ON ...
```
The wxWidgets `"Assert failure"` message printed to stderr on every run is
a known-benign upstream issue (fixed in wxWidgets >= 3.1.1), not a real
error.

### Geometry conversion

`UniversalFormat2FasterCap_923.py` (OpenROAD's own reference converter,
`src/rcx/rule_scripts/`) turns `gen_solver_patterns`' raw geometry into the
`wires.lst`/`Wires/`/`Dielectrics/` layout FasterCap actually reads. This
script inherited from upstream, unmodified, and carries several real bugs
worth knowing about before trusting its output blind:

- **Hardcoded shared-panel-pool path depth** (`"../../../../../../{}"`,
  literally 6 `..` levels at two call sites) — not computed from actual
  directory depth. If your pattern directory structure has a different
  depth than the reference flow assumed, this needs a matching one-time
  fix or every solve fails with `cannot open file '.../Wires/wire_....txt'`.
- **Dielectric-epsilon lookup uses a per-pattern local counter as a global-
  list index.** The converter builds one global dielectric list from the
  full process file (bottom-to-top order) but re-derives each panel's
  epsilon by indexing into that global list with a counter that resets to
  0 for every pattern. This is only correct if a pattern's local window
  happens to start at the literal bottom of the stack — patterns whose
  window starts mid-stack (common for `Over`/`OverUnder` patterns not
  anchored at the lowest layer) get the wrong dielectric's epsilon
  silently substituted. Fix: index by dielectric *name* (unique, and
  present in both the local and global lists) instead of position.
- **Off-by-one epsilon-lookup crash at the stack's top/bottom boundary.**
  Several call sites fetch the epsilon of "the dielectric one layer
  above/below the current one" via `shapeorder ± 1` with no bounds check —
  crashes (`IndexError`) when the current layer is already the topmost or
  bottommost entry, and (worse) silently wraps to the *wrong end of the
  list* via Python's negative-index semantics when `shapeorder - 1` is
  evaluated at index 0, rather than crashing. Fix: clamp the index to
  `[0, len(list)-1]` before lookup (repeating the boundary layer's own
  value past the modeled edge, which is physically reasonable) instead of
  arithmetic that can go out of bounds in either direction.
- **Dielectric-block `name` field on its own line isn't parsed** when
  reading the runtime `process.out` format (as opposed to a hand-written
  `.pro` file) — `process.out` emits `DIELECTRIC { ... name <X> ... }`
  rather than `DIELECTRIC <X> { ... }`, and the reference parser has no
  branch for the separated form, silently giving every dielectric the
  literal name `"{"`. If any fix above depends on matching dielectric
  names, verify against the real runtime file format, not just a
  hand-written process file — a fix that works against one and not the
  other can silently no-op in production while still passing a test.

Verify any fix against real converted output for a pattern whose local
window does *not* start at the stack's bottom (that's the case these bugs
actually affect) — patterns anchored at the bottom will show no
difference and can mask a broken fix.

### Solving

Invocation: `FasterCap -b <wires.lst> -g -a<target> [flags]`. Full flag
reference from `FasterCap -b?`. The single most impactful flag found:

| Flag | Effect | Recommendation |
|---|---|---|
| `-ap` | Automatic preconditioner selection — switches from a fixed weak (Jacobi) preconditioner to an adaptive one once problem size crosses an internal threshold | **Use unconditionally.** Fixed the majority of observed non-convergence and reduced peak memory by 1-2 orders of magnitude on the worst cases found, with zero regression on easy patterns (auto-selection only changes behavior once a threshold is crossed) |
| `-g` | Galerkin integration (more accurate of the two panel-interaction schemes) | Use by default |
| `-a<rel err>` | Target relative error for the automatic-refinement stopping criterion | `0.01` was sufficient once `-ap` is in use |
| `-t<tol>` | GMRES inner-iteration tolerance | Tested tightening this on a hard case — no effect. The bottleneck was preconditioning, not GMRES tolerance |
| `-ps<dim>` | Manually-specified two-level preconditioner dimension | Only try if `-ap` isn't available — picking the wrong dimension by hand is easy (a dimension too small for the problem size doesn't fix oscillating non-convergence) |
| `-m<mesh>` | Geometric mesh refinement granularity | Leave at default — tightening trades memory for accuracy, fighting directly against any memory ceiling |

**A hardcoded auto-refine round cap exists in both forks** (128 rounds
upstream, further reduced to 16 in one fork's base, before either fork's
own convergence work) — if a pattern doesn't converge within the cap, the
solver **falls through silently and returns whatever partial value it last
computed, with a normal exit code and no distinguishing flag**. This is
the single most important limitation to build tooling around: don't trust
a `RESULT`-tagged output as converged just because the process exited
cleanly. Parse the solver's own reported round count and, ideally, its
own printed convergence-error trajectory (`wires.log`), and treat any
result that hit the round cap as suspect. If raising the cap is an option
(it's a source-level `#define`, not a CLI flag in either fork), it costs
runtime only on patterns that actually need the extra rounds — patterns
that already converge under the original cap are unaffected.

### Known FasterCap/OpenRCX-pipeline limitations to plan around

These are the generalizable findings from calibrating GT2N; expect some
subset of these on any process, though the exact incidence rates will
differ:

- **Memory cost is extremely heavy-tailed and only loosely predictable
  from pattern name.** Two empirical (not analytically derived) risk
  factors found: spacing exactly at the minimum-allowed value (`S == W`),
  and any 3-conductor "coupled on both sides" pattern family. Neither rule
  is exhaustive — plan for a real long tail of exceptions and size memory
  tiers empirically (probe a diverse sample at a generous ceiling, then
  set the production ceiling with margin over the observed worst case),
  not purely from these two rules.
- **A geometry-generator bug in `wire_cnt=5` patterns**: `gen_solver_
  patterns`' own C++ implementation (`extSolverGen::writeWirePatterns`,
  upstream OpenROAD) places two of the five replica wires at literally
  identical coordinates for `wire_cnt == 5` specifically — a genuine short
  circuit in the generated input geometry, not a convergence problem. No
  solver setting fixes this; it produces confidently-wrong output (a clean
  exit, no warning) rather than an error. A fix exists upstream (OpenROAD
  PR #7720, approved but stalled/closed unmerged as of this writing) —
  check whether it has since landed before calibrating any process that
  needs `wire_cnt=5` data.
- **An intrinsically large top-of-stack layer (e.g. a redistribution
  layer) can be effectively unconvergeable** in patterns that involve it,
  independent of any solver tuning. A single global adaptive mesh has a
  structurally hard time simultaneously resolving a small near-field
  structure and a much larger (4x+ thicker/wider), farther conductor —
  panel count can double every refinement round with no sign of settling,
  making the memory cost of "just add more rounds" exponential rather
  than linear. Before spending compute chasing this, check whether the
  PDK's own documented benchmark flows actually route on the layer in
  question — if not, deferring its characterization as an explicit,
  documented model gap (rather than forcing convergence) may be the
  correct call, not just a compute-saving shortcut.
- **A residual negative-value numerical artifact on weak, long-range
  coupling terms** (2nd-nearest same-metal-neighbor coupling, and similar)
  shows up specifically in richer wire-count patterns (3+ replica wires) —
  confirmed via FastCap's own unconditionally-printed sanity warnings
  ("capacitance matrix has a non-negative off-diagonal element...",
  "...is not diagonally dominant...") on the raw solved matrix. This is a
  genuine solver-precision limit on terms an order of magnitude smaller
  than the dominant near-neighbor term, not a parsing bug — confirmed by
  hand-tracing the raw matrix through the parser's own formula and
  matching production output to the decimal. No config sweep resolves it;
  treat as a documented model gap for the affected `wire_cnt`/family
  combinations rather than continuing to spend compute on it.
- **A near-singular boundary-element kernel can produce `NaN`/assert
  crashes** for some patterns during adaptive mesh refinement, when two
  panels end up nearly coincident. Independent of `-a`/`-t`/preconditioner
  flags directly, but `-ap` incidentally changes the refinement path taken
  and resolves roughly a third of these cases as a side effect (not a
  guaranteed fix) — the rest are a genuine missing epsilon-guard in the
  solver itself.
- Sanity-check parsed output against something independent (a parallel-
  plate estimate, an analytical model already in use, cross-validation
  between two independent derivations of the same PDK constant) before
  trusting a large batch of harvested results — several of the findings
  above were only caught this way, not from the solver itself flagging
  anything.

## Stage 4 — Running at scale on a shared/cluster resource

At GT2N's scale (~7,000 patterns), running this serially on one machine is
impractical; the approach below generalizes to any shared batch/cluster
resource (Kubernetes, Slurm, or otherwise), not just the specific
scheduler used here:

- **Shard a flat pattern-list ("taskfile") across N worker pods/jobs**,
  each processing every Kth line (index-modulo-N), rather than trying to
  coordinate work assignment centrally. Cheap, embarrassingly parallel,
  and tolerant of any single worker dying (it just leaves its shard
  incomplete, harvested and re-queued separately, rather than blocking
  the others).
- **Give every worker its own per-pattern wall-clock ceiling** and kill
  and move on past it (recording a timeout, distinct from other failure
  modes) — without this, one pathological pattern (a slow oscillating
  non-convergence, or a solver bug that hangs rather than crashes) can
  hold an entire worker hostage indefinitely.
- **Size memory tiers empirically, not from a single rule.** A single
  "run everything at a huge ceiling" approach both wastes resources on the
  common case and can still trip a cluster-level low-utilization throttle
  (relevant on shared academic/research clusters specifically) if the
  ceiling is set far above what most patterns actually need. A tiered
  approach — a cheap default ceiling for the bulk of patterns, a smaller
  set of confirmed-heavy patterns routed to a higher ceiling sized from
  direct probing, not guesswork — balances this better. Expect some
  residual OOM tail regardless of tier sizing on a heavy-tailed
  distribution; that's expected, not a sign the tiering is wrong.
- **On preemption/OOM, don't blindly retry the whole batch.** If failures
  are deterministic (the same pattern will hit the same ceiling every
  time), a bare retry just wastes a full worker lifecycle re-hitting the
  same wall — route only the specific failed patterns to a different
  (usually larger-memory) tier instead. Reserve actual retries for
  failures that are genuinely non-deterministic (a transient
  infrastructure fault, not a solver limit).
- **Use a multi-tier escalation strategy for patterns that fail at
  default settings**, rather than one fixed retry policy for everything:
  1. **Automatic/default mode** first (cheapest, handles the large
     majority).
  2. **A small number (e.g. 3) of hand-picked alternative flag
     combinations**, raced concurrently against just the patterns that
     failed tier 1 — different points on the mesh-refinement /
     preconditioner-tolerance / GMRES-tolerance tradeoff space.
  3. **A fuller combinatorial sweep** (e.g. all combinations of {tight,
     loose} across each of 2-3 tunable dimensions) only for whatever
     still fails after tier 2 — this tier is expensive per-pattern, so
     keep the input list to it as small as possible via tiers 1-2.
  Each tier should be a strict superset check — only patterns that failed
  the previous tier are escalated, so total compute scales with the
  number of hard patterns, not the full set, at every tier past the
  first.
- **Harvest results incrementally, don't wait for full-batch completion.**
  Workers should write append-only per-worker result logs to shared/
  durable storage as they go (not just at the end), so results are
  recoverable even if a batch is killed early (deliberately, or by a
  cluster-level failure threshold) with many workers still mid-run.
- Track every attempted pattern's outcome in one queryable source of
  truth (a TSV/CSV with pattern key, verdict, and diagnostic fields like
  round count and peak memory) as results land, rather than reconstructing
  status from scattered logs after the fact — this is what makes it
  possible to later answer "has every pattern in the true universe been
  attempted" with confidence instead of guessing.

## Stage 5 — Assembling the rules file

Three scripts, run in order, over the tracked-results TSV from Stage 4 (no
FasterCap re-run needed — this stage is pure post-processing):

### 5a. Resistance table (`gen_resistance_table.py`)

Resistance needs no field solver — `R = sheet_resistance(ohm/sq) *
(length/width)`, a pure per-layer constant for a fixed test-pattern
length/width ratio. Output format (`resistance_<stack>.TYP`) is
reverse-engineered from the C++ reader (`extRCmodel_solver.cpp::
readRCvalues`) — there is no example or generator for this file format to
copy from, so verify the format directly against the reader's own field-
offset parsing rather than guessing from a capacitance-line example:

```
Metal <met> RESOVER 0 Under 0 Dist <d> Width <w> LEN <len> CC 0 FR 0 TC 0 CC2 0 RES <r> <pattern_name>
```

Two things the reader requires that aren't obvious from the format alone:

- **The trailing pattern-name field needs exactly 5 `/`-separated
  segments** (`family/pair/width/spacing/wire`) — the reader indexes
  backward from the end with no bounds check, so a shorter name
  segfaults.
- **At least two distinct `Dist` samples per layer are required**, even
  though resistance is physically distance-independent. The on-disk
  format groups samples by distance into "bins," and the reader
  unconditionally dereferences a second bin the moment a real design
  has actual coupling context — a single-sample table null-derefs at
  that point. Emit two samples with identical `RES` values (e.g.
  `Dist=0` and `Dist=1`) to satisfy this structural minimum without
  changing the actual resistance value.

### 5b. Capacitance table (`build_combined_caps.py`)

Concatenates every converged pattern's stored per-wire result text
(already in the exact format `read_rcx_tables -file` expects — identical
to what the FasterCap-log parser itself produces) into one `.caps` file
per stack.

**The layer-numbering remap is the step most likely to be needed for any
new process and most likely to be gotten wrong.** Every wire line in the
harvested data carries layer references ("Metal N", "Over N", "Under N")
that are 1-based positions in that *pattern's own generation-time process
file* — not necessarily the same numbering the real design's tech LEF
uses for `extract_parasitics` to index its per-layer tables. If the
process file used for pattern generation numbers layers differently than
the real unified tech LEF (very likely whenever generation was done
per-stack/per-domain, as with a frontside/backside split), **every layer
reference must be remapped to the real routing-level numbering before
being written into the combined `.caps` file, or extraction crashes or
silently applies the wrong layer's rules.** Confirm the real numbering
empirically (e.g. `dbTechLayer::getRoutingLevel()` in OpenROAD against
the actual loaded tech LEF) — don't assume it matches either stack's own
local convention.

If the real numbering doesn't just offset a stack's local order but
**reverses its direction** (as with GT2N's backside, where local "away
from devices" is real "toward devices"), a value remap alone isn't
enough — the Over and Under fields must also be **swapped** with each
other (not just remapped in place) to keep the over<met<under relationship
OpenRCX's own rules-loading code requires. Verify this against one real
sample by hand before trusting a bulk remap: compute what the remapped
over/met/under values *should* be from first principles for one pattern,
and confirm only the swapped assignment satisfies the ordering constraint.

**Some data may become structurally unrepresentable after a reversing
remap.** A "coupled-layer-below" (`DiagUnder`) relationship in local space
can become a "coupled-layer-above" relationship in real space that the
rules-file format has no field for (no symmetric `DiagOver` concept, and
the diagonal neighbor's width isn't interchangeable with the met's own
width field to work around it). Drop these lines rather than guess at a
representation, and log a count of how many were dropped — don't silently
lose data without a visible record of the gap.

### 5c. Rules-file assembly (`gen_rules_tcl.py` → `openroad -exit <tcl>`)

Generates a TCL script: one `init_rcx_model -met_cnt <total layers>`, then
one `read_rcx_tables -corner_name <corner> -file <caps> -wire_index <N>
-<family>` call per (stack × wire_index × family) combination, then
`write_rcx_model -file <output>.rcx.model`.

- **`met_cnt`** must be the *combined* real layer count across every
  stack the model needs to cover (e.g. backside + frontside), even though
  each stack's `.caps` data was generated independently — `extract_
  parasitics` iterates every routing layer in the design's loaded tech
  unconditionally, and a model covering only part of that range indexes
  out of bounds (crash) the moment a real design uses a layer outside it.
  **Build one combined model, not one model per stack**, if the real
  design's tech LEF spans multiple independently-solved domains.
- **`wire_index`** maps to the pattern's `wire_cnt`, per the reader's own
  documented convention: `wire_cnt` 1 or 2 → `wire_index=1` ("open-ended"),
  `wire_cnt=3` → `wire_index=2` ("fully coupled on both sides"),
  `wire_cnt=5` → `wire_index=3` ("dense packing"). This convention is
  fixed by the OpenRCX reader, not a project choice.
- **`family`** is one of `over`/`under`/`over_under`/`diag` — read each
  one that has data; there is no cost to reading a family with zero
  matching lines in a given `.caps` file.

Sanity-check the assembled model against a real routed design before
trusting it in production: load it via `set_extraction_rules_file` and
run `extract_parasitics` against an actual routed ODB (not a synthetic
test case) and confirm it produces a real, non-trivial SPEF with no
crash. A model that "writes successfully" is not the same as a model that
extracts successfully — most of the crashes found in this process only
surfaced at that second check.

## Stage 6 — Using the model in OpenROAD

There is no `read_rcx_model` command. The real sequence, per OpenRCX's own
reference flow:

```tcl
get_model_corners -ext_model_file <combined>.rcx.model
define_rcx_corners -corner_list "<corner>"
set_extraction_rules_file <combined>.rcx.model
extract_parasitics -version 2.0 ...
```

Wire this into an ORFS-style flow via its `RCX_RULES` variable pointing at
the combined model file; the flow's own final-report stage should already
branch on whether `RCX_RULES` is set to decide between real extraction and
whatever cruder fallback (global-route-based estimate, flat analytical
`set_layer_rc`) it uses in the absence of a rules file.

**Check whether the model is also expected to feed anything besides
`extract_parasitics`** (e.g. IR-drop/power-grid analysis) before assuming
one model covers every downstream consumer — some tools (e.g. OpenROAD's
PSM) get their per-layer resistance from a completely separate analytical
path (`set_layer_rc`) and never touch a `.rcx.model` file at all, so a
calibrated rules file may need a separate, much smaller distillation into
scalar per-layer values to actually reach every consumer that needs
resistance data.

## Summary: parameters and tunings that need a project-specific decision

| Parameter | Where | Not derivable from the PDK deck — needs a judgment call |
|---|---|---|
| Topside capping dielectric epsilon/thickness | `.pro` file | Use the PDK's own field-solver background-dielectric value if documented; a generous multiple of the top layer's min geometry for thickness |
| `-wire_cnt` sweep coverage | `gen_solver_patterns` | Skipping `wire_cnt=5` loses all dense-packing (`wire_index=3`) data — usually not acceptable for real digital routing |
| `-over_dist`/`-under_dist` | `gen_solver_patterns` | Tool default (4) may disproportionately involve an unusual top-of-stack layer; check before accepting the default blindly |
| FasterCap solver flags | Stage 3 | `-g -ap` as a strong default; everything else situational |
| Auto-refine round cap | Stage 3 (solver build) | Source-level `#define`, not exposed as a flag — raise it if hard patterns need it, at the cost of runtime only on patterns that need the extra rounds |
| Memory tier ceilings | Stage 4 (cluster job sizing) | Empirical, from direct probing — not derivable from pattern name alone |
| Real routing-layer numbering / stack ordering / Over-Under swap | Stage 5b (`.caps` remap) | Must be confirmed empirically against the real tech LEF for the specific target process — do not assume it matches any process file's own local convention |
| `met_cnt` | Stage 5c | Combined real layer count across every stack, not any single stack's own count |
