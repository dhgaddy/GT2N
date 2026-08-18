#!/bin/bash
# Entrypoint for gt2n FasterCap batch pods on NRP Nautilus (vlsida namespace).
#
# Env vars (set by the Job spec):
#   JOB_COMPLETION_INDEX  - set automatically by k8s for an Indexed Job
#   N_SHARDS              - total number of pods (must match completions)
#   PARALLEL              - concurrent FasterCap solves within this one pod
set -e

INDEX="${JOB_COMPLETION_INDEX:-0}"
NSHARDS="${N_SHARDS:-20}"
PARALLEL="${PARALLEL:-4}"

echo "=== pod $INDEX of $NSHARDS starting, internal parallelism $PARALLEL ==="

apt-get update -qq
apt-get install -y -qq libwxgtk3.2-dev unzip > /tmp/apt.log 2>&1 \
  || apt-get install -y -qq libwxgtk3.0-gtk3-dev unzip > /tmp/apt.log 2>&1
pip3 install -q numpy pandas matplotlib xlsxwriter

WX_VERSION="$(wx-config --version | cut -d. -f1,2)"
echo "wxWidgets version detected (major.minor): $WX_VERSION"

mkdir -p /work
cd /work
git clone --depth 1 https://github.com/dhgaddy/GT2N.git
git clone --depth 1 https://github.com/george-goudroumanis/FasterCAP_v2.git

cd FasterCAP_v2/FasterCap_v2/FasterCap
sed -i "s/--version=3.0/--version=$WX_VERSION/" CMakeLists.txt
sed -i '/#include "FasterCapConsole.h"/a\\n#include <omp.h>' FasterCapConsole.cpp

# The upstream repo ships a stale in-tree CMakeCache.txt/CMakeFiles from the
# original author's machine; a fresh out-of-tree configure fails unless these
# are removed first (found the hard way testing this locally).
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

process_one() {
  local COMBO="$1" PAT="$2" MODE="$3" STACK="$4" WCTAG="$5" VTAG="$6"
  cd "$COMBO"
  mkdir -p "fcout2/$PAT"
  python3 "$CONV" TYP/process.out "TYP/$PAT" fcout2 "$MODE" -sim_window_ext -20 -20 -20 20 20 20 \
    > "fcout2/$PAT/convert.log" 2>&1
  "$FCAP" -b "fcout2/$PAT/wires.lst" -g -a0.01 > "fcout2/$PAT/wires.log" 2>&1
  python3 "$PARSE" -in_file "fcout2/$PAT/wires.log" -out_file "fcout2/$PAT/pattern.caps" \
    > "fcout2/$PAT/parse.log" 2>&1
  echo "RESULT|$STACK|$WCTAG|$VTAG|$(cat "fcout2/$PAT/pattern.caps" 2>/dev/null)"
}
export -f process_one
export CONV FCAP PARSE

WORKDIR=/work/run
mkdir -p "$WORKDIR"
TASKS="$WORKDIR/tasks.txt"
> "$TASKS"

GLOBAL_IDX=0
for STACK in frontside backside; do
  PRO="/work/GT2N/openrcx/gt2n_process_${STACK}.pro"
  for WC in 1 2 3 5; do
    for V in 1 2; do
      if [ "$V" = "1" ]; then MODE=normalized; else MODE=standard; fi
      COMBO="$WORKDIR/${STACK}_wc${WC}_v${V}"
      mkdir -p "$COMBO"
      cp "$PRO" "$COMBO/process.pro"
      cd "$COMBO"
      echo "gen_solver_patterns -process_file process.pro -process_name TYP -wire_cnt $WC -version $V" > gen.tcl
      "$OR" -no_init gen.tcl > gen.log 2>&1
      if [ ! -f patternFiles.TYP ]; then
        echo "=== gen_solver_patterns failed for ${STACK} wc${WC} v${V}, gen.log: ==="
        cat gen.log
        exit 1
      fi
      mkdir -p TYP
      cp process.out TYP/process.out
      mkdir -p Wires Dielectrics

      while IFS= read -r line; do
        PAT="${line#TYP/}"; PAT="${PAT%/wires}"
        if [ $((GLOBAL_IDX % NSHARDS)) -eq "$INDEX" ]; then
          echo "$COMBO $PAT $MODE $STACK wc$WC v$V" >> "$TASKS"
        fi
        GLOBAL_IDX=$((GLOBAL_IDX + 1))
      done < patternFiles.TYP
      cd "$WORKDIR"
    done
  done
done

echo "=== pod $INDEX: $(wc -l < "$TASKS") patterns assigned, running with -P $PARALLEL ==="
xargs -P "$PARALLEL" -L 1 bash -c 'process_one "$@"' _ < "$TASKS"
echo "=== pod $INDEX: DONE ==="
