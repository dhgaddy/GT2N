# OpenRCX process-stack file for GT2N backside PDN metal (BPR -> BRDL)
#
# Same decomposition method as gt2n_process_frontside.pro (see that file's
# header for the full derivation and the bug it replaces). Difference: there
# is no backside section in qrc/GT2.ict (it only covers GATE..RDL), so this
# file's gaps are derived from nxtgrd/GT2.itf alone, using the formula
# GT2.ict proved correct on the frontside:
#
#   met_L          (L's own lateral fill) = L.THICKNESS              (epsilon = <L>_diel.ER)
#   next_met_(L+1) (real gap above L)     = <L>_diel.THICKNESS - L.THICKNESS   (epsilon = <L>_diel.ER)
#
# GT2N is BSPDN: the frontside BEOL (M0..RDL) and backside PDN metal
# (BPR..BRDL) are physically on opposite sides of the wafer, separated by
# nxtgrd/GT2.itf's standalone "BOX_diel" (buried oxide, THICKNESS=0.023
# ER=3.9) after wafer thinning. Each side is still solved as its own
# independent field-solver domain (no electrical coupling between them),
# mirroring how designs/gt2n/setRC_full.tcl treats the two stacks as
# independent -layer RC groups -- using BOX_diel below only sets BPR's own
# local distance-to-reference-plane to a physically real value instead of 0,
# exactly as gt2n_process_frontside.pro does for M0 using VSD_diel (the same
# 0.023/ER=3.9 values, for the same kind of device-adjacent interface).
#
# BPR -> BM1 gap: applying the formula gives next_met_2 = BPR_diel.THICKNESS
# (0.090) - BPR.THICKNESS (0.090) = 0.0 exactly -- BPR_diel's entire
# thickness is consumed by BPR's own lateral fill, leaving no separate ILD
# gap before BM1. This is the one result in this file not independently
# cross-checked the way the frontside gaps were against GT2.ict (no backside
# absolute-height source exists in this repo). Confirmed to use as-is: no
# DIELECTRIC block is emitted for this gap (a zero-thickness slab is
# degenerate geometry for the field solver); CONDUCTOR BM1's distance is set
# to 0.0 directly, placing it immediately above BPR's own body.
#
# BRDL's own-name dielectric does NOT come out to zero gap-above the way
# RDL's did on the frontside: BRDL_diel.THICKNESS (0.612) - BRDL.THICKNESS
# (0.5) = 0.112, matching the same 0.112 gap value seen between every other
# backside metal pair (BM2-BM3, BM3-BM4, BM4-BRDL) -- read as a real
# passivation/cap dielectric above BRDL before backside air begins, not a
# leftover artifact. Kept as a distinct, untagged capping DIELECTRIC block
# (BRDL_cap_diel) between BRDL's own fill and air_cap, rather than discarded,
# since GT2.itf gives this value directly and it is consistent with the rest
# of the stack's pattern.
#
# Capping dielectric above BRDL_cap_diel: same reasoning as the frontside
# file's air_cap -- epsilon=1.0 (air) is sourced from GT2.ict's "process GT2
# { background_dielectric_constant 1.0 }" (Cadence QRC's default for the
# region above the last declared layer), matching StarRC/GT2.itf's silent
# air-above-top convention. BRDL shares RDL's 1.6um min_width/min_spacing,
# so the same ~10x-pitch 16.0um boundary thickness applies (a solver
# boundary-size choice, not a PDK value).

CONDUCTOR BPR {
	distance	0.023
	thickness	0.090
	min_width	0.032
	min_spacing	0.112
	resistivity	0.070002
}

CONDUCTOR BM1 {
	distance	0.0
	thickness	0.112
	min_width	0.056
	min_spacing	0.056
	resistivity	0.046928
}

CONDUCTOR BM2 {
	distance	0.300
	thickness	0.112
	min_width	0.056
	min_spacing	0.056
	resistivity	0.046928
}

CONDUCTOR BM3 {
	distance	0.112
	thickness	0.112
	min_width	0.360
	min_spacing	0.360
	resistivity	0.025760
}

CONDUCTOR BM4 {
	distance	0.112
	thickness	0.112
	min_width	0.360
	min_spacing	0.360
	resistivity	0.025760
}

CONDUCTOR BRDL {
	distance	0.112
	thickness	0.5
	min_width	1.600
	min_spacing	1.600
	resistivity	0.005
}

DIELECTRIC BPR_below_diel {
	epsilon 3.9
	thickness 0.023
	next_met 1
}

DIELECTRIC BPR_fill_diel {
	epsilon 3.9
	thickness 0.090
	met 1
}

DIELECTRIC BM1_fill_diel {
	epsilon 3.9
	thickness 0.112
	met 2
}

DIELECTRIC BM2_gap_diel {
	epsilon 3.9
	thickness 0.300
	next_met 3
}

DIELECTRIC BM2_fill_diel {
	epsilon 2.5
	thickness 0.112
	met 3
}

DIELECTRIC BM3_gap_diel {
	epsilon 2.5
	thickness 0.112
	next_met 4
}

DIELECTRIC BM3_fill_diel {
	epsilon 2.5
	thickness 0.112
	met 4
}

DIELECTRIC BM4_gap_diel {
	epsilon 2.5
	thickness 0.112
	next_met 5
}

DIELECTRIC BM4_fill_diel {
	epsilon 2.5
	thickness 0.112
	met 5
}

DIELECTRIC BRDL_gap_diel {
	epsilon 2.5
	thickness 0.112
	next_met 6
}

DIELECTRIC BRDL_fill_diel {
	epsilon 2.5
	thickness 0.5
	met 6
}

DIELECTRIC BRDL_cap_diel {
	epsilon 2.5
	thickness 0.112
}

DIELECTRIC air_cap {
	epsilon 1.0
	thickness 16.0
}
