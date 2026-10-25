# OpenRCX process-stack file for GT2N frontside BEOL (M0 -> RDL)
#
# Rewritten from nxtgrd/GT2.itf AND qrc/GT2.ict together, replacing an earlier
# version of this file that read nxtgrd/GT2.itf alone and mis-decomposed its
# dielectric blocks (see git history / HIGHTIDE_QOR_COMPARISON.md for the
# investigation). Summary of what was wrong and how .ict fixed it:
#
#   GT2.itf lists each level as "DIELECTRIC <L>_diel {THICKNESS=t ER=e}"
#   immediately before "CONDUCTOR <L> {...}", which reads as if <L>_diel were
#   the ILD directly beneath conductor <L> alone. GT2.ict proves that's wrong:
#   it gives every block an explicit absolute `height`, and for every one of
#   the 14 frontside metal levels (M0..M13), "<L>_diel" starts at <L>'s OWN
#   bottom and runs thickness = (L's own conductor thickness) + (the real ILD
#   gap above L, up to the next conductor's bottom) -- i.e. each <L>_diel is
#   a composite slab covering L's own lateral fill AND the gap above it, not
#   a pure gap, and not "beneath" L at all.
#
#   Correct decomposition (verified exactly against GT2.ict's absolute
#   heights for all 14 M0..M13 levels):
#     met_L      (L's own lateral fill)      = L.THICKNESS            (epsilon = <L>_diel.ER)
#     next_met_(L+1) (real gap above L)      = <L>_diel.THICKNESS - L.THICKNESS   (epsilon = <L>_diel.ER)
#   Both halves share <L>_diel's epsilon, since GT2.ict marks the whole slab
#   "conformal FALSE" with one dielectric_constant -- there's no separate
#   liner/cap material to split out.
#
#   This stack happens to have gap_above_L == L.THICKNESS at every one of the
#   14 levels (a uniform 1:1 ILD-to-metal aspect-ratio design choice specific
#   to GT2N, confirmed, not assumed), which is also why every ITF "<L>_diel"
#   THICKNESS equals exactly 2x conductor L's own THICKNESS. That 2x pattern
#   is a consequence of this stack's design, not a general rule -- the
#   decomposition formula above is what's actually used, not "take half."
#
#   RDL is the one level GT2.ict doesn't cover (nothing above it in that
#   file). Checking RDL_diel against the same formula: RDL_diel.THICKNESS
#   (0.5) - RDL.THICKNESS (0.5) = 0 exactly, i.e. RDL_diel is entirely RDL's
#   own lateral fill with zero gap above it -- consistent with GT2.ict
#   independently having no entry above RDL, and consistent with air_cap
#   (see below) starting immediately at RDL's own top.
#
#   M0's OWN below-gap (toward the device/MOL layers, out of OpenRCX's scope)
#   has no same-pattern source, exactly like RDL has nothing above it -- GT2.itf's
#   M0_diel is entirely "above M0" (M0's own fill + the M0-M1 gap), so M0's
#   below-gap must come from a different entry. GT2.itf's "VSD_diel"
#   (THICKNESS=0.023, ER=3.9) is the dielectric immediately following
#   CONDUCTOR M0 in that file and is used here, cross-checked independently
#   against GT2.ict: GATE conductor top (height 0.01 + thickness 0.065 =
#   0.075) to M0's height (0.098) = 0.023, an exact match.
#
#   Known small residual: summing this file's own distance+thickness values
#   bottom-up from M0 puts RDL's top at 2.403um, while GT2.ict's own absolute
#   heights put it at 2.478um (RDL height 1.978 + thickness 0.5). The 0.075um
#   difference is entirely a boundary-reference artifact at the very bottom
#   (where GT2.ict's absolute "height=0" origin sits relative to the device
#   layers below M0, which are out of OpenRCX's scope here) -- it does not
#   affect any M0..RDL inter-metal gap, all of which are verified exactly
#   against GT2.ict above. Immaterial to wire-to-wire RC extraction.
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
# (air) convention. Both tools agree. It starts immediately at RDL's own top
# (see RDL's zero-gap-above finding above), not after an extra RDL_diel gap.
#
# The 16.0um thickness below is NOT a PDK value -- it's a solver boundary
# choice (~10x RDL's 1.6um min_width/min_spacing, a common rule of thumb to
# keep the field solver's outer boundary far enough from the top conductor
# to avoid truncation error). No PDK will specify this; adjust if solver
# runtime/accuracy tradeoffs call for it.
#
# PARSER QUIRK (verified against the real rcx::gen_solver_patterns parser,
# extprocess.cpp readDielectric): DIELECTRIC blocks MUST have one key/value
# pair per line. Cramming multiple fields onto a single line silently parses
# as epsilon=0/thickness=0 with no error -- confirmed by running
# gen_solver_patterns and inspecting process.out. CONDUCTOR blocks were
# never affected (always one field per line here).

CONDUCTOR M0 {
	distance	0.023
	thickness	0.024
	min_width	0.012
	min_spacing	0.012
	resistivity	0.179064
}

CONDUCTOR M1 {
	distance	0.024
	thickness	0.028
	min_width	0.014
	min_spacing	0.014
	resistivity	0.17150
}

CONDUCTOR M2 {
	distance	0.028
	thickness	0.024
	min_width	0.012
	min_spacing	0.012
	resistivity	0.179064
}

CONDUCTOR M3 {
	distance	0.024
	thickness	0.028
	min_width	0.014
	min_spacing	0.014
	resistivity	0.17150
}

CONDUCTOR M4 {
	distance	0.028
	thickness	0.042
	min_width	0.021
	min_spacing	0.021
	resistivity	0.147252
}

CONDUCTOR M5 {
	distance	0.042
	thickness	0.042
	min_width	0.021
	min_spacing	0.021
	resistivity	0.147252
}

CONDUCTOR M6 {
	distance	0.042
	thickness	0.076
	min_width	0.038
	min_spacing	0.038
	resistivity	0.076684
}

CONDUCTOR M7 {
	distance	0.076
	thickness	0.076
	min_width	0.038
	min_spacing	0.038
	resistivity	0.076684
}

CONDUCTOR M8 {
	distance	0.076
	thickness	0.076
	min_width	0.038
	min_spacing	0.038
	resistivity	0.076684
}

CONDUCTOR M9 {
	distance	0.076
	thickness	0.076
	min_width	0.038
	min_spacing	0.038
	resistivity	0.076684
}

CONDUCTOR M10 {
	distance	0.076
	thickness	0.112
	min_width	0.056
	min_spacing	0.056
	resistivity	0.046928
}

CONDUCTOR M11 {
	distance	0.112
	thickness	0.112
	min_width	0.056
	min_spacing	0.056
	resistivity	0.046928
}

CONDUCTOR M12 {
	distance	0.112
	thickness	0.112
	min_width	0.360
	min_spacing	0.360
	resistivity	0.025760
}

CONDUCTOR M13 {
	distance	0.112
	thickness	0.112
	min_width	0.360
	min_spacing	0.360
	resistivity	0.025760
}

CONDUCTOR RDL {
	distance	0.112
	thickness	0.5
	min_width	1.600
	min_spacing	1.600
	resistivity	0.005
}

DIELECTRIC M0_below_diel {
	epsilon 3.9
	thickness 0.023
	next_met 1
}

DIELECTRIC M0_fill_diel {
	epsilon 2.4
	thickness 0.024
	met 1
}

DIELECTRIC M1_gap_diel {
	epsilon 2.4
	thickness 0.024
	next_met 2
}

DIELECTRIC M1_fill_diel {
	epsilon 2.4
	thickness 0.028
	met 2
}

DIELECTRIC M2_gap_diel {
	epsilon 2.4
	thickness 0.028
	next_met 3
}

DIELECTRIC M2_fill_diel {
	epsilon 2.4
	thickness 0.024
	met 3
}

DIELECTRIC M3_gap_diel {
	epsilon 2.4
	thickness 0.024
	next_met 4
}

DIELECTRIC M3_fill_diel {
	epsilon 2.4
	thickness 0.028
	met 4
}

DIELECTRIC M4_gap_diel {
	epsilon 2.4
	thickness 0.028
	next_met 5
}

DIELECTRIC M4_fill_diel {
	epsilon 2.5
	thickness 0.042
	met 5
}

DIELECTRIC M5_gap_diel {
	epsilon 2.5
	thickness 0.042
	next_met 6
}

DIELECTRIC M5_fill_diel {
	epsilon 2.5
	thickness 0.042
	met 6
}

DIELECTRIC M6_gap_diel {
	epsilon 2.5
	thickness 0.042
	next_met 7
}

DIELECTRIC M6_fill_diel {
	epsilon 2.5
	thickness 0.076
	met 7
}

DIELECTRIC M7_gap_diel {
	epsilon 2.5
	thickness 0.076
	next_met 8
}

DIELECTRIC M7_fill_diel {
	epsilon 2.5
	thickness 0.076
	met 8
}

DIELECTRIC M8_gap_diel {
	epsilon 2.5
	thickness 0.076
	next_met 9
}

DIELECTRIC M8_fill_diel {
	epsilon 2.5
	thickness 0.076
	met 9
}

DIELECTRIC M9_gap_diel {
	epsilon 2.5
	thickness 0.076
	next_met 10
}

DIELECTRIC M9_fill_diel {
	epsilon 2.5
	thickness 0.076
	met 10
}

DIELECTRIC M10_gap_diel {
	epsilon 2.5
	thickness 0.076
	next_met 11
}

DIELECTRIC M10_fill_diel {
	epsilon 2.5
	thickness 0.112
	met 11
}

DIELECTRIC M11_gap_diel {
	epsilon 2.5
	thickness 0.112
	next_met 12
}

DIELECTRIC M11_fill_diel {
	epsilon 2.5
	thickness 0.112
	met 12
}

DIELECTRIC M12_gap_diel {
	epsilon 2.5
	thickness 0.112
	next_met 13
}

DIELECTRIC M12_fill_diel {
	epsilon 2.5
	thickness 0.112
	met 13
}

DIELECTRIC M13_gap_diel {
	epsilon 2.5
	thickness 0.112
	next_met 14
}

DIELECTRIC M13_fill_diel {
	epsilon 2.5
	thickness 0.112
	met 14
}

DIELECTRIC RDL_gap_diel {
	epsilon 2.5
	thickness 0.112
	next_met 15
}

DIELECTRIC RDL_fill_diel {
	epsilon 2.5
	thickness 0.5
	met 15
}

DIELECTRIC air_cap {
	epsilon 1.0
	thickness 16.0
}
