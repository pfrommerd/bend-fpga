# hdl/verilog/print.bend: the AST to tokens, and tokens to text.
#
# Every printer takes the tokens that follow (k) and puts its own in front:
# that is the shape the round-trip law (LAWS.bend) is proven in. Every
# compound expression is printed in parentheses, so the parser rebuilds
# exactly the printed tree, whatever the precedences.

import Base
import ./ast.bend as A
import ./tok.bend as K

def sym(s: K.Sym, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  K.KSym{s} <> k

def kw(w: K.Kw, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  K.KKw{w} <> k

def id(s: String, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  K.KId{s} <> k

# Operators
# ---------

def UOp.sym(o: A.UOp) -> K.Sym:
  match o:
    case A.UNot{}:
      K.PTilde{}
    case A.ULNot{}:
      K.PBang{}
    case A.UNeg{}:
      K.PMinus{}
    case A.URAnd{}:
      K.PAmp{}
    case A.UROr{}:
      K.PPipe{}
    case A.URXor{}:
      K.PCaret{}

def BOp.sym(o: A.BOp) -> K.Sym:
  match o:
    case A.BMul{}:
      K.PStar{}
    case A.BDiv{}:
      K.PSlash{}
    case A.BMod{}:
      K.PPercent{}
    case A.BAdd{}:
      K.PPlus{}
    case A.BSub{}:
      K.PMinus{}
    case A.BShl{}:
      K.PShl{}
    case A.BShr{}:
      K.PShr{}
    case A.BSshl{}:
      K.PSshl{}
    case A.BSshr{}:
      K.PSshr{}
    case A.BLt{}:
      K.PLt{}
    case A.BLe{}:
      K.PLe{}
    case A.BGt{}:
      K.PGt{}
    case A.BGe{}:
      K.PGe{}
    case A.BEq{}:
      K.PEqEq{}
    case A.BNe{}:
      K.PNe{}
    case A.BAnd{}:
      K.PAmp{}
    case A.BXor{}:
      K.PCaret{}
    case A.BOr{}:
      K.PPipe{}
    case A.BLAnd{}:
      K.PAndAnd{}
    case A.BLOr{}:
      K.POrOr{}

# Expressions
# -----------

# an expression (or a VCon list of them, comma-separated), then k
def expr(e: A.Expr, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match e:
    case A.VId{s}:
      id(s, k)
    case A.VNum{size, r, v}:
      K.KNum{size, r, v} <> k
    case A.VIdx{x, i}:
      expr(x, sym(K.PLBrack{}, expr(i, sym(K.PRBrack{}, k))))
    case A.VSli{x, hi, lo}:
      expr(x, sym(K.PLBrack{}, expr(hi, sym(K.PColon{}, expr(lo, sym(K.PRBrack{}, k))))))
    case A.VUn{o, x}:
      sym(K.PLParen{}, sym(UOp.sym(o), expr(x, sym(K.PRParen{}, k))))
    case A.VBin{o, a, b}:
      sym(K.PLParen{}, expr(a, sym(BOp.sym(o), expr(b, sym(K.PRParen{}, k)))))
    case A.VCond{c, a, b}:
      sym(K.PLParen{}, expr(c, sym(K.PQuest{}, expr(a, sym(K.PColon{}, expr(b, sym(K.PRParen{}, k)))))))
    case A.VCat{es}:
      sym(K.PLBrace{}, expr(es, sym(K.PRBrace{}, k)))
    case A.VRep{n, es}:
      sym(K.PLBrace{}, expr(n, sym(K.PLBrace{}, expr(es, sym(K.PRBrace{}, sym(K.PRBrace{}, k))))))
    case A.VSys{s, args}:
      K.KSys{s} <> sym(K.PLParen{}, expr(args, sym(K.PRParen{}, k)))
    case A.VNil{}:
      k
    case A.VCon{h, A.VNil{}}:
      expr(h, k)
    case A.VCon{h, t}:
      expr(h, sym(K.PComma{}, expr(t, k)))

# Declarations
# ------------

def range(r: Maybe<&2, A.Range>, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match r:
    case None{}:
      k
    case Some{A.Range{hi, lo}}:
      sym(K.PLBrack{}, expr(hi, sym(K.PColon{}, expr(lo, sym(K.PRBrack{}, k)))))

def net(n: A.Net, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match n:
    case A.NWire{}:
      kw(K.KwWire{}, k)
    case A.NReg{}:
      kw(K.KwReg{}, k)
    case A.NNone{}:
      k

def dir(d: A.Dir, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match d:
    case A.DIn{}:
      kw(K.KwInput{}, k)
    case A.DOut{}:
      kw(K.KwOutput{}, k)
    case A.DInout{}:
      kw(K.KwInout{}, k)

# a, b, c (a non-empty list of names)
def names(ns: List<&2, String>, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match ns:
    case Nil{}:
      k
    case Con{h, Nil{}}:
      id(h, k)
    case Con{h, t}:
      id(h, sym(K.PComma{}, names(t, k)))

def port(p: A.Port, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match p:
    case A.Port{d, n, r, ns}:
      dir(d, net(n, range(r, names(ns, k))))

def ports(ps: List<&2, A.Port>, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match ps:
    case Nil{}:
      k
    case Con{h, Nil{}}:
      port(h, k)
    case Con{h, t}:
      port(h, sym(K.PComma{}, ports(t, k)))

def param(p: A.Param, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match p:
    case A.Param{n, v}:
      id(n, sym(K.PEq{}, expr(v, k)))

def params.list(ps: List<&2, A.Param>, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match ps:
    case Nil{}:
      k
    case Con{h, Nil{}}:
      param(h, k)
    case Con{h, t}:
      param(h, sym(K.PComma{}, params.list(t, k)))

# #(parameter n = 16, r = 0), or nothing
def params(ps: List<&2, A.Param>, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match ps:
    case Nil{}:
      k
    case ps:
      sym(K.PHash{}, sym(K.PLParen{}, kw(K.KwParameter{}, params.list(ps, sym(K.PRParen{}, k)))))

def decl(d: A.Decl, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match d:
    case A.Decl{n, None{}}:
      id(n, k)
    case A.Decl{n, Some{e}}:
      id(n, sym(K.PEq{}, expr(e, k)))

def decls(ds: List<&2, A.Decl>, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match ds:
    case Nil{}:
      k
    case Con{h, Nil{}}:
      decl(h, k)
    case Con{h, t}:
      decl(h, sym(K.PComma{}, decls(t, k)))

def conn(c: A.Conn, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match c:
    case A.Conn{Some{p}, None{}}:
      sym(K.PDot{}, id(p, sym(K.PLParen{}, sym(K.PRParen{}, k))))
    case A.Conn{Some{p}, Some{e}}:
      sym(K.PDot{}, id(p, sym(K.PLParen{}, expr(e, sym(K.PRParen{}, k)))))
    case A.Conn{None{}, Some{e}}:
      expr(e, k)
    case A.Conn{None{}, None{}}:
      k

def conns(cs: List<&2, A.Conn>, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match cs:
    case Nil{}:
      k
    case Con{h, Nil{}}:
      conn(h, k)
    case Con{h, t}:
      conn(h, sym(K.PComma{}, conns(t, k)))

def sens1(s: A.Sens, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match s:
    case A.SPos{n}:
      kw(K.KwPosedge{}, id(n, k))
    case A.SNeg{n}:
      kw(K.KwNegedge{}, id(n, k))
    case A.SAll{}:
      sym(K.PStar{}, k)

def sens(ss: List<&2, A.Sens>, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match ss:
    case Nil{}:
      k
    case Con{h, Nil{}}:
      sens1(h, k)
    case Con{h, t}:
      sens1(h, sym(K.PComma{}, sens(t, k)))

# Statements
# ----------

def stmt(s: A.Stmt, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match s:
    case A.TBlock{b}:
      kw(K.KwBegin{}, stmt(b, kw(K.KwEnd{}, k)))
    case A.TIf{c, t, A.TSkip{}}:
      kw(K.KwIf{}, sym(K.PLParen{}, expr(c, sym(K.PRParen{}, stmt(t, k)))))
    case A.TIf{c, t, e}:
      kw(K.KwIf{}, sym(K.PLParen{}, expr(c, sym(K.PRParen{}, stmt(t, kw(K.KwElse{}, stmt(e, k)))))))
    case A.TSet{l, r}:
      expr(l, sym(K.PEq{}, expr(r, sym(K.PSemi{}, k))))
    case A.TSetNb{l, r}:
      expr(l, sym(K.PLe{}, expr(r, sym(K.PSemi{}, k))))
    case A.TSkip{}:
      sym(K.PSemi{}, k)
    case A.TNil{}:
      k
    case A.TCon{h, t}:
      stmt(h, stmt(t, k))

# Items
# -----

def delay(d: Maybe<&2, A.Expr>, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match d:
    case None{}:
      k
    case Some{e}:
      sym(K.PHash{}, sym(K.PLParen{}, expr(e, sym(K.PRParen{}, k))))

def signed(s: Bool, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match s:
    case True{}:
      kw(K.KwSigned{}, k)
    case False{}:
      k

def label(l: Maybe<&2, String>, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match l:
    case None{}:
      k
    case Some{n}:
      sym(K.PColon{}, id(n, k))

def iparams(ps: List<&2, A.Conn>, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match ps:
    case Nil{}:
      k
    case ps:
      sym(K.PHash{}, sym(K.PLParen{}, conns(ps, sym(K.PRParen{}, k))))

def local(l: Bool) -> K.Kw:
  match l:
    case True{}:
      K.KwLocalparam{}
    case False{}:
      K.KwParameter{}

def item(i: A.Item, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match i:
    case A.INet{n, s, r, ds}:
      net(n, signed(s, range(r, decls(ds, sym(K.PSemi{}, k)))))
    case A.IAssign{d, l, r}:
      kw(K.KwAssign{}, delay(d, expr(l, sym(K.PEq{}, expr(r, sym(K.PSemi{}, k))))))
    case A.IGenvar{ns}:
      kw(K.KwGenvar{}, names(ns, sym(K.PSemi{}, k)))
    case A.IParam{l, n, v}:
      kw(local(l), id(n, sym(K.PEq{}, expr(v, sym(K.PSemi{}, k)))))
    case A.IFor{+v, init, cond, step, l, body}:
      kw(K.KwFor{}, sym(K.PLParen{}, id(v, sym(K.PEq{}, expr(init, sym(K.PSemi{}, expr(cond, sym(K.PSemi{}, id(v, sym(K.PEq{}, expr(step, sym(K.PRParen{}, kw(K.KwBegin{}, label(l, item(body, kw(K.KwEnd{}, k))))))))))))))))
    case A.IInst{m, ps, n, cs}:
      id(m, iparams(ps, id(n, sym(K.PLParen{}, conns(cs, sym(K.PRParen{}, sym(K.PSemi{}, k)))))))
    case A.IAlways{ss, b}:
      kw(K.KwAlways{}, sym(K.PAt{}, sym(K.PLParen{}, sens(ss, sym(K.PRParen{}, stmt(b, k))))))
    case A.INil{}:
      k
    case A.ICon{h, t}:
      item(h, item(t, k))

# Modules
# -------

def module(m: A.Module, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match m:
    case A.Module{n, ps, pts, b}:
      kw(K.KwModule{}, id(n, params(ps, sym(K.PLParen{}, ports(pts, sym(K.PRParen{}, sym(K.PSemi{}, item(b, kw(K.KwEndmodule{}, k)))))))))

def modules(ms: List<&2, A.Module>, k: List<&2, K.Tok>) -> List<&2, K.Tok>:
  match ms:
    case Nil{}:
      k
    case Con{h, t}:
      module(h, modules(t, k))

# the tokens of a design
def design(d: A.Design) -> List<&2, K.Tok>:
  match d:
    case A.Design{ms}:
      modules(ms, Nil{})

# Text
# ----

def digit(d: Nat) -> Char:
  Chr{U32.from_nat(Nat.add(d, 48n))}

def hexdigit.if(+d: Nat, big: Bool) -> Char:
  match big:
    case True{}:
      Chr{U32.from_nat(Nat.add(d, 87n))}
    case False{}:
      digit(d)

def hexdigit(+d: Nat) -> Char:
  hexdigit.if(d, Nat.is_ge(d, 10n))

# exactly n digits of v in base b, most significant first
def pad(n: Nat, +b: Nat, +v: Nat, acc: String) -> String:
  match n:
    case 0n:
      acc
    case 1n+p:
      pad(p, b, Nat.div(v, b), SCon{hexdigit(Nat.mod(v, b)), acc})

# the digits of v in base b, with no leading zeros ("0" for 0); f bounds
# the digit count
def digits.go(f: Nat, +b: Nat, +v: Nat, acc: String, stop: Bool) -> String:
  match f stop:
    case 0n _:
      acc
    case 1n+p True{}:
      acc
    case 1n+p False{}:
      +q = Nat.div(v, b)
      digits.go(p, b, q, SCon{hexdigit(Nat.mod(v, b)), acc}, Nat.is_eq(q, 0n))

def digits(+b: Nat, +v: Nat) -> String:
  digits.go(128n, b, v, SNil{}, False{})

def radix.char(r: A.Radix) -> String:
  match r:
    case A.RBin{}:
      "b"
    case A.ROct{}:
      "o"
    case A.RDec{}:
      "d"
    case A.RHex{}:
      "h"

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

# how many digits a size-bit literal takes in radix r (decimal: unpadded)
def radix.width(r: A.Radix, +n: Nat) -> Maybe<&2, Nat>:
  match r:
    case A.RBin{}:
      Some{n}
    case A.ROct{}:
      Some{Nat.div(Nat.add(n, 2n), 3n)}
    case A.RDec{}:
      None{}
    case A.RHex{}:
      Some{Nat.div(Nat.add(n, 3n), 4n)}

def num.digits(w: Maybe<&2, Nat>, +b: Nat, +v: Nat) -> String:
  match w:
    case None{}:
      digits(b, v)
    case Some{n}:
      pad(n, b, v, SNil{})

def num(size: Maybe<&2, Nat>, +r: A.Radix, +v: Nat) -> String:
  match size:
    case None{}:
      match r:
        case A.RDec{}:
          digits(10n, v)
        case r:
          "'" ++ radix.char(r) ++ digits(radix.base(r), v)
    case Some{+n}:
      Nat.show(n) ++ "'" ++ radix.char(r) ++ num.digits(radix.width(r, n), radix.base(r), v)

def text(t: K.Tok) -> String:
  match t:
    case K.KId{s}:
      s
    case K.KKw{w}:
      K.Kw.text(w)
    case K.KSys{s}:
      "$" ++ s
    case K.KNum{size, r, v}:
      num(size, r, v)
    case K.KSym{s}:
      K.Sym.text(s)

# Layout
# ------

# how a token sits against its neighbours: G* glue to one side
type Fit is Data:
  FOpen{}     # ( [ { . # @ ~ !: nothing after
  FClose{}    # ) ] } , ;: nothing before
  FName{}     # identifiers and $calls: ( and [ glue after them
  FWord{}     # everything else

def fit(t: K.Tok) -> Fit:
  match t:
    case K.KId{_}:
      FName{}
    case K.KSys{_}:
      FName{}
    case K.KSym{K.PLParen{}}:
      FOpen{}
    case K.KSym{K.PLBrack{}}:
      FOpen{}
    case K.KSym{K.PLBrace{}}:
      FOpen{}
    case K.KSym{K.PDot{}}:
      FOpen{}
    case K.KSym{K.PHash{}}:
      FOpen{}
    case K.KSym{K.PAt{}}:
      FOpen{}
    case K.KSym{K.PTilde{}}:
      FOpen{}
    case K.KSym{K.PBang{}}:
      FOpen{}
    case K.KSym{K.PRParen{}}:
      FClose{}
    case K.KSym{K.PRBrack{}}:
      FClose{}
    case K.KSym{K.PRBrace{}}:
      FClose{}
    case K.KSym{K.PComma{}}:
      FClose{}
    case K.KSym{K.PSemi{}}:
      FClose{}
    case _:
      FWord{}

# true for ( and [, which glue to a name before them
def opens_call(t: K.Tok) -> Bool:
  match t:
    case K.KSym{K.PLParen{}}:
      True{}
    case K.KSym{K.PLBrack{}}:
      True{}
    case _:
      False{}

def space.go(a: Fit, b: Fit, call: Bool) -> String:
  match a b call:
    case FOpen{} _ _:
      ""
    case _ FClose{} _:
      ""
    case FName{} _ True{}:
      ""
    case _ _ _:
      " "

# a space between two tokens, unless one side glues
def space(p: K.Tok, +t: K.Tok) -> String:
  space.go(fit(p), fit(t), opens_call(t))

def is_end(t: K.Tok) -> Bool:
  match t:
    case K.KKw{K.KwEnd{}}:
      True{}
    case K.KKw{K.KwEndmodule{}}:
      True{}
    case _:
      False{}

def opens_block(t: K.Tok) -> Bool:
  match t:
    case K.KKw{K.KwBegin{}}:
      True{}
    case K.KKw{K.KwModule{}}:
      True{}
    case _:
      False{}

# the newlines before t, after p: 0, 1, or 2 (a blank line)
def breaks(p: K.Tok, t: K.Tok, semi_ends: Bool, comma_ends: Bool, t_end: Bool) -> Nat:
  match p:
    case K.KSym{K.PSemi{}}:
      match semi_ends:
        case True{}:
          1n
        case False{}:
          0n
    case K.KSym{K.PComma{}}:
      match comma_ends:
        case True{}:
          1n
        case False{}:
          0n
    case K.KKw{K.KwBegin{}}:
      match t:
        case K.KSym{K.PColon{}}:
          0n
        case _:
          1n
    case K.KKw{K.KwEnd{}}:
      match t:
        case K.KKw{K.KwElse{}}:
          0n
        case _:
          1n
    case K.KKw{K.KwEndmodule{}}:
      2n
    case _:
      match t_end:
        case True{}:
          1n
        case False{}:
          0n

def indent(n: Nat) -> String:
  match n:
    case 0n:
      ""
    case 1n+p:
      "  " ++ indent(p)

def newlines(n: Nat) -> String:
  match n:
    case 0n:
      ""
    case 1n+p:
      "\n" ++ newlines(p)

def sep.go(+p: K.Tok, +t: K.Tok, lvl: Nat, nl: Nat) -> String:
  match nl:
    case 0n:
      space(p, t)
    case 1n+q:
      newlines(1n+q) ++ indent(lvl)

# the text between p and t, t on nesting level lvl
def sep(+p: K.Tok, +t: K.Tok, lvl: Nat, +pd: Nat, hdr: Bool) -> String:
  sep.go(p, t, lvl, breaks(p, t, Nat.is_eq(pd, 0n), Bool.and(hdr, Nat.is_eq(pd, 1n)), is_end(t)))

# the level of t's line, and the level after t
def lvl_at.if(+lvl: Nat, e: Bool) -> Nat:
  match e:
    case True{}:
      Nat.sub(lvl, 1n)
    case False{}:
      lvl

def lvl_at(+t: K.Tok, +lvl: Nat) -> Nat:
  lvl_at.if(lvl, is_end(t))

def lvl_after.if(+lvl: Nat, o: Bool) -> Nat:
  match o:
    case True{}:
      1n+lvl
    case False{}:
      lvl

def lvl_after(+t: K.Tok, +lvl: Nat) -> Nat:
  lvl_after.if(lvl, opens_block(t))

# the parenthesis depth after t
def pd_after(t: K.Tok, +pd: Nat) -> Nat:
  match t:
    case K.KSym{K.PLParen{}}:
      1n+pd
    case K.KSym{K.PRParen{}}:
      Nat.sub(pd, 1n)
    case _:
      pd

# inside a module header (ports go one per line)?
def hdr_after(t: K.Tok, hdr: Bool, +pd: Nat) -> Bool:
  match t:
    case K.KKw{K.KwModule{}}:
      True{}
    case K.KSym{K.PSemi{}}:
      Bool.and(hdr, Bool.not(Nat.is_eq(pd, 0n)))
    case _:
      hdr

def render.go(ts: List<&2, K.Tok>, +p: K.Tok, +lvl: Nat, +pd: Nat, +hdr: Bool, acc: List<&2, String>) -> List<&2, String>:
  match ts:
    case Nil{}:
      List.reverse(&2, String, acc)
    case Con{+t, rest}:
      +l2 = lvl_at(t, lvl)
      render.go(rest, t, lvl_after(t, l2), pd_after(t, pd), hdr_after(t, hdr, pd), text(t) <> sep(p, t, l2, pd, hdr) <> acc)

# the text of a token list: tokens never touch where the lexer would read
# them as one
def render(ts: List<&2, K.Tok>) -> String:
  match ts:
    case Nil{}:
      ""
    case Con{+t, rest}:
      String.concat(render.go(rest, t, lvl_after(t, 0n), pd_after(t, 0n), hdr_after(t, False{}, 0n), [text(t)])) ++ "\n"
