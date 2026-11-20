# hdl/dsl.bend: a DSL for writing circuits in Bend.
#
# A signal S<n> is dual-rail: its value (an n-bit Word, what proofs reason
# about) and the Verilog expression that computes it (what export prints).
# Every operator computes both rails, the value with the hdl/bits function
# that gives the Verilog operator its meaning:
#
#   and(a, b)    a & b         add(a, b)   a + b        mux(c, a, b)  c ? a : b
#   eq(a, b)     a == b        ult(a, b)   a < b        slt(a, b)     $signed(a) < $signed(b)
#
# Every operand of an operator has the operator's width, and every literal is
# sized, so Verilog's context-dependent widths never come into play.
#
# A circuit is written in the Build monad, which records the Verilog items
# (wires, instances, registers) a design declares: wire(name, s) declares
# `wire [n-1:0] name = <s>;` and gives back s under that name, so a signal
# used many times is computed once. A slice or a bit select needs a named
# signal (Verilog has no (a + b)[3:0]); export rejects any other.
#
# A circuit must only reach the values of signals through these operators:
# branching on a value would print the branch taken while exporting. The
# Verilog of every design is also checked against PennSim's traces (make sim).

import Base
import ./bits.bend as B
import ./mem.bend as M
import ./verilog/ast.bend as A

# Signals
# -------

type S<-n: Nat> is Data:
  S{w: Word(n), e: A.Expr}

def val(-n: Nat, s: S<n>) -> Word(n):
  match s:
    case S{w, _}:
      w

def expr(-n: Nat, s: S<n>) -> A.Expr:
  match s:
    case S{_, e}:
      e

def bool(s: S<1n>) -> Bool:
  match s:
    case S{w, _}:
      B.lsb(1n, w)

# the sized literal n'hv
def lit(+n: Nat, +v: Nat) -> S<n>:
  S{B.of_nat(n, v), A.VNum{Some{n}, A.RHex{}, v}}

# a 1-bit literal
def lit1(b: Bool) -> S<1n>:
  match b:
    case True{}:
      S{B.bit1(True{}), A.VNum{Some{1n}, A.RBin{}, 1n}}
    case False{}:
      S{B.bit1(False{}), A.VNum{Some{1n}, A.RBin{}, 0n}}

# the signal named x, holding w
def sig(-n: Nat, w: Word(n), x: String) -> S<n>:
  S{w, A.VId{x}}

# Operators
# ---------

def bin(o: A.BOp, a: A.Expr, b: A.Expr) -> A.Expr:
  A.VBin{o, a, b}

def and(+n: Nat, a: S<n>, b: S<n>) -> S<n>:
  match a b:
    case S{x, ea} S{y, eb}:
      S{B.and(n, x, y), bin(A.BAnd{}, ea, eb)}

def or(+n: Nat, a: S<n>, b: S<n>) -> S<n>:
  match a b:
    case S{x, ea} S{y, eb}:
      S{B.or(n, x, y), bin(A.BOr{}, ea, eb)}

def xor(+n: Nat, a: S<n>, b: S<n>) -> S<n>:
  match a b:
    case S{x, ea} S{y, eb}:
      S{B.xor(n, x, y), bin(A.BXor{}, ea, eb)}

def not(+n: Nat, a: S<n>) -> S<n>:
  match a:
    case S{x, ea}:
      S{B.not(n, x), A.VUn{A.UNot{}, ea}}

def add(+n: Nat, a: S<n>, b: S<n>) -> S<n>:
  match a b:
    case S{x, ea} S{y, eb}:
      S{B.add(n, x, y), bin(A.BAdd{}, ea, eb)}

def sub(+n: Nat, a: S<n>, b: S<n>) -> S<n>:
  match a b:
    case S{x, ea} S{y, eb}:
      S{B.sub(n, x, y), bin(A.BSub{}, ea, eb)}

def mul(+n: Nat, a: S<n>, b: S<n>) -> S<n>:
  match a b:
    case S{x, ea} S{y, eb}:
      S{B.mul(n, x, y), bin(A.BMul{}, ea, eb)}

# a / b and a % b, as LC4 wants them: 0 when b is 0. Verilog's / and %
# leave division by zero undefined, so the printed expression tests b.
def udiv(+n: Nat, a: S<n>, b: S<n>) -> S<n>:
  match a b:
    case S{x, ea} S{+y, +eb}:
      S{B.udiv(n, x, y), A.VCond{bin(A.BEq{}, eb, A.VNum{Some{n}, A.RHex{}, 0n}), A.VNum{Some{n}, A.RHex{}, 0n}, bin(A.BDiv{}, ea, eb)}}

def umod(+n: Nat, a: S<n>, b: S<n>) -> S<n>:
  match a b:
    case S{x, ea} S{+y, +eb}:
      S{B.umod(n, x, y), A.VCond{bin(A.BEq{}, eb, A.VNum{Some{n}, A.RHex{}, 0n}), A.VNum{Some{n}, A.RHex{}, 0n}, bin(A.BMod{}, ea, eb)}}

# a << k, a >> k and $signed(a) >>> k, for a k-bit shift amount
def shl(+n: Nat, +k: Nat, a: S<n>, s: S<k>) -> S<n>:
  match a s:
    case S{x, ea} S{y, es}:
      S{B.shl_by(B.to_nat(k, y), n, x), bin(A.BShl{}, ea, es)}

def srl(+n: Nat, +k: Nat, a: S<n>, s: S<k>) -> S<n>:
  match a s:
    case S{x, ea} S{y, es}:
      S{B.srl_by(B.to_nat(k, y), n, x), bin(A.BShr{}, ea, es)}

def signed(e: A.Expr) -> A.Expr:
  A.VSys{"signed", A.VCon{e, A.VNil{}}}

def sra(+n: Nat, +k: Nat, a: S<n>, s: S<k>) -> S<n>:
  match a s:
    case S{x, ea} S{y, es}:
      S{B.sra_by(B.to_nat(k, y), n, x), signed(bin(A.BSshr{}, signed(ea), es))}

# c ? a : b
def mux(-n: Nat, c: S<1n>, a: S<n>, b: S<n>) -> S<n>:
  match c a b:
    case S{wc, ec} S{x, ea} S{y, eb}:
      S{B.pick(n, B.lsb(1n, wc), x, y), A.VCond{ec, ea, eb}}

def cmp_bit(b: Bool, e: A.Expr) -> S<1n>:
  S{B.bit1(b), e}

# a == b
def eq(+n: Nat, a: S<n>, b: S<n>) -> S<1n>:
  match a b:
    case S{x, ea} S{y, eb}:
      cmp_bit(B.eq(n, x, y), bin(A.BEq{}, ea, eb))

# a < b and a > b, unsigned
def ult(+n: Nat, a: S<n>, b: S<n>) -> S<1n>:
  match a b:
    case S{x, ea} S{y, eb}:
      cmp_bit(Cmp.is_lt(B.ucmp(n, x, y)), bin(A.BLt{}, ea, eb))

def ugt(+n: Nat, a: S<n>, b: S<n>) -> S<1n>:
  match a b:
    case S{x, ea} S{y, eb}:
      cmp_bit(Cmp.is_gt(B.ucmp(n, x, y)), bin(A.BGt{}, ea, eb))

# $signed(a) < $signed(b) and $signed(a) > $signed(b)
def slt(+n: Nat, a: S<n>, b: S<n>) -> S<1n>:
  match a b:
    case S{+x, ea} S{+y, eb}:
      cmp_bit(Cmp.is_lt(B.scmp(n, x, y)), bin(A.BLt{}, signed(ea), signed(eb)))

def sgt(+n: Nat, a: S<n>, b: S<n>) -> S<1n>:
  match a b:
    case S{+x, ea} S{+y, eb}:
      cmp_bit(Cmp.is_gt(B.scmp(n, x, y)), bin(A.BGt{}, signed(ea), signed(eb)))

# {hi, lo}
def cat(+n: Nat, -m: Nat, hi: S<m>, lo: S<n>) -> S<Nat.add(n, m)>:
  match hi lo:
    case S{x, ehi} S{y, elo}:
      S{B.cat(n, m, y, x), A.VCat{A.VCon{ehi, A.VCon{elo, A.VNil{}}}}}

# {k{a}}: a repeated k times
def rep.w(k: Nat, +n: Nat, +w: Word(n)) -> Word(Nat.mul(k, n)):
  match k:
    case 0n:
      WNil{}
    case 1n+p:
      B.cat(n, Nat.mul(p, n), w, rep.w(p, n, w))

def rep(+k: Nat, +n: Nat, a: S<n>) -> S<Nat.mul(k, n)>:
  match a:
    case S{+x, ea}:
      S{rep.w(k, n, x), A.VRep{A.VNum{None{}, A.RDec{}, k}, A.VCon{ea, A.VNil{}}}}

def num(n: Nat) -> A.Expr:
  A.VNum{None{}, A.RDec{}, n}

# a[hi:lo]
def bits(+n: Nat, +hi: Nat, +lo: Nat, a: S<n>) -> S<1n+Nat.sub(hi, lo)>:
  match a:
    case S{x, ea}:
      S{B.bits(n, hi, lo, x), A.VSli{ea, num(hi), num(lo)}}

# a[k], as a 1-bit signal
def bit(+n: Nat, +k: Nat, a: S<n>) -> S<1n>:
  match a:
    case S{x, ea}:
      S{B.bit1(B.bit(k, n, x)), A.VIdx{ea, num(k)}}

# a[hi:lo] sign-extended to m bits: {{k{a[hi]}}, a[hi:lo]} (m above the
# slice's width)
def sx(+n: Nat, +hi: Nat, +lo: Nat, +m: Nat, a: S<n>) -> S<m>:
  match a:
    case S{x, +ea}:
      S{B.sext(1n+Nat.sub(hi, lo), m, B.bits(n, hi, lo, x)), A.VCat{A.VCon{A.VRep{num(Nat.sub(m, 1n+Nat.sub(hi, lo))), A.VCon{A.VIdx{ea, num(hi)}, A.VNil{}}}, A.VCon{A.VSli{ea, num(hi), num(lo)}, A.VNil{}}}}}

# a[hi:lo] zero-extended to m bits: {k'h0, a[hi:lo]}
def zx(+n: Nat, +hi: Nat, +lo: Nat, +m: Nat, a: S<n>) -> S<m>:
  match a:
    case S{x, +ea}:
      S{B.zext(1n+Nat.sub(hi, lo), m, B.bits(n, hi, lo, x)), A.VCat{A.VCon{A.VNum{Some{Nat.sub(m, 1n+Nat.sub(hi, lo))}, A.RHex{}, 0n}, A.VCon{A.VSli{ea, num(hi), num(lo)}, A.VNil{}}}}}

# |a: is any bit set?
def any(+n: Nat, a: S<n>) -> S<1n>:
  match a:
    case S{x, ea}:
      cmp_bit(Bool.not(B.is_zero(n, x)), A.VUn{A.UROr{}, ea})

def eqk(e: A.Expr, +n: Nat, k: Nat) -> A.Expr:
  bin(A.BEq{}, e, A.VNum{Some{n}, A.RHex{}, k})

# the chain a == 0 ? x0 : a == 1 ? x1 : .. : x(last), over the names xs
def pick_named(xs: List<&2, String>, +e: A.Expr, +n: Nat, +k: Nat) -> A.Expr:
  match xs:
    case Nil{}:
      A.VNum{Some{1n}, A.RBin{}, 0n}
    case Con{x, Nil{}}:
      A.VId{x}
    case Con{x, t}:
      A.VCond{eqk(e, n, k), A.VId{x}, pick_named(t, e, n, 1n+k)}

# a register file read: the word at address a, from registers named rs
# (one per address, address 0 first)
def rf_read(+w: Nat, +n: Nat, m: M.Mem<w>, rs: List<&2, String>, a: S<n>) -> S<w>:
  match a:
    case S{+x, ea}:
      S{M.get(w, n, x, m), pick_named(rs, ea, n, 0n)}

# Building
# --------

# the items declared so far, last first
type St is Data:
  St{items: List<&2, A.Item>}

type Out<-R: Type> is Type:
  Out{val: R, st: St}

# a circuit fragment producing an R
def Build(R: Type) -> Type:
  St -> Out<R>

def Build.pure(-R: Type, x: R) -> Build(R):
  s => Out{x, s}

def Build.bind.go(-R: Type, -T: Type, o: Out<R>, f: R -> Build(T)) -> Out<T>:
  match o:
    case Out{x, s}:
      f(x)(s)

def Build.bind(-R: Type, -T: Type, m: Build(R), f: R -> Build(T)) -> Build(T):
  s => Build.bind.go(R, T, m(s), f)

def emit.go(i: A.Item, s: St) -> Out<Unit>:
  match s:
    case St{xs}:
      Out{Unit{}, St{i <> xs}}

# declares an item
def emit(i: A.Item) -> Build(Unit):
  s => emit.go(i, s)

def range(+n: Nat) -> Maybe<&2, A.Range>:
  match n:
    case 0n:
      None{}
    case 1n+p:
      match p:
        case 0n:
          None{}
        case 1n+q:
          Some{A.Range{num(1n+q), num(0n)}}

# wire [n-1:0] x = s; then s, named x
def wire(+n: Nat, +x: String, s: S<n>) -> Build(S<n>):
  match s:
    case S{w, e}:
      Build.bind(Unit, S<n>, emit(A.INet{A.NWire{}, False{}, range(n), [A.Decl{x, Some{e}}]}), u => Build.pure(S<n>, S{w, A.VId{x}}))

def run.go(-R: Type, o: Out<R>) -> R & List<&2, A.Item>:
  match o:
    case Out{x, St{xs}}:
      (x, List.reverse(&2, A.Item, xs))

# runs a fragment from nothing declared: its result and its items in order
def run(-R: Type, m: Build(R)) -> R & List<&2, A.Item>:
  run.go(R, m(St{Nil{}}))
