# hdl/verilog/lex.bend: Verilog text to tokens.
#
# Drops whitespace, // and /* */ comments, and the directives the AST does
# not keep: `timescale, `default_nettype, `include and `define lines, and
# `ifndef NDEBUG .. `endif blocks (NDEBUG is the only macro taken as
# defined, as the CIS 371 grading scripts build).

import Base
import ./ast.bend as A
import ./tok.bend as K

# Characters
# ----------

type Cls is Data:
  CSpace{}
  CAlpha{}   # a-z A-Z _
  CDigit{}   # 0-9
  CTick{}    # '
  CDollar{}  # $
  CBack{}    # `
  COther{}   # anything else: operators and punctuation

# a character with its class
type LC is Data:
  LC{k: Cls, c: Char}

def in(+x: U32, lo: U32, hi: U32) -> Bool:
  Bool.and(U32.is_ge(x, lo), U32.is_le(x, hi))

def cls.pick(alpha: Bool, digit: Bool, space: Bool, tick: Bool, dollar: Bool, back: Bool) -> Cls:
  match alpha digit space tick dollar back:
    case True{} _ _ _ _ _:
      CAlpha{}
    case False{} True{} _ _ _ _:
      CDigit{}
    case False{} False{} True{} _ _ _:
      CSpace{}
    case False{} False{} False{} True{} _ _:
      CTick{}
    case False{} False{} False{} False{} True{} _:
      CDollar{}
    case False{} False{} False{} False{} False{} True{}:
      CBack{}
    case False{} False{} False{} False{} False{} False{}:
      COther{}

def cls(+x: U32) -> Cls:
  +alpha = Bool.or(Bool.or(in(x, 97, 122), in(x, 65, 90)), U32.is_eq(x, 95))
  cls.pick(alpha, in(x, 48, 57), U32.is_le(x, 32), U32.is_eq(x, 39), U32.is_eq(x, 36), U32.is_eq(x, 96))

# the characters of s with their classes
def classify.go(s: String, acc: List<&2, LC>) -> List<&2, LC>:
  match s:
    case SNil{}:
      List.reverse(&2, LC, acc)
    case SCon{Chr{+x}, t}:
      classify.go(t, LC{cls(x), Chr{x}} <> acc)

def classify(s: String) -> List<&2, LC>:
  classify.go(s, Nil{})

# Scanners
# --------

def str1(c: Char) -> String:
  SCon{c, SNil{}}

def str2(a: Char, b: Char) -> String:
  SCon{a, SCon{b, SNil{}}}

def str3(a: Char, b: Char, c: Char) -> String:
  SCon{a, SCon{b, SCon{c, SNil{}}}}

# the longest run of identifier characters, and what follows it
def word.go(cs: List<&2, LC>, acc: String) -> String & List<&2, LC>:
  match cs:
    case Nil{}:
      (String.reverse(acc), Nil{})
    case Con{LC{CAlpha{}, c}, t}:
      word.go(t, SCon{c, acc})
    case Con{LC{CDigit{}, c}, t}:
      word.go(t, SCon{c, acc})
    case Con{LC{CDollar{}, c}, t}:
      word.go(t, SCon{c, acc})
    case Con{x, t}:
      (String.reverse(acc), Con{x, t})

def word(cs: List<&2, LC>) -> String & List<&2, LC>:
  word.go(cs, SNil{})

def digit.val(+x: U32, num: Bool) -> Nat:
  match num:
    case True{}:
      U32.to_nat((x - 48 : U32))
    case False{}:
      U32.to_nat(((x .|. 32) - 87 : U32))

def digit.step(+r: Nat, acc: Nat, +x: U32, under: Bool) -> Nat:
  match under:
    case True{}:
      acc
    case False{}:
      Nat.add(Nat.mul(acc, r), digit.val(x, False{}))

# the digits of a number in radix r (an underscore is skipped), with their
# value, and what follows them
def digits(+r: Nat, cs: List<&2, LC>, acc: Nat) -> Nat & List<&2, LC>:
  match cs:
    case Nil{}:
      (acc, Nil{})
    case Con{LC{CDigit{}, Chr{+x}}, t}:
      digits(r, t, Nat.add(Nat.mul(acc, r), digit.val(x, True{})))
    case Con{LC{CAlpha{}, Chr{+x}}, t}:
      digits(r, t, digit.step(r, acc, x, U32.is_eq(x, 95)))
    case Con{x, t}:
      (acc, Con{x, t})

def chr_is(c: Char, x: U32) -> Bool:
  match c:
    case Chr{y}:
      U32.is_eq(y, x)

# true when the characters of cs begin with p
def prefix(p: String, cs: List<&2, LC>) -> Bool:
  match p:
    case SNil{}:
      True{}
    case SCon{+pc, pt}:
      match cs:
        case Nil{}:
          False{}
        case Con{LC{_, c}, t}:
          Bool.and(Char.is_eq(c, pc), prefix(pt, t))

# the characters of cs after the first occurrence of p (hit: cs begins
# with p); none when p never occurs
def skip_until(+cs: List<&2, LC>, +p: String, hit: Bool) -> List<&2, LC>:
  match cs hit:
    case Nil{} _:
      Nil{}
    case Con{x, t} True{}:
      List.drop(&2, LC, Con{x, t}, String.length(p))
    case Con{x, t} False{}:
      skip_until(t, p, prefix(p, t))

def skip(+cs: List<&2, LC>, +p: String) -> List<&2, LC>:
  skip_until(cs, p, prefix(p, cs))

def skip_spaces(cs: List<&2, LC>) -> List<&2, LC>:
  match cs:
    case Con{LC{CSpace{}, _}, t}:
      skip_spaces(t)
    case cs:
      cs

# the characters of cs as a string, up to n of them
def peek(n: Nat, cs: List<&2, LC>) -> String:
  match n:
    case 0n:
      SNil{}
    case 1n+p:
      match cs:
        case Nil{}:
          SNil{}
        case Con{LC{_, c}, t}:
          SCon{c, peek(p, t)}

# The lexer
# ---------

# what one lexing step found
type Step is Data:
  LDone{}
  LSkip{rest: List<&2, LC>}
  LEmit{tok: K.Tok, rest: List<&2, LC>}
  LErr{msg: String}

def is_sym(+s: String) -> Bool:
  Maybe.is_some(&2, K.Sym, K.Sym.of(s))

def sym.emit(+text: String, s: Maybe<&2, K.Sym>, rest: List<&2, LC>) -> Step:
  match s:
    case None{}:
      LErr{"unknown symbol " ++ text}
    case Some{k}:
      LEmit{K.KSym{k}, rest}

def sym(+text: String, rest: List<&2, LC>) -> Step:
  sym.emit(text, K.Sym.of(text), rest)

def op.pick(+c: Char, +t: List<&2, LC>, three: Bool, two: Bool) -> Step:
  match three two:
    case True{} _:
      sym(SCon{c, peek(2n, t)}, List.drop(&2, LC, t, 2n))
    case False{} True{}:
      sym(SCon{c, peek(1n, t)}, List.drop(&2, LC, t, 1n))
    case False{} False{}:
      sym(str1(c), t)

# an operator or punctuation, longest match first
def op(+c: Char, +t: List<&2, LC>) -> Step:
  op.pick(c, t, is_sym(SCon{c, peek(2n, t)}), is_sym(SCon{c, peek(1n, t)}))

def other.pick(+c: Char, +t: List<&2, LC>, line: Bool, block: Bool) -> Step:
  match line block:
    case True{} _:
      LSkip{skip(t, "\n")}
    case False{} True{}:
      LSkip{skip(t, "*/")}
    case False{} False{}:
      op(c, t)

def other(+c: Char, +t: List<&2, LC>) -> Step:
  other.pick(c, t, Bool.and(chr_is(c, 47), prefix("/", t)), Bool.and(chr_is(c, 47), prefix("*", t)))

def radix.pick(b: Bool, o: Bool, d: Bool) -> A.Radix:
  match b o d:
    case True{} _ _:
      A.RBin{}
    case False{} True{} _:
      A.ROct{}
    case False{} False{} True{}:
      A.RDec{}
    case False{} False{} False{}:
      A.RHex{}

def radix.of(+x: U32) -> A.Radix:
  +l = (x .|. 32 : U32)
  radix.pick(U32.is_eq(l, 98), U32.is_eq(l, 111), U32.is_eq(l, 100))

def radix.base(r: A.Radix) -> Nat:
  match r:
    case A.RBin{}:
      2n
    case A.ROct{}:
      8n
    case A.RDec{}:
      10n
    case A.RHex{}:
      16n

def based.go(size: Maybe<&2, Nat>, +r: A.Radix, vr: Nat & List<&2, LC>) -> Step:
  (v, rest) = vr
  LEmit{K.KNum{size, r, v}, rest}

# after the tick of a based literal: the radix letter, then the digits
def based(size: Maybe<&2, Nat>, cs: List<&2, LC>) -> Step:
  match cs:
    case Con{LC{_, Chr{+x}}, t}:
      +r = radix.of(x)
      based.go(size, r, digits(radix.base(r), t, 0n))
    case Nil{}:
      LErr{"a based literal ends after its tick"}

# after the digits of a decimal number: a tick makes them a size
def decimal(vr: Nat & List<&2, LC>) -> Step:
  (v, rest) = vr
  match rest:
    case Con{LC{CTick{}, _}, t}:
      based(Some{v}, t)
    case rest:
      LEmit{K.KNum{None{}, A.RDec{}, v}, rest}

# skips an `ifdef or `ifndef block unless it is kept: NDEBUG is the only
# defined macro
def macro.if(skip_it: Bool, rest: List<&2, LC>) -> Step:
  match skip_it:
    case True{}:
      LSkip{skip(rest, "`endif")}
    case False{}:
      LSkip{rest}

def macro(is_ndef: Bool, mr: String & List<&2, LC>) -> Step:
  (m, rest) = mr
  macro.if(Bool.not(Bool.xor(String.eq(m, "NDEBUG"), is_ndef)), rest)

def directive.pick(ifndef: Bool, ifdef: Bool, keep: Bool, rest: List<&2, LC>) -> Step:
  match ifndef ifdef keep:
    case True{} _ _:
      macro(True{}, word(skip_spaces(rest)))
    case False{} True{} _:
      macro(False{}, word(skip_spaces(rest)))
    case False{} False{} True{}:
      LSkip{rest}
    case False{} False{} False{}:
      LSkip{skip(rest, "\n")}

# a directive: `ifndef/`ifdef blocks, `endif and `else go on; every other
# directive drops its line
def directive(wr: String & List<&2, LC>) -> Step:
  (+w, rest) = wr
  directive.pick(String.eq(w, "ifndef"), String.eq(w, "ifdef"), Bool.or(String.eq(w, "endif"), String.eq(w, "else")), rest)

def ident(c: Char, wr: String & List<&2, LC>) -> Step:
  (w, rest) = wr
  +name = {SCon{c, w} : String}
  LEmit{K.word(name, K.Kw.of(name)), rest}

def sys(wr: String & List<&2, LC>) -> Step:
  (w, rest) = wr
  LEmit{K.KSys{w}, rest}

# one token, a skip, or the end
def next(cs: List<&2, LC>) -> Step:
  match cs:
    case Nil{}:
      LDone{}
    case Con{LC{CSpace{}, _}, t}:
      LSkip{t}
    case Con{LC{CAlpha{}, c}, t}:
      ident(c, word(t))
    case Con{LC{CDollar{}, _}, t}:
      sys(word(t))
    case Con{LC{CDigit{}, Chr{+x}}, t}:
      decimal(digits(10n, t, digit.val(x, True{})))
    case Con{LC{CTick{}, _}, t}:
      based(None{}, t)
    case Con{LC{CBack{}, _}, t}:
      directive(word(t))
    case Con{LC{COther{}, +c}, +t}:
      other(c, t)

def lex.go(fuel: Nat, st: Step, acc: List<&2, K.Tok>) -> Result<&2, &2, String, List<&2, K.Tok>>:
  match fuel:
    case 0n:
      Fail{"the lexer ran out of fuel"}
    case 1n+f:
      match st:
        case LDone{}:
          Done{List.reverse(&2, K.Tok, acc)}
        case LSkip{rest}:
          lex.go(f, next(rest), acc)
        case LEmit{tok, rest}:
          lex.go(f, next(rest), tok <> acc)
        case LErr{msg}:
          Fail{msg}

def count.go(cs: List<&2, LC>, n: Nat) -> Nat:
  match cs:
    case Nil{}:
      n
    case Con{_, t}:
      count.go(t, 1n+n)

# the tokens of a Verilog source; every step consumes a character, so the
# length of the text bounds the steps
def lex(s: String) -> Result<&2, &2, String, List<&2, K.Tok>>:
  +cs = classify(s)
  lex.go(1n+count.go(cs, 0n), next(cs), Nil{})
