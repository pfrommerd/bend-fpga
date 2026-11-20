# chips/lc4_single/LAWS.bend: the single-cycle processor implements LC4.
# Proven in PROOF.bend.

import Base
import ../../hdl/mem.bend as M
import ../../isa/lc4/spec.bend as S
import ./chip.bend as C

# LAW: one clock cycle is one LC4 instruction. From any processor state
# (PC, NZP, registers) and memory, wherever the spec takes a step (the
# instruction at the PC decodes), the cycle reaches exactly the machine the
# spec does: the same PC, NZP bits, registers and memory.
law implements_lc4:
  for +pc: Word(16n)
  for +nzp: Word(3n)
  for +rf: M.Mem<16n>
  for +mem: M.Mem<16n>
  {S.erase_m(S.step(S.Machine{pc, nzp, False{}, rf, mem}))
    == S.when(S.step(S.Machine{pc, nzp, False{}, rf, mem}), C.abs(C.step(C.State{pc, nzp, rf}, mem))) : Maybe<&2, S.Machine>}
