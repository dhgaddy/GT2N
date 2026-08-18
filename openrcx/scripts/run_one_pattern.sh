#!/bin/bash
set -e
COMBO_DIR=$1
OUT_DIR=$2
MODE=$3
EXT=$4
PAT=$5
CONV=$6
FCAP=$7
PARSE=$8

cd "$COMBO_DIR"
mkdir -p "$OUT_DIR/$PAT"
python3 "$CONV" "TYP/process.out" "TYP/$PAT" "$OUT_DIR" "$MODE" -sim_window_ext -"$EXT" -"$EXT" -"$EXT" "$EXT" "$EXT" "$EXT" > "$OUT_DIR/$PAT/convert.log" 2>&1
OMP_NUM_THREADS=1 "$FCAP" -b "$OUT_DIR/$PAT/wires.lst" -g -a0.01 > "$OUT_DIR/$PAT/wires.log" 2>&1
python3 "$PARSE" -in_file "$OUT_DIR/$PAT/wires.log" -out_file "$OUT_DIR/$PAT/pattern.caps" > "$OUT_DIR/$PAT/parse.log" 2>&1
