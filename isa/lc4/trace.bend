# isa/lc4/trace.bend: runs the LC4 spec against a PennSim trace.
#
#   bend2 isa/lc4/trace.bend <image.hex> <trace.ctrace>
#
# The image is one hex word per line, address 0 first ($readmemh). Each
# trace line is what the CIS 371 testbench checks for one instruction:
#   pc insn(binary) rf_we rd rd_val nzp_we nzp mem_we mem_addr mem_val
# rd and rd_val are compared only when rf_we is set, nzp only when nzp_we
# is set, exactly as testbench_lc4_processor.v does. Execution starts at
# 0x8200 with every register and NZP at 0, as the processor resets.

import Base
import ../../hdl/bits.bend as B
import ../../hdl/mem.bend as M
import ./spec.bend as S

# Parsing
# -------

def digit.hi(+c: U32, letter: Bool) -> Nat:
  match letter:
    case True{}:
      U32.to_nat((c - 55 : U32))
    case False{}:
      U32.to_nat((c - 87 : U32))

def digit.go(+c: U32, num: Bool) -> Nat:
  match num:
    case True{}:
      U32.to_nat((c - 48 : U32))
    case False{}:
      digit.hi(c, U32.is_lt(c, 71))

# the value of a hex (or binary) digit
def digit(+c: U32) -> Nat:
  digit.go(c, U32.is_lt(c, 58))

def parse.go(+radix: Nat, s: String, acc: Nat) -> Nat:
  match s:
    case SNil{}:
      acc
    case SCon{Chr{c}, t}:
      parse.go(radix, t, Nat.add(Nat.mul(acc, radix), digit(c)))

def parse(+radix: Nat, s: String) -> Nat:
  parse.go(radix, s, 0n)

def hexw(s: String) -> Word(16n):
  B.of_nat(16n, parse(16n, s))

def split.put.if(cur: String, acc: List<&2, String>, empty: Bool) -> List<&2, String>:
  match empty:
    case True{}:
      acc
    case False{}:
      String.reverse(cur) <> acc

def split.put(+cur: String, acc: List<&2, String>) -> List<&2, String>:
  split.put.if(cur, acc, String.is_empty(cur))

def split.cur(c: Char, cur: String, cut: Bool) -> String:
  match cut:
    case True{}:
      SNil{}
    case False{}:
      SCon{c, cur}

def split.acc(+cur: String, acc: List<&2, String>, cut: Bool) -> List<&2, String>:
  match cut:
    case True{}:
      split.put(cur, acc)
    case False{}:
      acc

# the non-empty pieces of s between sep characters (tail-recursive, so a
# long file does not overflow)
def split.go(s: String, +cur: String, acc: List<&2, String>, +sep: Char) -> List<&2, String>:
  match s:
    case SNil{}:
      List.reverse(&2, String, split.put(cur, acc))
    case SCon{+c, t}:
      +cut = Char.is_eq(c, sep)
      split.go(t, split.cur(c, cur, cut), split.acc(cur, acc, cut), sep)

def split(s: String, +sep: Char) -> List<&2, String>:
  split.go(s, SNil{}, Nil{}, sep)

# the space-separated words of a line
def fields(s: String) -> List<&2, String>:
  split(s, ' ')

def lines(s: String) -> List<&2, String>:
  split(s, '\n')

# Words to text
# -------------

def hex(n: Nat, w: Word(n)) -> String:
  U32.hex(U32.from_nat(B.to_nat(n, w)))

# Loading the image
# -----------------

def load.put(k: Nat, +v: Nat, m: M.Mem<16n>, zero: Bool) -> M.Mem<16n>:
  match zero:
    case True{}:
      m
    case False{}:
      M.set(16n, 16n, B.of_nat(16n, k), B.of_nat(16n, v), m)

# the memory holding each line's word at the line's address
def load(xs: List<&2, String>, +k: Nat, m: M.Mem<16n>) -> M.Mem<16n>:
  match xs:
    case Nil{}:
      m
    case Con{h, t}:
      +v = parse(16n, h)
      load(t, 1n+k, load.put(k, v, m, Nat.is_eq(v, 0n)))

# Checking
# --------

def cmp_field.go(name: String, +n: Nat, +expect: Word(n), +got: Word(n), same: Bool) -> String:
  match same:
    case True{}:
      ""
    case False{}:
      name ++ " should be " ++ hex(n, expect) ++ " (but was " ++ hex(n, got) ++ ") "

# "" when expect and got agree, else a message naming the field
def cmp_field(name: String, +n: Nat, +expect: Word(n), +got: Word(n)) -> String:
  cmp_field.go(name, n, expect, got, B.eq(n, expect, got))

# the check of a field the testbench reads only when its enable is set
def cmp_when(on: Bool, name: String, +n: Nat, +expect: Word(n), +got: Word(n)) -> String:
  match on:
    case True{}:
      cmp_field(name, n, expect, got)
    case False{}:
      ""

def bitw(b: Bool) -> Word(16n):
  B.zext(1n, 16n, B.bit1(b))

def is_one(s: String) -> Bool:
  Bool.not(Nat.is_eq(parse(16n, s), 0n))

# the mismatches between a trace line and what the spec retired
def check(fs: List<&2, String>, +pc: Word(16n), +insn: Word(16n), r: S.Retire) -> String:
  match fs:
    case Con{tpc, Con{tinsn, Con{twe, Con{trd, Con{tval, Con{tnwe, Con{tnzp, Con{tmwe, Con{taddr, Con{tdata, _}}}}}}}}}}:
      match r:
        case S.Retire{rf_we, rd, rd_val, nzp_we, nzp, mem_we, mem_addr, mem_val, npc, priv}:
          +we = twe
          +nwe = tnwe
          cmp_field("pc", 16n, hexw(tpc), pc)
            ++ cmp_field("insn", 16n, B.of_nat(16n, parse(2n, tinsn)), insn)
            ++ cmp_field("regfile_we", 16n, hexw(we), bitw(rf_we))
            ++ cmp_when(is_one(we), "regfile_reg", 16n, hexw(trd), B.zext(3n, 16n, rd))
            ++ cmp_when(is_one(we), "regfile_in", 16n, hexw(tval), rd_val)
            ++ cmp_field("nzp_we", 16n, hexw(nwe), bitw(nzp_we))
            ++ cmp_when(is_one(nwe), "nzp_new_bits", 16n, hexw(tnzp), B.zext(3n, 16n, nzp))
            ++ cmp_field("dmem_we", 16n, hexw(tmwe), bitw(mem_we))
            ++ cmp_field("dmem_addr", 16n, hexw(taddr), mem_addr)
            ++ cmp_field("dmem_data", 16n, hexw(tdata), mem_val)
    case _:
      "malformed trace line"

def pc_of(s: S.Machine) -> Word(16n):
  match s:
    case S.Machine{pc, nzp, priv, regs, mem}:
      pc

def insn_of(s: S.Machine) -> Word(16n):
  match s:
    case S.Machine{+pc, nzp, priv, regs, mem}:
      M.get(16n, 16n, pc, mem)

def next.if(+s: S.Machine, r: S.Retire, ok: Bool, err: String) -> Either<&2, &2, String, S.Machine>:
  match ok:
    case True{}:
      Inr{S.apply(s, r)}
    case False{}:
      Inl{err}

def next.ok(+s: S.Machine, r: S.Retire, +err: String) -> Either<&2, &2, String, S.Machine>:
  next.if(s, r, String.is_empty(err), err)

def next.go(fs: List<&2, String>, +s: S.Machine, mr: Maybe<&2, S.Retire>) -> Either<&2, &2, String, S.Machine>:
  match mr:
    case None{}:
      Inl{"the instruction at the PC does not decode"}
    case Some{+r}:
      next.ok(s, r, check(fs, pc_of(s), insn_of(s), r))

# the machine after one trace line, or what went wrong
def next(line: String, +s: S.Machine) -> Either<&2, &2, String, S.Machine>:
  next.go(fields(line), s, S.retire(s))

def run(xs: List<&2, String>, st: Either<&2, &2, String, S.Machine>, +n: Nat) -> String:
  match xs:
    case Nil{}:
      match st:
        case Inl{err}:
          "MISMATCH at line " ++ Nat.show(n) ++ ": " ++ err
        case Inr{s}:
          "ALL " ++ Nat.show(n) ++ " INSTRUCTIONS MATCH"
    case Con{h, t}:
      match st:
        case Inl{err}:
          "MISMATCH at line " ++ Nat.show(n) ++ ": " ++ err
        case Inr{+s}:
          run(t, next(h, s), 1n+n)

def reset(mem: M.Mem<16n>) -> S.Machine:
  S.Machine{B.of_nat(16n, 33280n), B.zero(3n), True{}, M.MemZ{}, mem}

def read_all.fin(fr: File & Result<&1, &1, U32 & String, String>) -> IO(String):
  (f, r) = fr
  do IO<String>:
    File.close(f)
    text : String <- IO.try(String, IO.pure(Result<&1, &1, U32 & String, String>, r))
    return text

# the whole text of a file
def read_all(path: String) -> IO(String):
  do IO<String>:
    f : File <- IO.try(File, File.open(path, "r"))
    fr : File & Result<&1, &1, U32 & String, String> <- File.read(f, 1000000000)
    text : String <- read_all.fin(fr)
    return text

def main.go(args: List<String>) -> IO(Unit):
  match args:
    case Con{_, Con{hex, Con{trace, _}}}:
      do IO<Unit>:
        img : String <- read_all(hex)
        tr : String <- read_all(trace)
        IO.print(run(lines(tr), Inr{reset(load(lines(img), 0n, M.MemZ{}))}, 0n))
    case _:
      IO.print("usage: bend isa/lc4/trace.bend <image.hex> <trace.ctrace>")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    main.go(args)
