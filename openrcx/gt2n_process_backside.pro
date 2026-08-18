# OpenRCX process-stack file for GT2N backside PDN metal (BPR -> BRDL)
#
# Same translation rule as gt2n_process_frontside.pro (see that file's header
# for the full derivation). GT2N is BSPDN: the frontside BEOL (M0..RDL) and
# backside PDN metal (BPR..BRDL) are physically on opposite sides of the
# wafer, separated by nxtgrd/GT2.itf's standalone "BOX_diel" (buried oxide,
# THICKNESS=0.023 ER=3.9) after wafer thinning. BOX_diel has no CONDUCTOR of
# its own and is NOT part of either stack -- each side is solved as its own
# independent field-solver domain referenced to its own local ground plane
# (frontside: substrate; backside: the thinned-Si/BOX interface). This
# mirrors how designs/gt2n/setRC_full.tcl treats the two stacks as
# independent -layer RC groups.
#
# Capping dielectric above the topmost backside conductor (BRDL): same
# reasoning as the frontside file's air_cap -- epsilon=1.0 (air) is sourced
# from GT2.ict's "background_dielectric_constant 1.0" (Cadence QRC's default
# for the region above the last declared layer), matching StarRC/GT2.itf's
# silent air-above-top convention. BRDL shares RDL's 1.6um min_width/
# min_spacing, so the same ~10x-pitch 16.0um boundary thickness applies (a
# solver boundary-size choice, not a PDK value).

CONDUCTOR BPR {
	distance	0.090
	thickness	0.090
	min_width	0.032
	min_spacing	0.112
	resistivity	0.070002
}

CONDUCTOR BM1 {
	distance	0.412
	thickness	0.112
	min_width	0.056
	min_spacing	0.056
	resistivity	0.046928
}

CONDUCTOR BM2 {
	distance	0.224
	thickness	0.112
	min_width	0.056
	min_spacing	0.056
	resistivity	0.046928
}

CONDUCTOR BM3 {
	distance	0.224
	thickness	0.112
	min_width	0.360
	min_spacing	0.360
	resistivity	0.025760
}

CONDUCTOR BM4 {
	distance	0.224
	thickness	0.112
	min_width	0.360
	min_spacing	0.360
	resistivity	0.025760
}

CONDUCTOR BRDL {
	distance	0.612
	thickness	0.5
	min_width	1.600
	min_spacing	1.600
	resistivity	0.005
}

DIELECTRIC BPR_diel {
	epsilon 3.9
	thickness 0.090
	next_met 1
}

DIELECTRIC BM1_diel {
	epsilon 3.9
	thickness 0.412
	next_met 2
}

DIELECTRIC BM2_diel {
	epsilon 2.5
	thickness 0.224
	next_met 3
}

DIELECTRIC BM3_diel {
	epsilon 2.5
	thickness 0.224
	next_met 4
}

DIELECTRIC BM4_diel {
	epsilon 2.5
	thickness 0.224
	next_met 5
}

DIELECTRIC BRDL_diel {
	epsilon 2.5
	thickness 0.612
	next_met 6
}

DIELECTRIC air_cap {
	epsilon 1.0
	thickness 16.0
}
