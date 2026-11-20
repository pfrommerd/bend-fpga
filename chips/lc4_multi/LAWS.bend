# chips/lc4_multi/LAWS.bend: the multi-cycle processor implements LC4.
# Proven in PROOF.bend.

import Base
import ../../hdl/mem.bend as M
import ../../isa/lc4/spec.bend as S
import ./chip.bend as C

# LAW: two clock cycles from a FETCH state are one LC4 instruction. From
# any PC, NZP bits, registers, memory, and whatever the instruction register
# still holds, wherever the spec takes a step, FETCH then EXECUTE reach
# exactly the machine the spec does, back in a FETCH state.
law implements_lc4:
  for +pc: Word(16n)
  for +nzp: Word(3n)
  for +rf: M.Mem<16n>
  for -ir: Word(16n)
  for +mem: M.Mem<16n>
  {S.erase_m(S.step(S.Machine{pc, nzp, False{}, rf, mem}))
    == S.when(S.step(S.Machine{pc, nzp, False{}, rf, mem}), C.abs(C.step2(C.State{pc, nzp, rf, False{}, ir}, mem))) : Maybe<&2, S.Machine>}
