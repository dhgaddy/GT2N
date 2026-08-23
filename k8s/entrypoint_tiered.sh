#!/bin/bash
# Two-tier follow-up job entrypoint. Processes a shard of a specific
# pattern-list file (light_patterns.txt or heavy_patterns.txt) SEQUENTIALLY
# (no internal concurrency) to eliminate both risks found during probing:
#   - memory-summing risk (no 2 patterns ever run concurrently in one pod)
#   - the shared Wires/Dielectrics file-collision bug in
#     UniversalFormat2FasterCap_923.py (only unsafe under concurrent access;
#     sequential reuse of the shared pool is fine and intentional caching)
#
# Env vars (set by the Job spec):
#   JOB_COMPLETION_INDEX  - set automatically by k8s for an Indexed Job
#   N_SHARDS              - total number of pods for THIS tier's job
#   TASKFILE              - light_patterns.txt or heavy_patterns.txt
set -e

INDEX="${JOB_COMPLETION_INDEX:-0}"
NSHARDS="${N_SHARDS:-100}"
TASKFILE="${TASKFILE:-light_patterns.txt}"

echo "=== pod $INDEX of $NSHARDS starting, taskfile=$TASKFILE ==="

apt-get update -qq
apt-get install -y -qq libwxgtk3.2-dev unzip > /tmp/apt.log 2>&1 \
  || apt-get install -y -qq libwxgtk3.0-gtk3-dev unzip > /tmp/apt.log 2>&1
pip3 install -q numpy pandas matplotlib xlsxwriter

WX_VERSION="$(wx-config --version | cut -d. -f1,2)"
mkdir -p /work
cd /work
git clone --depth 1 https://github.com/dhgaddy/GT2N.git
git clone --depth 1 https://github.com/george-goudroumanis/FasterCAP_v2.git

cd /work/FasterCAP_v2
git apply /work/GT2N/k8s/patches/fastercap_convergence_fix.patch
cd FasterCAP_v2/FasterCap
sed -i "s/--version=3.0/--version=$WX_VERSION/" CMakeLists.txt
sed -i '/#include "FasterCapConsole.h"/a\\n#include <omp.h>' FasterCapConsole.cpp
find /work/FasterCAP_v2/FasterCap_v2 -iname "CMakeCache.txt" -o -iname "CMakeFiles" -o -iname "cmake_install.cmake" -o -iname "Makefile" | xargs rm -rf
mkdir -p /work/fastercap_build
cd /work/fastercap_build
cmake -G"Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DFASTFIELDSOLVERS_HEADLESS=ON \
  /work/FasterCAP_v2/FasterCap_v2/FasterCap
make -j"$(nproc)"
FCAP=/work/fastercap_build/FasterCap

OR=/OpenROAD-flow-scripts/tools/install/OpenROAD/bin/openroad
SCRIPTS=/work/GT2N/openrcx/scripts
CONV="$SCRIPTS/UniversalFormat2FasterCap_923.py"
PARSE="$SCRIPTS/fasterCapParse.py"

TASKPATH="/scripts/$TASKFILE"
WORKDIR=/work/run
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Select this pod's shard (every NSHARDS-th line) from the tier's task file.
MYTASKS="$WORKDIR/my_tasks.txt"
> "$MYTASKS"
GLOBAL_IDX=0
while IFS=$'\t' read -r shard stack wc v pat; do
  [ -z "$stack" ] && continue
  if [ $((GLOBAL_IDX % NSHARDS)) -eq "$INDEX" ]; then
    echo -e "${stack}\t${wc}\t${v}\t${pat}" >> "$MYTASKS"
  fi
  GLOBAL_IDX=$((GLOBAL_IDX + 1))
done < "$TASKPATH"

echo "=== pod $INDEX: $(wc -l < "$MYTASKS") patterns assigned ==="

# A crash on one pattern (FasterCap can hit e.g. Trace/breakpoint traps on
# pathological geometry) must NOT abort the rest of this pod's shard --
# with set -e that took down 40+ still-good patterns per crash, and a retry
# just hits the same deterministic crash again. Only gen_solver_patterns
# failing is treated as fatal (it means the whole combo is unusable).
CURRENT_COMBO=""
while IFS=$'\t' read -r STACK WC V PAT <&3; do
  if [ "$V" = "1" ]; then MODE=normalized; else MODE=standard; fi
  COMBO="$WORKDIR/${STACK}_wc${WC}_v${V}"
  if [ "$COMBO" != "$CURRENT_COMBO" ]; then
    if [ ! -d "$COMBO" ]; then
      mkdir -p "$COMBO"
      cd "$COMBO"
      if [ "$WC" = "5" ]; then
        # wc5's gen_solver_patterns has a real upstream bug (OpenROAD PR #7720,
        # approved-but-stalled): wire 1 duplicates wire 3's position for every
        # wire_cnt=5 pattern, a literal short in the generated geometry. See
        # scratch_logs/FASTERCAP_FINDINGS.md. Fix requires rebuilding OpenROAD,
        # too expensive to do per-pod, so instead use geometry pre-generated
        # once locally with a patched OpenROAD build (gen_solver_patterns only
        # needs to run once per (stack,wire_cnt,version) combo, not per
        # pattern, so this covers every wc5 pattern in the PDK).
        PREGEN="/work/GT2N/openrcx/wc5_pregenerated/${STACK}_wc5_v${V}"
        if [ ! -d "$PREGEN" ]; then
          echo "=== no pre-generated wc5 geometry for $COMBO ==="
          exit 1
        fi
        cp -r "$PREGEN/TYP" TYP
        cp "$PREGEN/process.out" TYP/process.out
      else
        PRO="/work/GT2N/openrcx/gt2n_process_${STACK}.pro"
        cp "$PRO" process.pro
        echo "gen_solver_patterns -process_file process.pro -process_name TYP -wire_cnt $WC -version $V" > gen.tcl
        "$OR" -no_init gen.tcl < /dev/null > gen.log 2>&1
        if [ ! -f patternFiles.TYP ]; then
          echo "=== gen_solver_patterns FAILED for $COMBO, gen.log: ==="
          cat gen.log
          exit 1
        fi
        mkdir -p TYP
        cp process.out TYP/process.out
      fi
      mkdir -p Wires Dielectrics fcout2
    fi
    CURRENT_COMBO="$COMBO"
  fi
  cd "$COMBO"
  mkdir -p "fcout2/$PAT"
  set +e
  python3 "$CONV" TYP/process.out "TYP/$PAT" fcout2 "$MODE" -sim_window_ext -20 -20 -20 20 20 20 \
    > "fcout2/$PAT/convert.log" 2>&1
  CONV_RC=$?
  if [ "$CONV_RC" -ne 0 ]; then
    echo "SKIPPED|$STACK|wc$WC|v$V|$PAT|stage=convert|rc=$CONV_RC"
    set -e
    cd "$WORKDIR"
    continue
  fi
  "$FCAP" -b "fcout2/$PAT/wires.lst" -g -a0.01 > "fcout2/$PAT/wires.log" 2>&1
  FCAP_RC=$?
  if [ "$FCAP_RC" -ne 0 ]; then
    echo "SKIPPED|$STACK|wc$WC|v$V|$PAT|stage=fastercap|rc=$FCAP_RC"
    set -e
    cd "$WORKDIR"
    continue
  fi
  python3 "$PARSE" -in_file "fcout2/$PAT/wires.log" -out_file "fcout2/$PAT/pattern.caps" \
    > "fcout2/$PAT/parse.log" 2>&1
  PARSE_RC=$?
  set -e
  if [ "$PARSE_RC" -ne 0 ]; then
    echo "SKIPPED|$STACK|wc$WC|v$V|$PAT|stage=parse|rc=$PARSE_RC"
    cd "$WORKDIR"
    continue
  fi
  echo "RESULT|$STACK|wc$WC|v$V|$(cat "fcout2/$PAT/pattern.caps" 2>/dev/null)"
  cd "$WORKDIR"
done 3< "$MYTASKS"

echo "=== pod $INDEX: DONE ==="
