# isa/lc4/spec.bend: the LC4 instruction set (UPenn CIS 240/371/5710).
#
# Reference: https://www.cis.upenn.edu/~cis5710/spring2022/lc4.html
#
# The machine: a 16-bit PC, the NZP condition codes, the privilege bit
# PSR[15], eight 16-bit registers and one 64K-word memory holding both code
# and data. One step fetches mem[PC], decodes it and executes it. An
# instruction with an unused opcode (0011, 1011, 1110) does not decode, and
# the machine has no step from it.
#
# Choices the reference leaves open, fixed here:
# - DIV and MOD by zero write 0 (as PennSim and the CIS 371 traces do).
# - CMP compares the true values ("sign(Rs - Rt)" without wrap-around).
# - Every instruction that writes a register sets NZP from the value
#   written, including JSR, JSRR and TRAP (which write R7).
# - Memory protection (user code touching OS space) is not modelled, so
#   PSR[15] never changes what a program computes (see LAWS.bend).

import Base
import ../../hdl/bits.bend as B
import ../../hdl/mem.bend as M

# Instructions
# ------------

# a decoded instruction: d is the destination, s and t the sources; every
# immediate keeps its encoded width
type Insn is Data:
  BR{n: Bool, z: Bool, p: Bool, off: Word(9n)}
  ADD{d: Word(3n), s: Word(3n), t: Word(3n)}
  MUL{d: Word(3n), s: Word(3n), t: Word(3n)}
  SUB{d: Word(3n), s: Word(3n), t: Word(3n)}
  DIV{d: Word(3n), s: Word(3n), t: Word(3n)}
  ADDI{d: Word(3n), s: Word(3n), imm: Word(5n)}
  CMP{s: Word(3n), t: Word(3n)}
  CMPU{s: Word(3n), t: Word(3n)}
  CMPI{s: Word(3n), imm: Word(7n)}
  CMPIU{s: Word(3n), imm: Word(7n)}
  JSRR{s: Word(3n)}
  JSR{imm: Word(11n)}
  AND{d: Word(3n), s: Word(3n), t: Word(3n)}
  NOT{d: Word(3n), s: Word(3n)}
  OR{d: Word(3n), s: Word(3n), t: Word(3n)}
  XOR{d: Word(3n), s: Word(3n), t: Word(3n)}
  ANDI{d: Word(3n), s: Word(3n), imm: Word(5n)}
  LDR{d: Word(3n), s: Word(3n), off: Word(6n)}
  STR{t: Word(3n), s: Word(3n), off: Word(6n)}
  RTI{}
  CONST{d: Word(3n), imm: Word(9n)}
  SLL{d: Word(3n), s: Word(3n), amt: Word(4n)}
  SRA{d: Word(3n), s: Word(3n), amt: Word(4n)}
  SRL{d: Word(3n), s: Word(3n), amt: Word(4n)}
  MOD{d: Word(3n), s: Word(3n), t: Word(3n)}
  JMPR{s: Word(3n)}
  JMP{off: Word(11n)}
  HICONST{d: Word(3n), imm: Word(8n)}
  TRAP{vec: Word(8n)}

# Decoding
# --------

# the fields at their places in an instruction word i (Verilog i[hi:lo])
def f_d(+i: Word(16n)) -> Word(3n):
  B.bits(16n, 11n, 9n, i)

def f_s(+i: Word(16n)) -> Word(3n):
  B.bits(16n, 8n, 6n, i)

def f_t(+i: Word(16n)) -> Word(3n):
  B.bits(16n, 2n, 0n, i)

# insn[5] picks the immediate form first, so its immediate's bits are
# never inspected
def dec.arith.reg(sub: Word(2n), +i: Word(16n)) -> Insn:
  match sub:
    case WCon{False{}, WCon{False{}, WNil{}}}:
      ADD{f_d(i), f_s(i), f_t(i)}
    case WCon{True{}, WCon{False{}, WNil{}}}:
      MUL{f_d(i), f_s(i), f_t(i)}
    case WCon{False{}, WCon{True{}, WNil{}}}:
      SUB{f_d(i), f_s(i), f_t(i)}
    case WCon{True{}, WCon{True{}, WNil{}}}:
      DIV{f_d(i), f_s(i), f_t(i)}

def dec.arith(imm: Bool, +i: Word(16n)) -> Insn:
  match imm:
    case True{}:
      ADDI{f_d(i), f_s(i), B.bits(16n, 4n, 0n, i)}
    case False{}:
      dec.arith.reg(B.bits(16n, 4n, 3n, i), i)

def dec.cmp(sub: Word(2n), +i: Word(16n)) -> Insn:
  match sub:
    case WCon{False{}, WCon{False{}, WNil{}}}:
      CMP{f_d(i), f_t(i)}
    case WCon{True{}, WCon{False{}, WNil{}}}:
      CMPU{f_d(i), f_t(i)}
    case WCon{False{}, WCon{True{}, WNil{}}}:
      CMPI{f_d(i), B.bits(16n, 6n, 0n, i)}
    case WCon{True{}, WCon{True{}, WNil{}}}:
      CMPIU{f_d(i), B.bits(16n, 6n, 0n, i)}

# insn[5] picks the immediate form first, so its immediate's bits are
# never inspected
def dec.logic.reg(sub: Word(2n), +i: Word(16n)) -> Insn:
  match sub:
    case WCon{False{}, WCon{False{}, WNil{}}}:
      AND{f_d(i), f_s(i), f_t(i)}
    case WCon{True{}, WCon{False{}, WNil{}}}:
      NOT{f_d(i), f_s(i)}
    case WCon{False{}, WCon{True{}, WNil{}}}:
      OR{f_d(i), f_s(i), f_t(i)}
    case WCon{True{}, WCon{True{}, WNil{}}}:
      XOR{f_d(i), f_s(i), f_t(i)}

def dec.logic(imm: Bool, +i: Word(16n)) -> Insn:
  match imm:
    case True{}:
      ANDI{f_d(i), f_s(i), B.bits(16n, 4n, 0n, i)}
    case False{}:
      dec.logic.reg(B.bits(16n, 4n, 3n, i), i)

def dec.shift(sub: Word(2n), +i: Word(16n)) -> Insn:
  match sub:
    case WCon{False{}, WCon{False{}, WNil{}}}:
      SLL{f_d(i), f_s(i), B.bits(16n, 3n, 0n, i)}
    case WCon{True{}, WCon{False{}, WNil{}}}:
      SRA{f_d(i), f_s(i), B.bits(16n, 3n, 0n, i)}
    case WCon{False{}, WCon{True{}, WNil{}}}:
      SRL{f_d(i), f_s(i), B.bits(16n, 3n, 0n, i)}
    case WCon{True{}, WCon{True{}, WNil{}}}:
      MOD{f_d(i), f_s(i), f_t(i)}

# JSR/JSRR and JMP/JMPR share an opcode; bit 11 picks the immediate form
def dec.jsr(imm: Bool, +i: Word(16n)) -> Insn:
  match imm:
    case True{}:
      JSR{B.bits(16n, 10n, 0n, i)}
    case False{}:
      JSRR{f_s(i)}

def dec.jmp(imm: Bool, +i: Word(16n)) -> Insn:
  match imm:
    case True{}:
      JMP{B.bits(16n, 10n, 0n, i)}
    case False{}:
      JMPR{f_s(i)}

def dec.op(op: Word(4n), +i: Word(16n)) -> Maybe<&2, Insn>:
  match op:
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      Some{BR{B.bit(11n, 16n, i), B.bit(10n, 16n, i), B.bit(9n, 16n, i), B.bits(16n, 8n, 0n, i)}}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      Some{dec.arith(B.bit(5n, 16n, i), i)}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      Some{dec.cmp(B.bits(16n, 8n, 7n, i), i)}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{False{}, WNil{}}}}}:
      None{}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      Some{dec.jsr(B.bit(11n, 16n, i), i)}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      Some{dec.logic(B.bit(5n, 16n, i), i)}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      Some{LDR{f_d(i), f_s(i), B.bits(16n, 5n, 0n, i)}}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{False{}, WNil{}}}}}:
      Some{STR{f_d(i), f_s(i), B.bits(16n, 5n, 0n, i)}}
    case WCon{False{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      Some{RTI{}}
    case WCon{True{}, WCon{False{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      Some{CONST{f_d(i), B.bits(16n, 8n, 0n, i)}}
    case WCon{False{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      Some{dec.shift(B.bits(16n, 5n, 4n, i), i)}
    case WCon{True{}, WCon{True{}, WCon{False{}, WCon{True{}, WNil{}}}}}:
      None{}
    case WCon{False{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      Some{dec.jmp(B.bit(11n, 16n, i), i)}
    case WCon{True{}, WCon{False{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      Some{HICONST{f_d(i), B.bits(16n, 7n, 0n, i)}}
    case WCon{False{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      None{}
    case WCon{True{}, WCon{True{}, WCon{True{}, WCon{True{}, WNil{}}}}}:
      Some{TRAP{B.bits(16n, 7n, 0n, i)}}

# the instruction an encoded word holds, if any
def decode(+i: Word(16n)) -> Maybe<&2, Insn>:
  dec.op(B.bits(16n, 15n, 12n, i), i)

# Encoding
# --------

# Verilog's {hi, lo}
def hl(-m: Nat, n: Nat, hi: Word(m), lo: Word(n)) -> Word(Nat.add(n, m)):
  B.cat(n, m, lo, hi)

def k(n: Nat, +v: Nat) -> Word(n):
  B.of_nat(n, v)

def b(x: Bool) -> Word(1n):
  B.bit1(x)

# the instruction word of i; every don't-care bit is 0
def encode(i: Insn) -> Word(16n):
  match i:
    case BR{n, z, p, off}:
      hl(4n, 12n, k(4n, 0n), hl(1n, 11n, b(n), hl(1n, 10n, b(z), hl(1n, 9n, b(p), off))))
    case ADD{d, s, t}:
      hl(4n, 12n, k(4n, 1n), hl(3n, 9n, d, hl(3n, 6n, s, hl(3n, 3n, k(3n, 0n), t))))
    case MUL{d, s, t}:
      hl(4n, 12n, k(4n, 1n), hl(3n, 9n, d, hl(3n, 6n, s, hl(3n, 3n, k(3n, 1n), t))))
    case SUB{d, s, t}:
      hl(4n, 12n, k(4n, 1n), hl(3n, 9n, d, hl(3n, 6n, s, hl(3n, 3n, k(3n, 2n), t))))
    case DIV{d, s, t}:
      hl(4n, 12n, k(4n, 1n), hl(3n, 9n, d, hl(3n, 6n, s, hl(3n, 3n, k(3n, 3n), t))))
    case ADDI{d, s, imm}:
      hl(4n, 12n, k(4n, 1n), hl(3n, 9n, d, hl(3n, 6n, s, hl(1n, 5n, k(1n, 1n), imm))))
    case CMP{s, t}:
      hl(4n, 12n, k(4n, 2n), hl(3n, 9n, s, hl(2n, 7n, k(2n, 0n), hl(4n, 3n, k(4n, 0n), t))))
    case CMPU{s, t}:
      hl(4n, 12n, k(4n, 2n), hl(3n, 9n, s, hl(2n, 7n, k(2n, 1n), hl(4n, 3n, k(4n, 0n), t))))
    case CMPI{s, imm}:
      hl(4n, 12n, k(4n, 2n), hl(3n, 9n, s, hl(2n, 7n, k(2n, 2n), imm)))
    case CMPIU{s, imm}:
      hl(4n, 12n, k(4n, 2n), hl(3n, 9n, s, hl(2n, 7n, k(2n, 3n), imm)))
    case JSRR{s}:
      hl(4n, 12n, k(4n, 4n), hl(3n, 9n, k(3n, 0n), hl(3n, 6n, s, k(6n, 0n))))
    case JSR{imm}:
      hl(4n, 12n, k(4n, 4n), hl(1n, 11n, k(1n, 1n), imm))
    case AND{d, s, t}:
      hl(4n, 12n, k(4n, 5n), hl(3n, 9n, d, hl(3n, 6n, s, hl(3n, 3n, k(3n, 0n), t))))
    case NOT{d, s}:
      hl(4n, 12n, k(4n, 5n), hl(3n, 9n, d, hl(3n, 6n, s, hl(3n, 3n, k(3n, 1n), k(3n, 0n)))))
    case OR{d, s, t}:
      hl(4n, 12n, k(4n, 5n), hl(3n, 9n, d, hl(3n, 6n, s, hl(3n, 3n, k(3n, 2n), t))))
    case XOR{d, s, t}:
      hl(4n, 12n, k(4n, 5n), hl(3n, 9n, d, hl(3n, 6n, s, hl(3n, 3n, k(3n, 3n), t))))
    case ANDI{d, s, imm}:
      hl(4n, 12n, k(4n, 5n), hl(3n, 9n, d, hl(3n, 6n, s, hl(1n, 5n, k(1n, 1n), imm))))
    case LDR{d, s, off}:
      hl(4n, 12n, k(4n, 6n), hl(3n, 9n, d, hl(3n, 6n, s, off)))
    case STR{t, s, off}:
      hl(4n, 12n, k(4n, 7n), hl(3n, 9n, t, hl(3n, 6n, s, off)))
    case RTI{}:
      hl(4n, 12n, k(4n, 8n), k(12n, 0n))
    case CONST{d, imm}:
      hl(4n, 12n, k(4n, 9n), hl(3n, 9n, d, imm))
    case SLL{d, s, amt}:
      hl(4n, 12n, k(4n, 10n), hl(3n, 9n, d, hl(3n, 6n, s, hl(2n, 4n, k(2n, 0n), amt))))
    case SRA{d, s, amt}:
      hl(4n, 12n, k(4n, 10n), hl(3n, 9n, d, hl(3n, 6n, s, hl(2n, 4n, k(2n, 1n), amt))))
    case SRL{d, s, amt}:
      hl(4n, 12n, k(4n, 10n), hl(3n, 9n, d, hl(3n, 6n, s, hl(2n, 4n, k(2n, 2n), amt))))
    case MOD{d, s, t}:
      hl(4n, 12n, k(4n, 10n), hl(3n, 9n, d, hl(3n, 6n, s, hl(3n, 3n, k(3n, 6n), t))))
    case JMPR{s}:
      hl(4n, 12n, k(4n, 12n), hl(3n, 9n, k(3n, 0n), hl(3n, 6n, s, k(6n, 0n))))
    case JMP{off}:
      hl(4n, 12n, k(4n, 12n), hl(1n, 11n, k(1n, 1n), off))
    case HICONST{d, imm}:
      hl(4n, 12n, k(4n, 13n), hl(3n, 9n, d, hl(1n, 8n, k(1n, 0n), imm)))
    case TRAP{vec}:
      hl(4n, 12n, k(4n, 15n), hl(4n, 8n, k(4n, 0n), vec))

# Machine state
# -------------

# nzp is Verilog's nzp[2:0]: bit 2 N, bit 1 Z, bit 0 P; priv is PSR[15]
type Machine is Data:
  Machine{pc: Word(16n), nzp: Word(3n), priv: Bool, regs: M.Mem<16n>, mem: M.Mem<16n>}

# what one instruction does, as a record of its writes (what the CIS 371
# testbench checks per instruction): a register write, an NZP write, a
# memory access, and the next PC and privilege bit. Unused fields are 0.
# mem_val is the word stored, or the word loaded.
type Retire is Data:
  Retire{rf_we: Bool, rd: Word(3n), rd_val: Word(16n), nzp_we: Bool, nzp: Word(3n), mem_we: Bool, mem_addr: Word(16n), mem_val: Word(16n), pc: Word(16n), priv: Bool}

# the register file read port: regs[r]
def reg(+regs: M.Mem<16n>, r: Word(3n)) -> Word(16n):
  M.get(16n, 3n, r, regs)

def r7() -> Word(3n):
  B.of_nat(3n, 7n)

# the NZP bits, nzp[2:0] = {N, Z, P}
def nzp3(n: Bool, z: Bool, p: Bool) -> Word(3n):
  WCon{p, WCon{z, WCon{n, WNil{}}}}

# the NZP bits for a value written to a register: N when it is negative
# (its sign bit, bit 15, is set), Z when it is 0, P otherwise
def nzp_of(+v: Word(16n)) -> Word(3n):
  +n = B.bit(15n, 16n, v)
  +z = B.eq(16n, v, B.of_nat(16n, 0n))
  nzp3(n, z, Bool.not(Bool.or(n, z)))

# the NZP bits for a comparison of a with b: N when a < b, Z when a == b,
# P when a > b; signed compares two's complement values
def nzp_cmp(+a: Word(16n), +b: Word(16n), signed: Bool) -> Word(3n):
  match signed:
    case True{}:
      nzp3(Cmp.is_lt(B.scmp(16n, a, b)), B.eq(16n, a, b), Cmp.is_gt(B.scmp(16n, a, b)))
    case False{}:
      nzp3(Cmp.is_lt(B.ucmp(16n, a, b)), B.eq(16n, a, b), Cmp.is_gt(B.ucmp(16n, a, b)))

# Retire records
# --------------

# writes v to register d, sets NZP from v, then goes to pc
def wr(d: Word(3n), +v: Word(16n), pc: Word(16n), priv: Bool) -> Retire:
  Retire{True{}, d, v, True{}, nzp_of(v), False{}, B.zero(16n), B.zero(16n), pc, priv}

# sets NZP to cc, then goes to pc
def setcc(cc: Word(3n), pc: Word(16n), priv: Bool) -> Retire:
  Retire{False{}, B.zero(3n), B.zero(16n), True{}, cc, False{}, B.zero(16n), B.zero(16n), pc, priv}

# writes nothing, goes to pc
def jump(pc: Word(16n), priv: Bool) -> Retire:
  Retire{False{}, B.zero(3n), B.zero(16n), False{}, B.zero(3n), False{}, B.zero(16n), B.zero(16n), pc, priv}

# loads mem[addr] into d
def load(d: Word(3n), +addr: Word(16n), +mem: M.Mem<16n>, pc: Word(16n), priv: Bool) -> Retire:
  +v = M.get(16n, 16n, addr, mem)
  Retire{True{}, d, v, True{}, nzp_of(v), False{}, addr, v, pc, priv}

# stores v to mem[addr]
def store(addr: Word(16n), v: Word(16n), pc: Word(16n), priv: Bool) -> Retire:
  Retire{False{}, B.zero(3n), B.zero(16n), False{}, B.zero(3n), True{}, addr, v, pc, priv}

# Execution
# ---------

def sx(+n: Nat, +w: Word(n)) -> Word(16n):
  B.sext(n, 16n, w)

def zx(n: Nat, w: Word(n)) -> Word(16n):
  B.zext(n, 16n, w)

# a branch is taken when one of the NZP bits it names is set:
# (nzp & {n, z, p}) != 0
def taken(n: Bool, z: Bool, p: Bool, cc: Word(3n)) -> Bool:
  Bool.not(B.is_zero(3n, B.and(3n, cc, nzp3(n, z, p))))

# the effect of instruction i on the machine (pc, nzp, priv, regs, mem);
# pc1 is pc + 1
def exec.go(i: Insn, +pc: Word(16n), +pc1: Word(16n), +nzp: Word(3n), +priv: Bool, +regs: M.Mem<16n>, +mem: M.Mem<16n>) -> Retire:
  match i:
    case BR{n, z, p, off}:
      jump(B.pick(16n, taken(n, z, p, nzp), B.add(16n, pc1, sx(9n, off)), pc1), priv)
    case ADD{d, s, t}:
      wr(d, B.add(16n, reg(regs, s), reg(regs, t)), pc1, priv)
    case MUL{d, s, t}:
      wr(d, B.mul(16n, reg(regs, s), reg(regs, t)), pc1, priv)
    case SUB{d, s, t}:
      wr(d, B.sub(16n, reg(regs, s), reg(regs, t)), pc1, priv)
    case DIV{d, s, t}:
      wr(d, B.udiv(16n, reg(regs, s), reg(regs, t)), pc1, priv)
    case ADDI{d, s, imm}:
      wr(d, B.add(16n, reg(regs, s), sx(5n, imm)), pc1, priv)
    case CMP{s, t}:
      setcc(nzp_cmp(reg(regs, s), reg(regs, t), True{}), pc1, priv)
    case CMPU{s, t}:
      setcc(nzp_cmp(reg(regs, s), reg(regs, t), False{}), pc1, priv)
    case CMPI{s, imm}:
      setcc(nzp_cmp(reg(regs, s), sx(7n, imm), True{}), pc1, priv)
    case CMPIU{s, imm}:
      setcc(nzp_cmp(reg(regs, s), zx(7n, imm), False{}), pc1, priv)
    case JSRR{s}:
      wr(r7(), pc1, reg(regs, s), priv)
    case JSR{imm}:
      # (PC & 0x8000) | (IMM11 << 4)
      wr(r7(), pc1, B.cat(4n, 12n, B.zero(4n), B.cat(11n, 1n, imm, B.bit1(B.msb(16n, pc)))), priv)
    case AND{d, s, t}:
      wr(d, B.and(16n, reg(regs, s), reg(regs, t)), pc1, priv)
    case NOT{d, s}:
      wr(d, B.not(16n, reg(regs, s)), pc1, priv)
    case OR{d, s, t}:
      wr(d, B.or(16n, reg(regs, s), reg(regs, t)), pc1, priv)
    case XOR{d, s, t}:
      wr(d, B.xor(16n, reg(regs, s), reg(regs, t)), pc1, priv)
    case ANDI{d, s, imm}:
      wr(d, B.and(16n, reg(regs, s), sx(5n, imm)), pc1, priv)
    case LDR{d, s, off}:
      load(d, B.add(16n, reg(regs, s), sx(6n, off)), mem, pc1, priv)
    case STR{t, s, off}:
      store(B.add(16n, reg(regs, s), sx(6n, off)), reg(regs, t), pc1, priv)
    case RTI{}:
      jump(reg(regs, r7()), False{})
    case CONST{d, imm}:
      wr(d, sx(9n, imm), pc1, priv)
    case SLL{d, s, amt}:
      wr(d, B.shl_by(B.to_nat(4n, amt), 16n, reg(regs, s)), pc1, priv)
    case SRA{d, s, amt}:
      wr(d, B.sra_by(B.to_nat(4n, amt), 16n, reg(regs, s)), pc1, priv)
    case SRL{d, s, amt}:
      wr(d, B.srl_by(B.to_nat(4n, amt), 16n, reg(regs, s)), pc1, priv)
    case MOD{d, s, t}:
      wr(d, B.umod(16n, reg(regs, s), reg(regs, t)), pc1, priv)
    case JMPR{s}:
      jump(reg(regs, s), priv)
    case JMP{off}:
      jump(B.add(16n, pc1, sx(11n, off)), priv)
    case HICONST{d, imm}:
      # (Rd & 0xFF) | (UIMM8 << 8)
      +rd = d
      wr(rd, B.cat(8n, 8n, B.bits(16n, 7n, 0n, reg(regs, rd)), imm), pc1, priv)
    case TRAP{vec}:
      # 0x8000 | UIMM8
      wr(r7(), pc1, B.cat(8n, 8n, vec, B.cat(7n, 1n, B.zero(7n), B.bit1(True{}))), True{})

def exec(i: Insn, +pc: Word(16n), +nzp: Word(3n), +priv: Bool, +regs: M.Mem<16n>, +mem: M.Mem<16n>) -> Retire:
  exec.go(i, pc, B.add(16n, pc, B.of_nat(16n, 1n)), nzp, priv, regs, mem)

# the machine after the writes of r
def apply(s: Machine, r: Retire) -> Machine:
  match s:
    case Machine{pc, nzp, priv, regs, mem}:
      match r:
        case Retire{rf_we, rd, rd_val, nzp_we, nzp2, mem_we, mem_addr, mem_val, pc2, priv2}:
          Machine{pc2, B.pick(3n, nzp_we, nzp2, nzp), priv2, M.write(16n, rf_we, 3n, rd, rd_val, regs), M.write(16n, mem_we, 16n, mem_addr, mem_val, mem)}

def retire.go(mi: Maybe<&2, Insn>, +pc: Word(16n), +nzp: Word(3n), +priv: Bool, +regs: M.Mem<16n>, +mem: M.Mem<16n>) -> Maybe<&2, Retire>:
  match mi:
    case None{}:
      None{}
    case Some{i}:
      Some{exec(i, pc, nzp, priv, regs, mem)}

# the writes of the instruction at the PC; None when it does not decode
def retire(+s: Machine) -> Maybe<&2, Retire>:
  match s:
    case Machine{pc, nzp, priv, regs, mem}:
      retire.go(decode(M.get(16n, 16n, pc, mem)), pc, nzp, priv, regs, mem)

def step.go(+s: Machine, r: Maybe<&2, Retire>) -> Maybe<&2, Machine>:
  match r:
    case None{}:
      None{}
    case Some{x}:
      Some{apply(s, x)}

# one instruction: the next machine, or None at an undecodable instruction
def step(+s: Machine) -> Maybe<&2, Machine>:
  step.go(s, retire(s))

# Privilege
# ---------

# the machine with PSR[15] cleared: what a processor without the privilege
# bit holds (LAWS.bend proves no step can tell the difference)
def erase(s: Machine) -> Machine:
  match s:
    case Machine{pc, nzp, priv, regs, mem}:
      Machine{pc, nzp, False{}, regs, mem}

def erase_m(m: Maybe<&2, Machine>) -> Maybe<&2, Machine>:
  match m:
    case None{}:
      None{}
    case Some{x}:
      Some{erase(x)}

# Implementations
# ---------------

# Some{x} where the spec steps, None where it does not: what a processor
# implementing LC4 must reach in a step that ends at x
def when(m: Maybe<&2, Machine>, x: Machine) -> Maybe<&2, Machine>:
  match m:
    case None{}:
      None{}
    case Some{_}:
      Some{x}
