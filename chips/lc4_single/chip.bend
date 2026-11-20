# chips/lc4_single/chip.bend: a single-cycle LC4 processor, in the DSL.
#
# One instruction per cycle: the PC fetches the instruction (combinational
# instruction memory), the decoder's opcode tests steer register reads, the
# units compute in parallel, and muxes pick the register write, the NZP
# write, the memory access and the next PC. State: the PC (resets to
# 0x8200), the NZP bits, and eight 16-bit registers. Memory sits outside,
# as in the CIS 371 labs: the exported module is a drop-in lc4_processor.
#
# LAWS.bend states that each cycle performs exactly one LC4 instruction.

import Base
import ../../hdl/bits.bend as B
import ../../hdl/mem.bend as M
import ../../hdl/dsl.bend as D
import ../../hdl/verilog/ast.bend as A
import ../../isa/lc4/spec.bend as S

# What one cycle computes
# -----------------------

type Out is Data:
  Out{next_pc: D.S<16n>, rf_we: D.S<1n>, wsel: D.S<3n>, wdata: D.S<16n>, nzp_we: D.S<1n>, nzp_new: D.S<3n>, dmem_we: D.S<1n>, dmem_addr: D.S<16n>, dmem_out: D.S<16n>}

def regs() -> List<&2, String>:
  ["r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7"]

def w1(+x: String, s: D.S<1n>) -> D.Build(D.S<1n>):
  D.wire(1n, x, s)

def w3(+x: String, s: D.S<3n>) -> D.Build(D.S<3n>):
  D.wire(3n, x, s)

def w16(+x: String, s: D.S<16n>) -> D.Build(D.S<16n>):
  D.wire(16n, x, s)

def k16(v: Nat) -> D.S<16n>:
  D.lit(16n, v)

# is the opcode k?
def is_op(+op: D.S<4n>, k: Nat) -> D.S<1n>:
  D.eq(4n, op, D.lit(4n, k))

def or1(a: D.S<1n>, b: D.S<1n>) -> D.S<1n>:
  D.or(1n, a, b)

# {a, b, c}, three bits
def bits3(a: D.S<1n>, b: D.S<1n>, c: D.S<1n>) -> D.S<3n>:
  D.cat(1n, 2n, D.cat(1n, 1n, a, b), c)

# the cycle: from the PC, the NZP bits, the registers, the instruction
# fetched at the PC, and the word loaded from data memory
def cycle(+pc: D.S<16n>, +nzp: D.S<3n>, +rf: M.Mem<16n>, +i: D.S<16n>, +ld: D.S<16n>) -> D.Build(Out):
  do D.Build<Out>:
    # decode
    +op : D.S<4n> <- D.wire(4n, "op", D.bits(16n, 15n, 12n, i))
    +is_br : D.S<1n> <- w1("is_br", is_op(op, 0n))
    +is_arith : D.S<1n> <- w1("is_arith", is_op(op, 1n))
    +is_cmp : D.S<1n> <- w1("is_cmp", is_op(op, 2n))
    +is_jsr : D.S<1n> <- w1("is_jsr", is_op(op, 4n))
    +is_logic : D.S<1n> <- w1("is_logic", is_op(op, 5n))
    +is_ldr : D.S<1n> <- w1("is_ldr", is_op(op, 6n))
    +is_str : D.S<1n> <- w1("is_str", is_op(op, 7n))
    +is_rti : D.S<1n> <- w1("is_rti", is_op(op, 8n))
    +is_const : D.S<1n> <- w1("is_const", is_op(op, 9n))
    +is_shift : D.S<1n> <- w1("is_shift", is_op(op, 10n))
    +is_jmp : D.S<1n> <- w1("is_jmp", is_op(op, 12n))
    +is_hic : D.S<1n> <- w1("is_hiconst", is_op(op, 13n))
    +is_trap : D.S<1n> <- w1("is_trap", is_op(op, 15n))
    +imm : D.S<1n> <- w1("imm", D.bit(16n, 5n, i))
    +sub1 : D.S<1n> <- w1("sub1", D.bit(16n, 4n, i))
    +sub0 : D.S<1n> <- w1("sub0", D.bit(16n, 3n, i))
    +link : D.S<1n> <- w1("link", or1(is_jsr, is_trap))
    # register reads: CMP and HICONST read insn[11:9], RTI reads R7
    +rs_sel : D.S<3n> <- w3("rs_sel", D.mux(3n, or1(is_cmp, is_hic), D.bits(16n, 11n, 9n, i), D.mux(3n, is_rti, D.lit(3n, 7n), D.bits(16n, 8n, 6n, i))))
    +rt_sel : D.S<3n> <- w3("rt_sel", D.mux(3n, is_str, D.bits(16n, 11n, 9n, i), D.bits(16n, 2n, 0n, i)))
    +rs : D.S<16n> <- w16("rs", D.rf_read(16n, 3n, rf, regs(), rs_sel))
    +rt : D.S<16n> <- w16("rt", D.rf_read(16n, 3n, rf, regs(), rt_sel))
    +pc1 : D.S<16n> <- w16("pc1", D.add(16n, pc, k16(1n)))
    # the units
    +arith : D.S<16n> <- w16("arith", D.mux(16n, imm, D.add(16n, rs, D.sx(16n, 4n, 0n, 16n, i)), D.mux(16n, sub1, D.mux(16n, sub0, D.udiv(16n, rs, rt), D.sub(16n, rs, rt)), D.mux(16n, sub0, D.mul(16n, rs, rt), D.add(16n, rs, rt)))))
    +logic : D.S<16n> <- w16("logic_r", D.mux(16n, imm, D.and(16n, rs, D.sx(16n, 4n, 0n, 16n, i)), D.mux(16n, sub1, D.mux(16n, sub0, D.xor(16n, rs, rt), D.or(16n, rs, rt)), D.mux(16n, sub0, D.not(16n, rs), D.and(16n, rs, rt)))))
    +amt : D.S<4n> <- D.wire(4n, "amt", D.bits(16n, 3n, 0n, i))
    +shift : D.S<16n> <- w16("shift", D.mux(16n, imm, D.mux(16n, sub1, D.umod(16n, rs, rt), D.srl(16n, 4n, rs, amt)), D.mux(16n, sub1, D.sra(16n, 4n, rs, amt), D.shl(16n, 4n, rs, amt))))
    +rs_lo : D.S<8n> <- D.wire(8n, "rs_lo", D.bits(16n, 7n, 0n, rs))
    +hiconst : D.S<16n> <- w16("hiconst", D.cat(8n, 8n, D.bits(16n, 7n, 0n, i), rs_lo))
    +alu : D.S<16n> <- w16("alu", D.mux(16n, is_arith, arith, D.mux(16n, is_logic, logic, D.mux(16n, is_shift, shift, D.mux(16n, is_hic, hiconst, D.sx(16n, 8n, 0n, 16n, i))))))
    +addr : D.S<16n> <- w16("addr", D.add(16n, rs, D.sx(16n, 5n, 0n, 16n, i)))
    # register write
    +rf_we : D.S<1n> <- w1("rf_we", or1(or1(or1(is_arith, is_logic), or1(is_shift, is_const)), or1(or1(is_hic, is_ldr), link)))
    +wsel : D.S<3n> <- w3("wsel", D.mux(3n, link, D.lit(3n, 7n), D.bits(16n, 11n, 9n, i)))
    +wdata : D.S<16n> <- w16("wdata", D.mux(16n, is_ldr, ld, D.mux(16n, link, pc1, alu)))
    # NZP: N is the sign, Z is zero, P is neither; compares: <, ==, >
    +cmp_b : D.S<16n> <- w16("cmp_b", D.mux(16n, D.bit(16n, 8n, i), D.mux(16n, D.bit(16n, 7n, i), D.zx(16n, 6n, 0n, 16n, i), D.sx(16n, 6n, 0n, 16n, i)), rt))
    +cmp_nzp : D.S<3n> <- w3("cmp_nzp", D.mux(3n, D.bit(16n, 7n, i), bits3(D.ult(16n, rs, cmp_b), D.eq(16n, rs, cmp_b), D.ugt(16n, rs, cmp_b)), bits3(D.slt(16n, rs, cmp_b), D.eq(16n, rs, cmp_b), D.sgt(16n, rs, cmp_b))))
    +neg : D.S<1n> <- w1("neg", D.bit(16n, 15n, wdata))
    +zero : D.S<1n> <- w1("zero", D.eq(16n, wdata, k16(0n)))
    +nzp_we : D.S<1n> <- w1("nzp_we", or1(rf_we, is_cmp))
    +nzp_new : D.S<3n> <- w3("nzp_new", D.mux(3n, is_cmp, cmp_nzp, bits3(neg, zero, D.not(1n, or1(neg, zero)))))
    # the next PC
    +taken : D.S<1n> <- w1("taken", D.any(3n, D.and(3n, nzp, D.bits(16n, 11n, 9n, i))))
    +br_pc : D.S<16n> <- w16("br_pc", D.mux(16n, taken, D.add(16n, pc1, D.sx(16n, 8n, 0n, 16n, i)), pc1))
    +jsr_pc : D.S<16n> <- w16("jsr_pc", D.mux(16n, D.bit(16n, 11n, i), D.cat(4n, 12n, D.cat(11n, 1n, D.bit(16n, 15n, pc), D.bits(16n, 10n, 0n, i)), D.lit(4n, 0n)), rs))
    +jmp_pc : D.S<16n> <- w16("jmp_pc", D.mux(16n, D.bit(16n, 11n, i), D.add(16n, pc1, D.sx(16n, 10n, 0n, 16n, i)), rs))
    +trap_pc : D.S<16n> <- w16("trap_pc", D.cat(8n, 8n, D.lit(8n, 128n), D.bits(16n, 7n, 0n, i)))
    +next_pc : D.S<16n> <- w16("next_pc", D.mux(16n, is_br, br_pc, D.mux(16n, is_jsr, jsr_pc, D.mux(16n, is_jmp, jmp_pc, D.mux(16n, is_rti, rs, D.mux(16n, is_trap, trap_pc, pc1))))))
    # data memory
    +mem : D.S<1n> <- w1("mem", or1(is_ldr, is_str))
    +dmem_addr : D.S<16n> <- w16("dmem_addr", D.mux(16n, mem, addr, k16(0n)))
    +dmem_out : D.S<16n> <- w16("dmem_out", D.mux(16n, is_str, rt, k16(0n)))
    return Out{next_pc, rf_we, wsel, wdata, nzp_we, nzp_new, is_str, dmem_addr, dmem_out}

# The processor as a Bend function
# --------------------------------

type State is Data:
  State{pc: Word(16n), nzp: Word(3n), rf: M.Mem<16n>}

def out_of(p: Out & List<&2, A.Item>) -> Out:
  (o, items) = p
  o

# the cycle's values on the given inputs
def eval(+pc: Word(16n), +nzp: Word(3n), +rf: M.Mem<16n>, +i: Word(16n), +ld: Word(16n)) -> Out:
  out_of(D.run(Out, cycle(D.sig(16n, pc, "pc"), D.sig(3n, nzp, "nzp"), rf, D.sig(16n, i, "i_cur_insn"), D.sig(16n, ld, "i_cur_dmem_data"))))

def dmem_addr_of(o: Out) -> Word(16n):
  match o:
    case Out{_, _, _, _, _, _, _, a, _}:
      D.val(16n, a)

def commit(+nzp: Word(3n), rf: M.Mem<16n>, mem: M.Mem<16n>, o: Out) -> State & M.Mem<16n>:
  match o:
    case Out{npc, rf_we, wsel, wdata, nzp_we, nzp_new, dmem_we, dmem_addr, dmem_out}:
      (State{D.val(16n, npc), B.pick(3n, D.bool(nzp_we), D.val(3n, nzp_new), nzp), M.write(16n, D.bool(rf_we), 3n, D.val(3n, wsel), D.val(16n, wdata), rf)}, M.write(16n, D.bool(dmem_we), 16n, D.val(16n, dmem_addr), D.val(16n, dmem_out), mem))

# one clock cycle with instruction i at the PC, against memory mem: the
# memory read sees the address this cycle computes
def step_with(+i: Word(16n), +pc: Word(16n), +nzp: Word(3n), +rf: M.Mem<16n>, +mem: M.Mem<16n>) -> State & M.Mem<16n>:
  +ld = M.get(16n, 16n, dmem_addr_of(eval(pc, nzp, rf, i, B.zero(16n))), mem)
  commit(nzp, rf, mem, eval(pc, nzp, rf, i, ld))

# one clock cycle
def step(s: State, +mem: M.Mem<16n>) -> State & M.Mem<16n>:
  match s:
    case State{+pc, nzp, rf}:
      step_with(M.get(16n, 16n, pc, mem), pc, nzp, rf, mem)

# The processor as Verilog
# ------------------------

def port(d: A.Dir, w: Nat, x: String) -> A.Port:
  A.Port{d, A.NWire{}, D.range(w), [x]}

# the lc4_processor ports of the CIS 371 labs
def ports() -> List<&2, A.Port>:
  [port(A.DIn{}, 1n, "clk"), port(A.DIn{}, 1n, "rst"), port(A.DIn{}, 1n, "gwe"),
   port(A.DOut{}, 16n, "o_cur_pc"), port(A.DIn{}, 16n, "i_cur_insn"),
   port(A.DOut{}, 16n, "o_dmem_addr"), port(A.DIn{}, 16n, "i_cur_dmem_data"),
   port(A.DOut{}, 1n, "o_dmem_we"), port(A.DOut{}, 16n, "o_dmem_towrite"),
   port(A.DOut{}, 2n, "test_stall"), port(A.DOut{}, 16n, "test_cur_pc"),
   port(A.DOut{}, 16n, "test_cur_insn"), port(A.DOut{}, 1n, "test_regfile_we"),
   port(A.DOut{}, 3n, "test_regfile_wsel"), port(A.DOut{}, 16n, "test_regfile_data"),
   port(A.DOut{}, 1n, "test_nzp_we"), port(A.DOut{}, 3n, "test_nzp_new_bits"),
   port(A.DOut{}, 1n, "test_dmem_we"), port(A.DOut{}, 16n, "test_dmem_addr"),
   port(A.DOut{}, 16n, "test_dmem_data"), port(A.DIn{}, 8n, "switch_data"),
   port(A.DOut{}, 8n, "led_data")]

def wire(w: Nat, x: String) -> A.Item:
  A.INet{A.NWire{}, False{}, D.range(w), [A.Decl{x, None{}}]}

def assign(x: String, e: A.Expr) -> A.Item:
  A.IAssign{None{}, A.VId{x}, e}

def id(x: String) -> A.Expr:
  A.VId{x}

def conn(p: String, e: A.Expr) -> A.Conn:
  A.Conn{Some{p}, Some{e}}

def num(n: Nat) -> A.Expr:
  A.VNum{None{}, A.RDec{}, n}

# Nbit_reg #(w, r) name (.in(d), .out(q), .clk(clk), .we(we), .gwe(gwe), .rst(rst));
def reg(+w: Nat, r: Nat, name: String, d: A.Expr, q: String, we: A.Expr) -> A.Item:
  A.IInst{"Nbit_reg", [A.Conn{None{}, Some{num(w)}}, A.Conn{None{}, Some{A.VNum{Some{w}, A.RHex{}, r}}}], name,
    [conn("in", d), conn("out", id(q)), conn("clk", id("clk")), conn("we", we), conn("gwe", id("gwe")), conn("rst", id("rst"))]}

def regfile.go(xs: List<&2, String>, +k: Nat) -> List<&2, A.Item>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+x, t}:
      reg(16n, 0n, x ++ "_reg", id("wdata"), x, A.VBin{A.BLAnd{}, id("rf_we"), A.VBin{A.BEq{}, id("wsel"), A.VNum{Some{3n}, A.RHex{}, k}}}) <> regfile.go(t, 1n+k)

def body(xs: List<&2, A.Item>) -> A.Item:
  match xs:
    case Nil{}:
      A.INil{}
    case Con{h, t}:
      A.ICon{h, body(t)}

def module.go(items: List<&2, A.Item>) -> A.Module:
  A.Module{"lc4_processor", Nil{}, ports(), body(List.concat(&2, A.Item, [
    [wire(16n, "pc"), wire(3n, "nzp"), wire(16n, "r0"), wire(16n, "r1"), wire(16n, "r2"), wire(16n, "r3"),
     wire(16n, "r4"), wire(16n, "r5"), wire(16n, "r6"), wire(16n, "r7")],
    items,
    [reg(16n, 33280n, "pc_reg", id("next_pc"), "pc", A.VNum{Some{1n}, A.RBin{}, 1n}),
     reg(3n, 0n, "nzp_reg", id("nzp_new"), "nzp", id("nzp_we"))],
    regfile.go(regs(), 0n),
    [assign("o_cur_pc", id("pc")), assign("o_dmem_addr", id("dmem_addr")), assign("o_dmem_we", id("is_str")),
     assign("o_dmem_towrite", id("dmem_out")), assign("test_stall", A.VNum{Some{2n}, A.RBin{}, 0n}),
     assign("test_cur_pc", id("pc")), assign("test_cur_insn", id("i_cur_insn")),
     assign("test_regfile_we", id("rf_we")), assign("test_regfile_wsel", id("wsel")),
     assign("test_regfile_data", id("wdata")), assign("test_nzp_we", id("nzp_we")),
     assign("test_nzp_new_bits", id("nzp_new")), assign("test_dmem_we", id("is_str")),
     assign("test_dmem_addr", id("dmem_addr")),
     assign("test_dmem_data", A.VCond{id("is_ldr"), id("i_cur_dmem_data"), id("dmem_out")}),
     assign("led_data", id("switch_data"))]]))}

def items_of(p: Out & List<&2, A.Item>) -> List<&2, A.Item>:
  (o, items) = p
  items

# the processor as a Verilog module
def module() -> A.Module:
  +z = B.zero(16n)
  module.go(items_of(D.run(Out, cycle(D.sig(16n, z, "pc"), D.sig(3n, B.zero(3n), "nzp"), M.MemZ{}, D.sig(16n, z, "i_cur_insn"), D.sig(16n, z, "i_cur_dmem_data")))))

# The processor as an LC4 machine
# -------------------------------

def abs.go(s: State, mem: M.Mem<16n>) -> S.Machine:
  match s:
    case State{pc, nzp, rf}:
      S.Machine{pc, nzp, False{}, rf, mem}

# the LC4 machine a processor state and its memory hold (the processor has
# no privilege bit; isa/lc4/LAWS.bend shows the bit is unobservable)
def abs(sm: State & M.Mem<16n>) -> S.Machine:
  (s, mem) = sm
  abs.go(s, mem)
