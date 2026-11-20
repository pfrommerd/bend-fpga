# LAWS.bend: what bend-fpga claims. Each import states its laws; PROOF.bend
# proves them all (`bend PROOF.bend` is the gate).
#
# - isa/lc4/LAWS.bend         the LC4 spec: decode inverts encode, and the
#                             privilege bit PSR[15] is unobservable
# - chips/lc4_single/LAWS.bend  the single-cycle chip implements LC4
# - chips/lc4_multi/LAWS.bend   the multi-cycle chip implements LC4

import Base
import ./isa/lc4/LAWS.bend as Lc4
import ./chips/lc4_single/LAWS.bend as Single
import ./chips/lc4_multi/LAWS.bend as Multi
