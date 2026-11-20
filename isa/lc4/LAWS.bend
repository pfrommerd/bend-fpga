# isa/lc4/LAWS.bend: the laws of the LC4 spec. Proven in PROOF.bend.

import Base
import ../../hdl/bits.bend as B
import ../../hdl/mem.bend as M
import ./spec.bend as S

# LAW: decoding inverts encoding: every instruction has an encoding, and
# the decoder reads back exactly the instruction (fields included)
law decode_encode:
  for i: S.Insn
  {S.decode(S.encode(i)) == Some{i} : Maybe<&2, S.Insn>}

# LAW: PSR[15] is unobservable: with no memory protection, the privilege
# bit never changes what a step computes, only the privilege bit itself.
# So a processor that drops it still implements LC4 up to erase.
law priv_unobservable:
  for s: S.Machine
  {S.erase_m(S.step(s)) == S.erase_m(S.step(S.erase(s))) : Maybe<&2, S.Machine>}
