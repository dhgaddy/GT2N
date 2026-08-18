#!/bin/bash
set -e
RCX_TCL=/home/dgaddy/.cache/bazel/_bazel_dgaddy/9593cb0e7729b5be4f5e9dd2575a824e/external/openroad+/src/rcx/src/OpenRCX_process.tcl
OR=/home/dgaddy/.cache/bazel/_bazel_dgaddy/9593cb0e7729b5be4f5e9dd2575a824e/execroot/_main/bazel-out/k8-opt-exec-ST-d57f47055a04/bin/external/openroad+/openroad

for STACK in frontside backside; do
  BASE=/home/dgaddy/research/GT2N/openrcx/work/$STACK
  for WC in 1 2 3 5; do
    for V in 1 2; do
      if [ "$WC" = "1" ] && [ "$V" = "1" ]; then
        continue  # already done, sits directly in $BASE
      fi
      RUN="$BASE/sweep/wc${WC}_v${V}"
      mkdir -p "$RUN"
      cp "$BASE/process.pro" "$RUN/process.pro"
      cd "$RUN"
      cat > gen.tcl <<EOF
source "$RCX_TCL"
gen_solver_patterns -process_file process.pro -process_name TYP -wire_cnt $WC -version $V
puts "GEN_SOLVER_PATTERNS_DONE $STACK wc=$WC v=$V"
EOF
      echo "=== $STACK wc=$WC v=$V ==="
      "$OR" -no_init gen.tcl > gen.log 2>&1
      tail -3 gen.log
      grep -ic "warn\|error" rulesGen.log || true
    done
  done
done
echo "ALL_SWEEP_RUNS_DONE"
