# chips/lc4_multi/chip.bend: a multi-cycle LC4 processor, in the DSL.
#
# Two cycles per instruction. FETCH latches the word at the PC into the
# instruction register and changes nothing else; EXECUTE runs the datapath
# of chips/lc4_single on the instruction register and commits its writes.
# The instruction memory is read only in FETCH, so EXECUTE's instruction
# no longer depends on the memory port, as with a real fetch stage. The
# testbench sees FETCH as a stall cycle (test_stall = 2).
#
# LAWS.bend states that from every FETCH state, two cycles perform exactly
# one LC4 instruction.

import Base
import ../../hdl/bits.bend as B
import ../../hdl/mem.bend as M
import ../../hdl/dsl.bend as D
import ../../hdl/verilog/ast.bend as A
import ../../isa/lc4/spec.bend as S
import ../lc4_single/chip.bend as Single

# The processor as a Bend function
# --------------------------------

# exec: the cycle executes (else it fetches); ir: the instruction register
type State is Data:
  State{pc: Word(16n), nzp: Word(3n), rf: M.Mem<16n>, exec: Bool, ir: Word(16n)}

def with_phase(sm: Single.State & M.Mem<16n>, +ir: Word(16n)) -> State & M.Mem<16n>:
  (s, mem) = sm
  match s:
    case Single.State{pc, nzp, rf}:
      (State{pc, nzp, rf, False{}, ir}, mem)

# the EXECUTE cycle of instruction i: the single-cycle datapath, on i
def exec_with(+i: Word(16n), +pc: Word(16n), +nzp: Word(3n), +rf: M.Mem<16n>, +mem: M.Mem<16n>) -> State & M.Mem<16n>:
  with_phase(Single.step_with(i, pc, nzp, rf, mem), i)

# one clock cycle
def step(s: State, +mem: M.Mem<16n>) -> State & M.Mem<16n>:
  match s:
    case State{+pc, nzp, rf, exec, ir}:
      match exec:
        case False{}:
          (State{pc, nzp, rf, True{}, M.get(16n, 16n, pc, mem)}, mem)
        case True{}:
          exec_with(ir, pc, nzp, rf, mem)

# The processor as an LC4 machine
# -------------------------------

def abs.go(s: State, mem: M.Mem<16n>) -> S.Machine:
  match s:
    case State{pc, nzp, rf, _, _}:
      S.Machine{pc, nzp, False{}, rf, mem}

# the LC4 machine a FETCH state and its memory hold
def abs(sm: State & M.Mem<16n>) -> S.Machine:
  (s, mem) = sm
  abs.go(s, mem)

def step2.go(sm: State & M.Mem<16n>) -> State & M.Mem<16n>:
  (s, mem) = sm
  step(s, mem)

# two clock cycles
def step2(s: State, +mem: M.Mem<16n>) -> State & M.Mem<16n>:
  step2.go(step(s, mem))

# The processor as Verilog
# ------------------------

def id(x: String) -> A.Expr:
  A.VId{x}

def and(a: A.Expr, b: A.Expr) -> A.Expr:
  A.VBin{A.BLAnd{}, a, b}

def regfile.go(xs: List<&2, String>, +k: Nat) -> List<&2, A.Item>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+x, t}:
      Single.reg(16n, 0n, x ++ "_reg", id("wdata"), x, and(id("exec"), and(id("rf_we"), A.VBin{A.BEq{}, id("wsel"), A.VNum{Some{3n}, A.RHex{}, k}}))) <> regfile.go(t, 1n+k)

def module.go(items: List<&2, A.Item>) -> A.Module:
  A.Module{"lc4_processor", Nil{}, Single.ports(), Single.body(List.concat(&2, A.Item, [
    [Single.wire(16n, "pc"), Single.wire(3n, "nzp"), Single.wire(1n, "exec"), Single.wire(16n, "ir"),
     Single.wire(16n, "r0"), Single.wire(16n, "r1"), Single.wire(16n, "r2"), Single.wire(16n, "r3"),
     Single.wire(16n, "r4"), Single.wire(16n, "r5"), Single.wire(16n, "r6"), Single.wire(16n, "r7")],
    items,
    [Single.reg(1n, 0n, "exec_reg", A.VUn{A.UNot{}, id("exec")}, "exec", A.VNum{Some{1n}, A.RBin{}, 1n}),
     Single.reg(16n, 0n, "ir_reg", id("i_cur_insn"), "ir", A.VUn{A.ULNot{}, id("exec")}),
     Single.reg(16n, 33280n, "pc_reg", id("next_pc"), "pc", id("exec")),
     Single.reg(3n, 0n, "nzp_reg", id("nzp_new"), "nzp", and(id("exec"), id("nzp_we")))],
    regfile.go(Single.regs(), 0n),
    [Single.assign("o_cur_pc", id("pc")), Single.assign("o_dmem_addr", id("dmem_addr")),
     Single.assign("o_dmem_we", and(id("exec"), id("is_str"))),
     Single.assign("o_dmem_towrite", id("dmem_out")),
     Single.assign("test_stall", A.VCond{id("exec"), A.VNum{Some{2n}, A.RBin{}, 0n}, A.VNum{Some{2n}, A.RBin{}, 2n}}),
     Single.assign("test_cur_pc", id("pc")), Single.assign("test_cur_insn", id("ir")),
     Single.assign("test_regfile_we", id("rf_we")), Single.assign("test_regfile_wsel", id("wsel")),
     Single.assign("test_regfile_data", id("wdata")), Single.assign("test_nzp_we", id("nzp_we")),
     Single.assign("test_nzp_new_bits", id("nzp_new")), Single.assign("test_dmem_we", id("is_str")),
     Single.assign("test_dmem_addr", id("dmem_addr")),
     Single.assign("test_dmem_data", A.VCond{id("is_ldr"), id("i_cur_dmem_data"), id("dmem_out")}),
     Single.assign("led_data", id("switch_data"))]]))}

def items_of(p: Single.Out & List<&2, A.Item>) -> List<&2, A.Item>:
  (o, items) = p
  items

# the processor as a Verilog module: the single-cycle datapath, reading
# the instruction register
def module() -> A.Module:
  +z = B.zero(16n)
  module.go(items_of(D.run(Single.Out, Single.cycle(D.sig(16n, z, "pc"), D.sig(3n, B.zero(3n), "nzp"), M.MemZ{}, D.sig(16n, z, "ir"), D.sig(16n, z, "i_cur_dmem_data")))))
