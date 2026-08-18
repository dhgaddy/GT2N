# OpenRCX process-stack file for GT2N frontside BEOL (M0 -> RDL)
#
# Derived mechanically from nxtgrd/GT2.itf. Translation rule (validated against
# OpenROAD's own reference process file at
# src/rcx/test/rcx_v2/FasterCapModel/data/process):
#   - each ITF "DIELECTRIC <L>_diel { THICKNESS=t ER=e }" line immediately
#     precedes "CONDUCTOR <L> { THICKNESS=... WMIN=... SMIN=... RPSQ=... }"
#     and represents the ILD directly beneath conductor <L>.
#   - CONDUCTOR <L>.distance      = <L>_diel.THICKNESS
#   - CONDUCTOR <L>.thickness     = ITF CONDUCTOR THICKNESS
#   - CONDUCTOR <L>.min_width     = ITF WMIN
#   - CONDUCTOR <L>.min_spacing   = ITF SMIN
#   - CONDUCTOR <L>.resistivity   = ITF RPSQ * THICKNESS   (ohm*um)
#   - DIELECTRIC <L>_diel.epsilon   = ITF ER
#   - DIELECTRIC <L>_diel.thickness = ITF THICKNESS
#   - DIELECTRIC <L>_diel tagged "next_met <N>" where N is the 1-based
#     bottom-up index of conductor <L> in this stack.
#
# Scope: M0 is the lowest OpenRCX-relevant routing layer (GATE/ACT/SDCON/
# VSD/VG are device/MOL layers below M0, out of scope for wire RC
# extraction -- confirmed against designs/gt2n's setRC_full.tcl, which only
# sets -layer RC for M0..RDL and BPR..BRDL/BM1-4).
#
# Dielectric ABOVE the topmost conductor (RDL): epsilon=1.0 (air) is sourced,
# not guessed -- GT2.ict's "process GT2 { background_dielectric_constant 1.0 }"
# is Cadence QRC's documented value for the region above the last declared
# layer, and GT2.itf's silence on a topside cap matches StarRC's own default
# (air) convention. Both tools agree.
#
# The 16.0um thickness below is NOT a PDK value -- it's a solver boundary
# choice (~10x RDL's 1.6um min_width/min_spacing, a common rule of thumb to
# keep the field solver's outer boundary far enough from the top conductor
# to avoid truncation error). No PDK will specify this; adjust if solver
# runtime/accuracy tradeoffs call for it.
#
# PARSER QUIRK (verified against the real rcx::gen_solver_patterns parser,
# extprocess.cpp readDielectric): DIELECTRIC blocks MUST have one key/value
# pair per line. Cramming multiple fields onto a single line (as an early
# draft of this file did, and as OpenROAD's own reference example at
# rcx/test/rcx_v2/FasterCapModel/data/process's m2_2 block does) silently
# parses as epsilon=0/thickness=0 with no error -- confirmed by running
# gen_solver_patterns and inspecting process.out. CONDUCTOR blocks were
# never affected (always one field per line here).

CONDUCTOR M0 {
	distance	0.048
	thickness	0.024
	min_width	0.012
	min_spacing	0.012
	resistivity	0.179064
}

CONDUCTOR M1 {
	distance	0.056
	thickness	0.028
	min_width	0.014
	min_spacing	0.014
	resistivity	0.17150
}

CONDUCTOR M2 {
	distance	0.048
	thickness	0.024
	min_width	0.012
	min_spacing	0.012
	resistivity	0.179064
}

CONDUCTOR M3 {
	distance	0.056
	thickness	0.028
	min_width	0.014
	min_spacing	0.014
	resistivity	0.17150
}

CONDUCTOR M4 {
	distance	0.084
	thickness	0.042
	min_width	0.021
	min_spacing	0.021
	resistivity	0.147252
}

CONDUCTOR M5 {
	distance	0.084
	thickness	0.042
	min_width	0.021
	min_spacing	0.021
	resistivity	0.147252
}

CONDUCTOR M6 {
	distance	0.152
	thickness	0.076
	min_width	0.038
	min_spacing	0.038
	resistivity	0.076684
}

CONDUCTOR M7 {
	distance	0.152
	thickness	0.076
	min_width	0.038
	min_spacing	0.038
	resistivity	0.076684
}

CONDUCTOR M8 {
	distance	0.152
	thickness	0.076
	min_width	0.038
	min_spacing	0.038
	resistivity	0.076684
}

CONDUCTOR M9 {
	distance	0.152
	thickness	0.076
	min_width	0.038
	min_spacing	0.038
	resistivity	0.076684
}

CONDUCTOR M10 {
	distance	0.224
	thickness	0.112
	min_width	0.056
	min_spacing	0.056
	resistivity	0.046928
}

CONDUCTOR M11 {
	distance	0.224
	thickness	0.112
	min_width	0.056
	min_spacing	0.056
	resistivity	0.046928
}

CONDUCTOR M12 {
	distance	0.224
	thickness	0.112
	min_width	0.360
	min_spacing	0.360
	resistivity	0.025760
}

CONDUCTOR M13 {
	distance	0.224
	thickness	0.112
	min_width	0.360
	min_spacing	0.360
	resistivity	0.025760
}

CONDUCTOR RDL {
	distance	0.5
	thickness	0.5
	min_width	1.600
	min_spacing	1.600
	resistivity	0.005
}

DIELECTRIC M0_diel {
	epsilon 2.4
	thickness 0.048
	next_met 1
}

DIELECTRIC M1_diel {
	epsilon 2.4
	thickness 0.056
	next_met 2
}

DIELECTRIC M2_diel {
	epsilon 2.4
	thickness 0.048
	next_met 3
}

DIELECTRIC M3_diel {
	epsilon 2.4
	thickness 0.056
	next_met 4
}

DIELECTRIC M4_diel {
	epsilon 2.5
	thickness 0.084
	next_met 5
}

DIELECTRIC M5_diel {
	epsilon 2.5
	thickness 0.084
	next_met 6
}

DIELECTRIC M6_diel {
	epsilon 2.5
	thickness 0.152
	next_met 7
}

DIELECTRIC M7_diel {
	epsilon 2.5
	thickness 0.152
	next_met 8
}

DIELECTRIC M8_diel {
	epsilon 2.5
	thickness 0.152
	next_met 9
}

DIELECTRIC M9_diel {
	epsilon 2.5
	thickness 0.152
	next_met 10
}

DIELECTRIC M10_diel {
	epsilon 2.5
	thickness 0.224
	next_met 11
}

DIELECTRIC M11_diel {
	epsilon 2.5
	thickness 0.224
	next_met 12
}

DIELECTRIC M12_diel {
	epsilon 2.5
	thickness 0.224
	next_met 13
}

DIELECTRIC M13_diel {
	epsilon 2.5
	thickness 0.224
	next_met 14
}

DIELECTRIC RDL_diel {
	epsilon 2.5
	thickness 0.5
	next_met 15
}

DIELECTRIC air_cap {
	epsilon 1.0
	thickness 16.0
}
