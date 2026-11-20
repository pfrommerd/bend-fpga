# hdl/bits.bend: bit-vector helpers on Base's Word(n).
#
# A Word(n) is n bits, least significant first: WCon{bit0, WCon{bit1, ..}}.
# Verilog's w[hi:lo] is bits(n, hi, lo, w) and {hi, lo} is cat(lo, hi).

import Base

# Literals
# --------

# Nat.div and Nat.mod run as machine division at runtime
def half(n: Nat) -> Nat:
  Nat.div(n, 2n)

def odd(n: Nat) -> Bool:
  Nat.is_eq(Nat.mod(n, 2n), 1n)

# the low n bits of k
def of_nat(n: Nat, +k: Nat) -> Word(n):
  match n:
    case 0n:
      WNil{}
    case 1n+p:
      WCon{odd(k), of_nat(p, half(k))}

def to_nat(n: Nat, w: Word(n)) -> Nat:
  Word.to_nat(n, w)

def zero(n: Nat) -> Word(n):
  Word.zero(n)

# the single bit b, as a Word(1n)
def bit1(b: Bool) -> Word(1n):
  WCon{b, WNil{}}

# Bits and fields
# ---------------

def msb.go(p: Nat, h: Bool, t: Word(p)) -> Bool:
  match p:
    case 0n:
      h
    case 1n+q:
      match t:
        case WCon{h2, t2}:
          msb.go(q, h2, t2)

# the most significant bit (the sign); False on Word(0n)
def msb(n: Nat, w: Word(n)) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      match w:
        case WCon{h, t}:
          msb.go(p, h, t)

# the lowest bit; False on Word(0n)
def lsb(n: Nat, w: Word(n)) -> Bool:
  match n:
    case 0n:
      False{}
    case 1n+p:
      match w:
        case WCon{h, t}:
          h

# bit k of w (Verilog w[k]); False past the top
def bit(k: Nat, n: Nat, w: Word(n)) -> Bool:
  match k:
    case 0n:
      lsb(n, w)
    case 1n+kp:
      match n:
        case 0n:
          False{}
        case 1n+p:
          match w:
            case WCon{h, t}:
              bit(kp, p, t)

# resizes w to m bits: truncates, or pads the top with fill
def ext(m: Nat, n: Nat, +fill: Bool, w: Word(n)) -> Word(m):
  match m:
    case 0n:
      WNil{}
    case 1n+mp:
      match n:
        case 0n:
          WCon{fill, ext(mp, 0n, fill, WNil{})}
        case 1n+np:
          match w:
            case WCon{h, t}:
              WCon{h, ext(mp, np, fill, t)}

# zero-extension (or truncation) of w to m bits
def zext(n: Nat, m: Nat, w: Word(n)) -> Word(m):
  ext(m, n, False{}, w)

# sign-extension (or truncation) of w to m bits
def sext(+n: Nat, m: Nat, +w: Word(n)) -> Word(m):
  ext(m, n, msb(n, w), w)

# len bits of w starting at bit lo; zeros past the top
def slice(n: Nat, lo: Nat, len: Nat, w: Word(n)) -> Word(len):
  match n:
    case 0n:
      Word.zero(len)
    case 1n+np:
      match lo:
        case 0n:
          ext(len, 1n+np, False{}, w)
        case 1n+lp:
          match w:
            case WCon{h, t}:
              slice(np, lp, len, t)

# Verilog's w[hi:lo]
def bits(n: Nat, +hi: Nat, +lo: Nat, w: Word(n)) -> Word(1n+Nat.sub(hi, lo)):
  slice(n, lo, 1n+Nat.sub(hi, lo), w)

# Verilog's {hi, lo}: lo fills the low n bits
def cat(n: Nat, -m: Nat, lo: Word(n), hi: Word(m)) -> Word(Nat.add(n, m)):
  match n:
    case 0n:
      hi
    case 1n+p:
      match lo:
        case WCon{h, t}:
          WCon{h, cat(p, m, t, hi)}

# Shifts
# ------

# shifts right by one, filling the top with fill
def shr_fill(+n: Nat, fill: Bool, w: Word(n)) -> Word(n):
  match n:
    case 0n:
      WNil{}
    case 1n+p:
      match w:
        case WCon{h, t}:
          ext(1n+p, p, fill, t)

def srl1(n: Nat, w: Word(n)) -> Word(n):
  shr_fill(n, False{}, w)

def sra1(+n: Nat, +w: Word(n)) -> Word(n):
  shr_fill(n, msb(n, w), w)

# Verilog's w << k, w >> k and $signed(w) >>> k, for a Nat count k
def shl_by(k: Nat, +n: Nat, w: Word(n)) -> Word(n):
  match k:
    case 0n:
      w
    case 1n+p:
      shl_by(p, n, Word.shl(n, w))

def srl_by(k: Nat, +n: Nat, w: Word(n)) -> Word(n):
  match k:
    case 0n:
      w
    case 1n+p:
      srl_by(p, n, srl1(n, w))

def sra_by(k: Nat, +n: Nat, w: Word(n)) -> Word(n):
  match k:
    case 0n:
      w
    case 1n+p:
      sra_by(p, n, sra1(n, w))

# true when every bit is 0
def is_zero(n: Nat, w: Word(n)) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+p:
      match w:
        case WCon{h, t}:
          match h:
            case True{}:
              False{}
            case False{}:
              is_zero(p, t)

# Arithmetic
# ----------

def add(n: Nat, a: Word(n), b: Word(n)) -> Word(n):
  Word.add(n, a, b)

def sub(n: Nat, a: Word(n), b: Word(n)) -> Word(n):
  Word.sub(n, a, b)

def inc(n: Nat, a: Word(n)) -> Word(n):
  Word.inc(n, a)

# the low n bits of the product, defined on Nat
def mul(+n: Nat, a: Word(n), b: Word(n)) -> Word(n):
  of_nat(n, Nat.mul(to_nat(n, a), to_nat(n, b)))

def div.if(+n: Nat, z: Bool, a: Word(n), b: Word(n)) -> Word(n):
  match z:
    case True{}:
      Word.zero(n)
    case False{}:
      of_nat(n, Nat.div(to_nat(n, a), to_nat(n, b)))

def mod.if(+n: Nat, z: Bool, a: Word(n), b: Word(n)) -> Word(n):
  match z:
    case True{}:
      Word.zero(n)
    case False{}:
      of_nat(n, Nat.mod(to_nat(n, a), to_nat(n, b)))

# unsigned quotient and remainder, defined on Nat; both 0 when b is 0
def udiv(+n: Nat, a: Word(n), +b: Word(n)) -> Word(n):
  div.if(n, is_zero(n, b), a, b)

def umod(+n: Nat, a: Word(n), +b: Word(n)) -> Word(n):
  mod.if(n, is_zero(n, b), a, b)

# Logic
# -----

def and(n: Nat, a: Word(n), b: Word(n)) -> Word(n):
  Word.and(n, a, b)

def or(n: Nat, a: Word(n), b: Word(n)) -> Word(n):
  Word.or(n, a, b)

def xor(n: Nat, a: Word(n), b: Word(n)) -> Word(n):
  Word.xor(n, a, b)

def not(n: Nat, a: Word(n)) -> Word(n):
  Word.not(n, a)

# Comparison
# ----------

# unsigned comparison
def ucmp(n: Nat, a: Word(n), b: Word(n)) -> Cmp:
  Word.cmp(n, a, b)

def scmp.go(sa: Bool, sb: Bool, u: Cmp) -> Cmp:
  match sa sb:
    case True{} False{}:
      LT{}
    case False{} True{}:
      GT{}
    case _ _:
      u

# two's complement comparison: a negative word is below every other
def scmp(+n: Nat, +a: Word(n), +b: Word(n)) -> Cmp:
  scmp.go(msb(n, a), msb(n, b), Word.cmp(n, a, b))

def eq(n: Nat, a: Word(n), b: Word(n)) -> Bool:
  Cmp.is_eq(Word.cmp(n, a, b))

# Selection
# ---------

# Verilog's c ? a : b, on words
def pick(-n: Nat, c: Bool, a: Word(n), b: Word(n)) -> Word(n):
  match c:
    case True{}:
      a
    case False{}:
      b
