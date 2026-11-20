# hdl/verilog/parse.bend: tokens to the AST.
#
# A recursive-descent parser with Verilog's precedences. Bend has no mutual
# recursion and recursion must shrink an argument, so each syntactic
# category is one def that takes a mode (what to parse next) and a fuel
# count, which every recursive call spends; parse gives it a bound larger
# than any parse can use. A decision that depends on a computed value
# (is the next token a binary operator of high enough precedence?) is
# made by a helper and handed to the next call inside its mode.

import Base
import ./ast.bend as A
import ./tok.bend as K

# a parsed A, with the tokens left after it
type Got<-A: Data> is Data:
  Got{val: A, rest: List<&2, K.Tok>}

# a parse of an A: what went wrong, or what was parsed
def PR(A: Data) -> Data:
  Result<&2, &2, String, Got<A>>

def ok(-A: Data, a: A, r: List<&2, K.Tok>) -> PR(A):
  Done{Got{a, r}}

def err(-A: Data, msg: String) -> PR(A):
  Fail{msg}

# runs m, then k on its result and the tokens left
def then(-A: Data, -B: Data, m: PR(A), k: A -> List<&2, K.Tok> -> PR(B)) -> PR(B):
  match m:
    case Fail{e}:
      Fail{e}
    case Done{Got{a, r}}:
      k(a, r)

def Sym.eq(a: K.Sym, b: K.Sym) -> Bool:
  String.eq(K.Sym.text(a), K.Sym.text(b))

def Kw.eq(a: K.Kw, b: K.Kw) -> Bool:
  String.eq(K.Kw.text(a), K.Kw.text(b))

def tok.show(t: K.Tok) -> String:
  match t:
    case K.KId{s}:
      s
    case K.KKw{w}:
      K.Kw.text(w)
    case K.KSys{s}:
      "$" ++ s
    case K.KNum{_, _, v}:
      Nat.show(v)
    case K.KSym{s}:
      K.Sym.text(s)

def near(ts: List<&2, K.Tok>) -> String:
  match ts:
    case Nil{}:
      "the end of the file"
    case Con{t, _}:
      "'" ++ tok.show(t) ++ "'"

def expect.if(-B: Data, +s: K.Sym, t: List<&2, K.Tok>, +all: List<&2, K.Tok>, k: List<&2, K.Tok> -> PR(B), hit: Bool) -> PR(B):
  match hit:
    case True{}:
      k(t)
    case False{}:
      Fail{"expected '" ++ K.Sym.text(s) ++ "' near " ++ near(all)}

# the symbol s, then k on the tokens after it
def expect(-B: Data, +s: K.Sym, ts: List<&2, K.Tok>, k: List<&2, K.Tok> -> PR(B)) -> PR(B):
  match ts:
    case Con{K.KSym{+x}, +t}:
      expect.if(B, s, t, Con{K.KSym{x}, t}, k, Sym.eq(s, x))
    case ts:
      Fail{"expected '" ++ K.Sym.text(s) ++ "' near " ++ near(ts)}

def expect_kw.if(-B: Data, +w: K.Kw, t: List<&2, K.Tok>, +all: List<&2, K.Tok>, k: List<&2, K.Tok> -> PR(B), hit: Bool) -> PR(B):
  match hit:
    case True{}:
      k(t)
    case False{}:
      Fail{"expected '" ++ K.Kw.text(w) ++ "' near " ++ near(all)}

# the keyword w, then k on the tokens after it
def expect_kw(-B: Data, +w: K.Kw, ts: List<&2, K.Tok>, k: List<&2, K.Tok> -> PR(B)) -> PR(B):
  match ts:
    case Con{K.KKw{+x}, +t}:
      expect_kw.if(B, w, t, Con{K.KKw{x}, t}, k, Kw.eq(w, x))
    case ts:
      Fail{"expected '" ++ K.Kw.text(w) ++ "' near " ++ near(ts)}

# an identifier, then k on it and the tokens after it
def ident(-B: Data, ts: List<&2, K.Tok>, k: String -> List<&2, K.Tok> -> PR(B)) -> PR(B):
  match ts:
    case Con{K.KId{s}, t}:
      k(s, t)
    case ts:
      Fail{"expected a name near " ++ near(ts)}

# Operators
# ---------

# whether the binary loop goes on: with which operator, at what precedence
type Dec is Data:
  DStop{}
  DGo{op: A.BOp, prec: Nat}

# a binary operator and its precedence (higher binds tighter); DStop for a
# symbol that is not one
def binop(s: K.Sym) -> Dec:
  match s:
    case K.PStar{}:
      DGo{A.BMul{}, 10n}
    case K.PSlash{}:
      DGo{A.BDiv{}, 10n}
    case K.PPercent{}:
      DGo{A.BMod{}, 10n}
    case K.PPlus{}:
      DGo{A.BAdd{}, 9n}
    case K.PMinus{}:
      DGo{A.BSub{}, 9n}
    case K.PShl{}:
      DGo{A.BShl{}, 8n}
    case K.PShr{}:
      DGo{A.BShr{}, 8n}
    case K.PSshl{}:
      DGo{A.BSshl{}, 8n}
    case K.PSshr{}:
      DGo{A.BSshr{}, 8n}
    case K.PLt{}:
      DGo{A.BLt{}, 7n}
    case K.PLe{}:
      DGo{A.BLe{}, 7n}
    case K.PGt{}:
      DGo{A.BGt{}, 7n}
    case K.PGe{}:
      DGo{A.BGe{}, 7n}
    case K.PEqEq{}:
      DGo{A.BEq{}, 6n}
    case K.PNe{}:
      DGo{A.BNe{}, 6n}
    case K.PAmp{}:
      DGo{A.BAnd{}, 5n}
    case K.PCaret{}:
      DGo{A.BXor{}, 4n}
    case K.PPipe{}:
      DGo{A.BOr{}, 3n}
    case K.PAndAnd{}:
      DGo{A.BLAnd{}, 2n}
    case K.POrOr{}:
      DGo{A.BLOr{}, 1n}
    case _:
      DStop{}

def decide.if(o: A.BOp, +p: Nat, go: Bool) -> Dec:
  match go:
    case True{}:
      DGo{o, p}
    case False{}:
      DStop{}

def decide.op(+minp: Nat, b: Dec) -> Dec:
  match b:
    case DStop{}:
      DStop{}
    case DGo{o, +p}:
      decide.if(o, p, Nat.is_ge(p, minp))

# does the next token continue a binary expression at precedence minp?
def decide(+minp: Nat, ts: List<&2, K.Tok>) -> Dec:
  match ts:
    case Con{K.KSym{s}, _}:
      decide.op(minp, binop(s))
    case _:
      DStop{}

# Expressions
# -----------

type XM is Data:
  XTop{}                                # c ? a : b, or below
  XTern{c: A.Expr}                      # after a condition
  XBin{minp: Nat}                       # a binary expression, operators >= minp
  XLoop{minp: Nat, lhs: A.Expr}         # after an operand
  XGo{minp: Nat, lhs: A.Expr, d: Dec}   # after an operand, the decision made
  XUnary{}                              # ~a, -a, |a .., or a postfix expression
  XAtom{}                               # a name, a number, (e), {..}, $f(..)
  XPost{e: A.Expr}                      # after an atom: [i] and [hi:lo]
  XIdx{e: A.Expr, i: A.Expr}            # after e[i
  XBrace{first: A.Expr}                 # after {first
  XArgs{}                               # a, b, c (one or more)
  XMore{h: A.Expr}                      # after one of a list
  XSysArgs{}                            # the arguments of a $call, maybe none

def px(+fuel: Nat, mode: XM, +ts: List<&2, K.Tok>) -> PR(A.Expr):
  match fuel:
    case 0n:
      Fail{"the parser ran out of fuel"}
    case 1n+f:
      match mode:
        case XTop{}:
          then(A.Expr, A.Expr, px(f, XBin{0n}, ts), c => r => px(f, XTern{c}, r))
        case XTern{c}:
          match ts:
            case Con{K.KSym{K.PQuest{}}, t}:
              then(A.Expr, A.Expr, px(f, XTop{}, t), a => r =>
                expect(A.Expr, K.PColon{}, r, r2 =>
                  then(A.Expr, A.Expr, px(f, XTop{}, r2), b => r3 => ok(A.Expr, A.VCond{c, a, b}, r3))))
            case ts:
              ok(A.Expr, c, ts)
        case XBin{+minp}:
          then(A.Expr, A.Expr, px(f, XUnary{}, ts), a => r => px(f, XLoop{minp, a}, r))
        case XLoop{+minp, lhs}:
          px(f, XGo{minp, lhs, decide(minp, ts)}, ts)
        case XGo{+minp, lhs, d}:
          match d:
            case DStop{}:
              ok(A.Expr, lhs, ts)
            case DGo{o, p}:
              match ts:
                case Con{_, t}:
                  then(A.Expr, A.Expr, px(f, XBin{1n+p}, t), b => r => px(f, XLoop{minp, A.VBin{o, lhs, b}}, r))
                case Nil{}:
                  Fail{"an operator ends the file"}
        case XUnary{}:
          match ts:
            case Con{K.KSym{K.PTilde{}}, t}:
              then(A.Expr, A.Expr, px(f, XUnary{}, t), e => r => ok(A.Expr, A.VUn{A.UNot{}, e}, r))
            case Con{K.KSym{K.PBang{}}, t}:
              then(A.Expr, A.Expr, px(f, XUnary{}, t), e => r => ok(A.Expr, A.VUn{A.ULNot{}, e}, r))
            case Con{K.KSym{K.PMinus{}}, t}:
              then(A.Expr, A.Expr, px(f, XUnary{}, t), e => r => ok(A.Expr, A.VUn{A.UNeg{}, e}, r))
            case Con{K.KSym{K.PAmp{}}, t}:
              then(A.Expr, A.Expr, px(f, XUnary{}, t), e => r => ok(A.Expr, A.VUn{A.URAnd{}, e}, r))
            case Con{K.KSym{K.PPipe{}}, t}:
              then(A.Expr, A.Expr, px(f, XUnary{}, t), e => r => ok(A.Expr, A.VUn{A.UROr{}, e}, r))
            case Con{K.KSym{K.PCaret{}}, t}:
              then(A.Expr, A.Expr, px(f, XUnary{}, t), e => r => ok(A.Expr, A.VUn{A.URXor{}, e}, r))
            case ts:
              then(A.Expr, A.Expr, px(f, XAtom{}, ts), a => r => px(f, XPost{a}, r))
        case XAtom{}:
          match ts:
            case Con{K.KId{s}, t}:
              ok(A.Expr, A.VId{s}, t)
            case Con{K.KNum{size, rdx, v}, t}:
              ok(A.Expr, A.VNum{size, rdx, v}, t)
            case Con{K.KSym{K.PLParen{}}, t}:
              then(A.Expr, A.Expr, px(f, XTop{}, t), e => r =>
                expect(A.Expr, K.PRParen{}, r, r2 => ok(A.Expr, e, r2)))
            case Con{K.KSym{K.PLBrace{}}, t}:
              then(A.Expr, A.Expr, px(f, XTop{}, t), e => r => px(f, XBrace{e}, r))
            case Con{K.KSys{s}, t}:
              expect(A.Expr, K.PLParen{}, t, r =>
                then(A.Expr, A.Expr, px(f, XSysArgs{}, r), args => r2 =>
                  expect(A.Expr, K.PRParen{}, r2, r3 => ok(A.Expr, A.VSys{s, args}, r3))))
            case ts:
              Fail{"expected an expression near " ++ near(ts)}
        case XPost{e}:
          match ts:
            case Con{K.KSym{K.PLBrack{}}, t}:
              then(A.Expr, A.Expr, px(f, XTop{}, t), i => r => px(f, XIdx{e, i}, r))
            case ts:
              ok(A.Expr, e, ts)
        case XIdx{e, i}:
          match ts:
            case Con{K.KSym{K.PRBrack{}}, t}:
              px(f, XPost{A.VIdx{e, i}}, t)
            case Con{K.KSym{K.PColon{}}, t}:
              then(A.Expr, A.Expr, px(f, XTop{}, t), lo => r =>
                expect(A.Expr, K.PRBrack{}, r, r2 => px(f, XPost{A.VSli{e, i, lo}}, r2)))
            case ts:
              Fail{"expected ']' or ':' near " ++ near(ts)}
        case XBrace{first}:
          match ts:
            case Con{K.KSym{K.PLBrace{}}, t}:
              then(A.Expr, A.Expr, px(f, XArgs{}, t), es => r =>
                expect(A.Expr, K.PRBrace{}, r, r2 =>
                  expect(A.Expr, K.PRBrace{}, r2, r3 => ok(A.Expr, A.VRep{first, es}, r3))))
            case ts:
              then(A.Expr, A.Expr, px(f, XMore{first}, ts), es => r =>
                expect(A.Expr, K.PRBrace{}, r, r2 => ok(A.Expr, A.VCat{es}, r2)))
        case XArgs{}:
          then(A.Expr, A.Expr, px(f, XTop{}, ts), h => r => px(f, XMore{h}, r))
        case XMore{h}:
          match ts:
            case Con{K.KSym{K.PComma{}}, t}:
              then(A.Expr, A.Expr, px(f, XArgs{}, t), tl => r => ok(A.Expr, A.VCon{h, tl}, r))
            case ts:
              ok(A.Expr, A.VCon{h, A.VNil{}}, ts)
        case XSysArgs{}:
          match ts:
            case Con{K.KSym{K.PRParen{}}, t}:
              ok(A.Expr, A.VNil{}, Con{K.KSym{K.PRParen{}}, t})
            case ts:
              px(f, XArgs{}, ts)

def expr(+f: Nat, ts: List<&2, K.Tok>, -B: Data, k: A.Expr -> List<&2, K.Tok> -> PR(B)) -> PR(B):
  then(A.Expr, B, px(f, XTop{}, ts), k)

# an lvalue: a name with its [i] and [hi:lo], or a {..} (stops before = and <=)
def lvalue(+f: Nat, ts: List<&2, K.Tok>, -B: Data, k: A.Expr -> List<&2, K.Tok> -> PR(B)) -> PR(B):
  then(A.Expr, B, px(f, XUnary{}, ts), k)

# Declarations
# ------------

# [hi:lo], if there
def range(+f: Nat, ts: List<&2, K.Tok>, -B: Data, k: Maybe<&2, A.Range> -> List<&2, K.Tok> -> PR(B)) -> PR(B):
  match ts:
    case Con{K.KSym{K.PLBrack{}}, t}:
      expr(f, t, B, hi => r =>
        expect(B, K.PColon{}, r, r2 =>
          expr(f, r2, B, lo => r3 =>
            expect(B, K.PRBrack{}, r3, r4 => k(Some{A.Range{hi, lo}}, r4)))))
    case ts:
      k(None{}, ts)

def net(ts: List<&2, K.Tok>, -B: Data, k: A.Net -> List<&2, K.Tok> -> PR(B)) -> PR(B):
  match ts:
    case Con{K.KKw{K.KwWire{}}, t}:
      k(A.NWire{}, t)
    case Con{K.KKw{K.KwReg{}}, t}:
      k(A.NReg{}, t)
    case ts:
      k(A.NNone{}, ts)

def signed(ts: List<&2, K.Tok>, -B: Data, k: Bool -> List<&2, K.Tok> -> PR(B)) -> PR(B):
  match ts:
    case Con{K.KKw{K.KwSigned{}}, t}:
      k(True{}, t)
    case ts:
      k(False{}, ts)

# a, b, c: names, while a comma is followed by a name
def names(+fuel: Nat, ts: List<&2, K.Tok>) -> PR(List<&2, String>):
  match fuel:
    case 0n:
      Fail{"the parser ran out of fuel"}
    case 1n+f:
      match ts:
        case Con{K.KId{s}, Con{K.KSym{K.PComma{}}, Con{K.KId{s2}, t}}}:
          then(List<&2, String>, List<&2, String>, names(f, Con{K.KId{s2}, t}), ns => r => ok(List<&2, String>, s <> ns, r))
        case Con{K.KId{s}, t}:
          ok(List<&2, String>, [s], t)
        case ts:
          Fail{"expected a name near " ++ near(ts)}

def dir(ts: List<&2, K.Tok>) -> PR(A.Dir):
  match ts:
    case Con{K.KKw{K.KwInput{}}, t}:
      ok(A.Dir, A.DIn{}, t)
    case Con{K.KKw{K.KwOutput{}}, t}:
      ok(A.Dir, A.DOut{}, t)
    case Con{K.KKw{K.KwInout{}}, t}:
      ok(A.Dir, A.DInout{}, t)
    case ts:
      Fail{"expected a port direction near " ++ near(ts)}

# input wire [15:0] a, b
def port(+f: Nat, ts: List<&2, K.Tok>) -> PR(A.Port):
  then(A.Dir, A.Port, dir(ts), d => r =>
    net(r, A.Port, n => r2 =>
      range(f, r2, A.Port, rg => r3 =>
        then(List<&2, String>, A.Port, names(f, r3), ns => r4 => ok(A.Port, A.Port{d, n, rg, ns}, r4)))))

# The lists below share a shape: called with None, a list starts (and may
# be empty when its closer comes first); called with Some{x}, x was just
# parsed and a comma continues the list.

# the port groups of a header, up to (not past) its )
def ports(+fuel: Nat, after: Maybe<&2, A.Port>, ts: List<&2, K.Tok>) -> PR(List<&2, A.Port>):
  match fuel:
    case 0n:
      Fail{"the parser ran out of fuel"}
    case 1n+f:
      match after:
        case None{}:
          match ts:
            case Con{K.KSym{K.PRParen{}}, t}:
              ok(List<&2, A.Port>, Nil{}, Con{K.KSym{K.PRParen{}}, t})
            case ts:
              then(A.Port, List<&2, A.Port>, port(f, ts), p => r => ports(f, Some{p}, r))
        case Some{p}:
          match ts:
            case Con{K.KSym{K.PComma{}}, t}:
              then(List<&2, A.Port>, List<&2, A.Port>, ports(f, None{}, t), ps => r => ok(List<&2, A.Port>, p <> ps, r))
            case ts:
              ok(List<&2, A.Port>, [p], ts)

# n = 16, r = 0 (each may repeat the parameter keyword), up to its )
def params(+fuel: Nat, after: Maybe<&2, A.Param>, ts: List<&2, K.Tok>) -> PR(List<&2, A.Param>):
  match fuel:
    case 0n:
      Fail{"the parser ran out of fuel"}
    case 1n+f:
      match after:
        case None{}:
          match ts:
            case Con{K.KKw{K.KwParameter{}}, t}:
              params(f, None{}, t)
            case Con{K.KId{n}, Con{K.KSym{K.PEq{}}, t}}:
              expr(f, t, List<&2, A.Param>, v => r => params(f, Some{A.Param{n, v}}, r))
            case ts:
              Fail{"expected a parameter near " ++ near(ts)}
        case Some{p}:
          match ts:
            case Con{K.KSym{K.PComma{}}, t}:
              then(List<&2, A.Param>, List<&2, A.Param>, params(f, None{}, t), ps => r => ok(List<&2, A.Param>, p <> ps, r))
            case ts:
              ok(List<&2, A.Param>, [p], ts)

def decl(+f: Nat, ts: List<&2, K.Tok>) -> PR(A.Decl):
  match ts:
    case Con{K.KId{n}, Con{K.KSym{K.PEq{}}, t}}:
      expr(f, t, A.Decl, e => r => ok(A.Decl, A.Decl{n, Some{e}}, r))
    case Con{K.KId{n}, t}:
      ok(A.Decl, A.Decl{n, None{}}, t)
    case ts:
      Fail{"expected a name near " ++ near(ts)}

# a, b = e, c: the names a net declaration declares
def decls(+fuel: Nat, after: Maybe<&2, A.Decl>, ts: List<&2, K.Tok>) -> PR(List<&2, A.Decl>):
  match fuel:
    case 0n:
      Fail{"the parser ran out of fuel"}
    case 1n+f:
      match after:
        case None{}:
          then(A.Decl, List<&2, A.Decl>, decl(f, ts), d => r => decls(f, Some{d}, r))
        case Some{d}:
          match ts:
            case Con{K.KSym{K.PComma{}}, t}:
              then(List<&2, A.Decl>, List<&2, A.Decl>, decls(f, None{}, t), ds => r => ok(List<&2, A.Decl>, d <> ds, r))
            case ts:
              ok(List<&2, A.Decl>, [d], ts)

# .port(e), .port(), or e
def conn(+f: Nat, ts: List<&2, K.Tok>) -> PR(A.Conn):
  match ts:
    case Con{K.KSym{K.PDot{}}, Con{K.KId{p}, Con{K.KSym{K.PLParen{}}, Con{K.KSym{K.PRParen{}}, t}}}}:
      ok(A.Conn, A.Conn{Some{p}, None{}}, t)
    case Con{K.KSym{K.PDot{}}, Con{K.KId{p}, Con{K.KSym{K.PLParen{}}, t}}}:
      expr(f, t, A.Conn, e => r => expect(A.Conn, K.PRParen{}, r, r2 => ok(A.Conn, A.Conn{Some{p}, Some{e}}, r2)))
    case ts:
      expr(f, ts, A.Conn, e => r => ok(A.Conn, A.Conn{None{}, Some{e}}, r))

# the connections of an instance (or its parameters), up to its )
def conns(+fuel: Nat, after: Maybe<&2, A.Conn>, ts: List<&2, K.Tok>) -> PR(List<&2, A.Conn>):
  match fuel:
    case 0n:
      Fail{"the parser ran out of fuel"}
    case 1n+f:
      match after:
        case None{}:
          match ts:
            case Con{K.KSym{K.PRParen{}}, t}:
              ok(List<&2, A.Conn>, Nil{}, Con{K.KSym{K.PRParen{}}, t})
            case ts:
              then(A.Conn, List<&2, A.Conn>, conn(f, ts), c => r => conns(f, Some{c}, r))
        case Some{c}:
          match ts:
            case Con{K.KSym{K.PComma{}}, t}:
              then(List<&2, A.Conn>, List<&2, A.Conn>, conns(f, None{}, t), cs => r => ok(List<&2, A.Conn>, c <> cs, r))
            case ts:
              ok(List<&2, A.Conn>, [c], ts)

def sens1(ts: List<&2, K.Tok>) -> PR(A.Sens):
  match ts:
    case Con{K.KKw{K.KwPosedge{}}, Con{K.KId{n}, t}}:
      ok(A.Sens, A.SPos{n}, t)
    case Con{K.KKw{K.KwNegedge{}}, Con{K.KId{n}, t}}:
      ok(A.Sens, A.SNeg{n}, t)
    case Con{K.KSym{K.PStar{}}, t}:
      ok(A.Sens, A.SAll{}, t)
    case ts:
      Fail{"expected posedge, negedge or * near " ++ near(ts)}

# posedge clk, negedge rst (or "or" between them), up to its )
def sens(+fuel: Nat, after: Maybe<&2, A.Sens>, ts: List<&2, K.Tok>) -> PR(List<&2, A.Sens>):
  match fuel:
    case 0n:
      Fail{"the parser ran out of fuel"}
    case 1n+f:
      match after:
        case None{}:
          then(A.Sens, List<&2, A.Sens>, sens1(ts), x => r => sens(f, Some{x}, r))
        case Some{x}:
          match ts:
            case Con{K.KSym{K.PComma{}}, t}:
              then(List<&2, A.Sens>, List<&2, A.Sens>, sens(f, None{}, t), xs => r => ok(List<&2, A.Sens>, x <> xs, r))
            case Con{K.KKw{K.KwOr{}}, t}:
              then(List<&2, A.Sens>, List<&2, A.Sens>, sens(f, None{}, t), xs => r => ok(List<&2, A.Sens>, x <> xs, r))
            case ts:
              ok(List<&2, A.Sens>, [x], ts)

# Statements
# ----------

type SM is Data:
  SOne{}                          # one statement
  SElse{c: A.Expr, t: A.Stmt}     # after if (c) t: maybe an else
  SAssign{l: A.Expr}              # after an lvalue: = or <=
  SList{}                         # statements up to (not past) end

def ps(+fuel: Nat, mode: SM, +ts: List<&2, K.Tok>) -> PR(A.Stmt):
  match fuel:
    case 0n:
      Fail{"the parser ran out of fuel"}
    case 1n+f:
      match mode:
        case SOne{}:
          match ts:
            case Con{K.KKw{K.KwBegin{}}, t}:
              then(A.Stmt, A.Stmt, ps(f, SList{}, t), b => r =>
                expect_kw(A.Stmt, K.KwEnd{}, r, r2 => ok(A.Stmt, A.TBlock{b}, r2)))
            case Con{K.KKw{K.KwIf{}}, t}:
              expect(A.Stmt, K.PLParen{}, t, r =>
                expr(f, r, A.Stmt, c => r2 =>
                  expect(A.Stmt, K.PRParen{}, r2, r3 =>
                    then(A.Stmt, A.Stmt, ps(f, SOne{}, r3), th => r4 => ps(f, SElse{c, th}, r4)))))
            case Con{K.KSym{K.PSemi{}}, t}:
              ok(A.Stmt, A.TSkip{}, t)
            case ts:
              lvalue(f, ts, A.Stmt, l => r => ps(f, SAssign{l}, r))
        case SElse{c, th}:
          match ts:
            case Con{K.KKw{K.KwElse{}}, t}:
              then(A.Stmt, A.Stmt, ps(f, SOne{}, t), e => r => ok(A.Stmt, A.TIf{c, th, e}, r))
            case ts:
              ok(A.Stmt, A.TIf{c, th, A.TSkip{}}, ts)
        case SAssign{l}:
          match ts:
            case Con{K.KSym{K.PEq{}}, t}:
              expr(f, t, A.Stmt, v => r => expect(A.Stmt, K.PSemi{}, r, r2 => ok(A.Stmt, A.TSet{l, v}, r2)))
            case Con{K.KSym{K.PLe{}}, t}:
              expr(f, t, A.Stmt, v => r => expect(A.Stmt, K.PSemi{}, r, r2 => ok(A.Stmt, A.TSetNb{l, v}, r2)))
            case ts:
              Fail{"expected = or <= near " ++ near(ts)}
        case SList{}:
          match ts:
            case Con{K.KKw{K.KwEnd{}}, t}:
              ok(A.Stmt, A.TNil{}, Con{K.KKw{K.KwEnd{}}, t})
            case ts:
              then(A.Stmt, A.Stmt, ps(f, SOne{}, ts), h => r =>
                then(A.Stmt, A.Stmt, ps(f, SList{}, r), tl => r2 => ok(A.Stmt, A.TCon{h, tl}, r2)))

# Items
# -----

# #(e) or #e before an assignment, if there
def delay(+f: Nat, ts: List<&2, K.Tok>, -B: Data, k: Maybe<&2, A.Expr> -> List<&2, K.Tok> -> PR(B)) -> PR(B):
  match ts:
    case Con{K.KSym{K.PHash{}}, Con{K.KSym{K.PLParen{}}, t}}:
      expr(f, t, B, e => r => expect(B, K.PRParen{}, r, r2 => k(Some{e}, r2)))
    case Con{K.KSym{K.PHash{}}, t}:
      then(A.Expr, B, px(f, XAtom{}, t), e => r => k(Some{e}, r))
    case ts:
      k(None{}, ts)

# #(params) after a module name in an instance, if there
def iparams(+f: Nat, ts: List<&2, K.Tok>, -B: Data, k: List<&2, A.Conn> -> List<&2, K.Tok> -> PR(B)) -> PR(B):
  match ts:
    case Con{K.KSym{K.PHash{}}, t}:
      expect(B, K.PLParen{}, t, r =>
        then(List<&2, A.Conn>, B, conns(f, None{}, r), ps => r2 =>
          expect(B, K.PRParen{}, r2, r3 => k(ps, r3))))
    case ts:
      k(Nil{}, ts)

# : label after a begin, if there
def label(ts: List<&2, K.Tok>, -B: Data, k: Maybe<&2, String> -> List<&2, K.Tok> -> PR(B)) -> PR(B):
  match ts:
    case Con{K.KSym{K.PColon{}}, Con{K.KId{n}, t}}:
      k(Some{n}, t)
    case ts:
      k(None{}, ts)

# a for loop's header: (v = init; cond; v = step) begin [: label]
type ForHead is Data:
  ForHead{var: String, init: A.Expr, cond: A.Expr, step: A.Expr, label: Maybe<&2, String>}

def for_head(+f: Nat, ts: List<&2, K.Tok>) -> PR(ForHead):
  expect(ForHead, K.PLParen{}, ts, r =>
    ident(ForHead, r, v => r2 =>
      expect(ForHead, K.PEq{}, r2, r3 =>
        expr(f, r3, ForHead, init => r4 =>
          expect(ForHead, K.PSemi{}, r4, r5 =>
            expr(f, r5, ForHead, cond => r6 =>
              expect(ForHead, K.PSemi{}, r6, r7 =>
                ident(ForHead, r7, v2 => r8 =>
                  expect(ForHead, K.PEq{}, r8, r9 =>
                    expr(f, r9, ForHead, step => r10 =>
                      expect(ForHead, K.PRParen{}, r10, r11 =>
                        expect_kw(ForHead, K.KwBegin{}, r11, r12 =>
                          label(r12, ForHead, l => r13 => ok(ForHead, ForHead{v, init, cond, step, l}, r13))))))))))))))

def for_item(h: ForHead, body: A.Item) -> A.Item:
  match h:
    case ForHead{v, init, cond, step, l}:
      A.IFor{v, init, cond, step, l, body}

type IM is Data:
  IOne{}     # one item
  IList{}    # items up to (not past) end or endmodule

def pi(+fuel: Nat, mode: IM, +ts: List<&2, K.Tok>) -> PR(A.Item):
  match fuel:
    case 0n:
      Fail{"the parser ran out of fuel"}
    case 1n+f:
      match mode:
        case IOne{}:
          match ts:
            case Con{K.KKw{K.KwWire{}}, t}:
              signed(t, A.Item, s => r =>
                range(f, r, A.Item, rg => r2 =>
                  then(List<&2, A.Decl>, A.Item, decls(f, None{}, r2), ds => r3 =>
                    expect(A.Item, K.PSemi{}, r3, r4 => ok(A.Item, A.INet{A.NWire{}, s, rg, ds}, r4)))))
            case Con{K.KKw{K.KwReg{}}, t}:
              signed(t, A.Item, s => r =>
                range(f, r, A.Item, rg => r2 =>
                  then(List<&2, A.Decl>, A.Item, decls(f, None{}, r2), ds => r3 =>
                    expect(A.Item, K.PSemi{}, r3, r4 => ok(A.Item, A.INet{A.NReg{}, s, rg, ds}, r4)))))
            case Con{K.KKw{K.KwAssign{}}, t}:
              delay(f, t, A.Item, d => r =>
                lvalue(f, r, A.Item, l => r2 =>
                  expect(A.Item, K.PEq{}, r2, r3 =>
                    expr(f, r3, A.Item, v => r4 =>
                      expect(A.Item, K.PSemi{}, r4, r5 => ok(A.Item, A.IAssign{d, l, v}, r5))))))
            case Con{K.KKw{K.KwGenvar{}}, t}:
              then(List<&2, String>, A.Item, names(f, t), ns => r =>
                expect(A.Item, K.PSemi{}, r, r2 => ok(A.Item, A.IGenvar{ns}, r2)))
            case Con{K.KKw{K.KwParameter{}}, Con{K.KId{n}, Con{K.KSym{K.PEq{}}, t}}}:
              expr(f, t, A.Item, v => r => expect(A.Item, K.PSemi{}, r, r2 => ok(A.Item, A.IParam{False{}, n, v}, r2)))
            case Con{K.KKw{K.KwLocalparam{}}, Con{K.KId{n}, Con{K.KSym{K.PEq{}}, t}}}:
              expr(f, t, A.Item, v => r => expect(A.Item, K.PSemi{}, r, r2 => ok(A.Item, A.IParam{True{}, n, v}, r2)))
            case Con{K.KKw{K.KwFor{}}, t}:
              then(ForHead, A.Item, for_head(f, t), h => r =>
                then(A.Item, A.Item, pi(f, IList{}, r), body => r2 =>
                  expect_kw(A.Item, K.KwEnd{}, r2, r3 => ok(A.Item, for_item(h, body), r3))))
            case Con{K.KKw{K.KwAlways{}}, t}:
              expect(A.Item, K.PAt{}, t, r =>
                expect(A.Item, K.PLParen{}, r, r2 =>
                  then(List<&2, A.Sens>, A.Item, sens(f, None{}, r2), ss => r3 =>
                    expect(A.Item, K.PRParen{}, r3, r4 =>
                      then(A.Stmt, A.Item, ps(f, SOne{}, r4), b => r5 => ok(A.Item, A.IAlways{ss, b}, r5))))))
            case Con{K.KId{m}, t}:
              iparams(f, t, A.Item, pars => r =>
                ident(A.Item, r, n => r2 =>
                  expect(A.Item, K.PLParen{}, r2, r3 =>
                    then(List<&2, A.Conn>, A.Item, conns(f, None{}, r3), cs => r4 =>
                      expect(A.Item, K.PRParen{}, r4, r5 =>
                        expect(A.Item, K.PSemi{}, r5, r6 => ok(A.Item, A.IInst{m, pars, n, cs}, r6)))))))
            case ts:
              Fail{"expected a module item near " ++ near(ts)}
        case IList{}:
          match ts:
            case Con{K.KKw{K.KwEnd{}}, t}:
              ok(A.Item, A.INil{}, Con{K.KKw{K.KwEnd{}}, t})
            case Con{K.KKw{K.KwEndmodule{}}, t}:
              ok(A.Item, A.INil{}, Con{K.KKw{K.KwEndmodule{}}, t})
            case ts:
              then(A.Item, A.Item, pi(f, IOne{}, ts), h => r =>
                then(A.Item, A.Item, pi(f, IList{}, r), tl => r2 => ok(A.Item, A.ICon{h, tl}, r2)))

# Modules
# -------

# #(parameter ..) in a module header, if there
def hparams(+f: Nat, ts: List<&2, K.Tok>, -B: Data, k: List<&2, A.Param> -> List<&2, K.Tok> -> PR(B)) -> PR(B):
  match ts:
    case Con{K.KSym{K.PHash{}}, t}:
      expect(B, K.PLParen{}, t, r =>
        then(List<&2, A.Param>, B, params(f, None{}, r), ps => r2 =>
          expect(B, K.PRParen{}, r2, r3 => k(ps, r3))))
    case ts:
      k(Nil{}, ts)

def module(+f: Nat, ts: List<&2, K.Tok>) -> PR(A.Module):
  expect_kw(A.Module, K.KwModule{}, ts, r =>
    ident(A.Module, r, n => r2 =>
      hparams(f, r2, A.Module, ps => r3 =>
        expect(A.Module, K.PLParen{}, r3, r4 =>
          then(List<&2, A.Port>, A.Module, ports(f, None{}, r4), pts => r5 =>
            expect(A.Module, K.PRParen{}, r5, r6 =>
              expect(A.Module, K.PSemi{}, r6, r7 =>
                then(A.Item, A.Module, pi(f, IList{}, r7), b => r8 =>
                  expect_kw(A.Module, K.KwEndmodule{}, r8, r9 => ok(A.Module, A.Module{n, ps, pts, b}, r9))))))))))

def modules(+fuel: Nat, ts: List<&2, K.Tok>) -> PR(List<&2, A.Module>):
  match fuel:
    case 0n:
      Fail{"the parser ran out of fuel"}
    case 1n+f:
      match ts:
        case Nil{}:
          ok(List<&2, A.Module>, Nil{}, Nil{})
        case ts:
          then(A.Module, List<&2, A.Module>, module(f, ts), m => r =>
            then(List<&2, A.Module>, List<&2, A.Module>, modules(f, r), ms => r2 => ok(List<&2, A.Module>, m <> ms, r2)))

def count(ts: List<&2, K.Tok>, n: Nat) -> Nat:
  match ts:
    case Nil{}:
      n
    case Con{_, t}:
      count(t, 1n+n)

def design.go(r: PR(List<&2, A.Module>)) -> Result<&2, &2, String, A.Design>:
  match r:
    case Fail{e}:
      Fail{e}
    case Done{Got{ms, _}}:
      Done{A.Design{ms}}

# the design a token list holds, with the fuel f
def design.with(+f: Nat, ts: List<&2, K.Tok>) -> Result<&2, &2, String, A.Design>:
  design.go(modules(f, ts))

# the design a token list holds; no parse of n tokens recurses more than
# 64 times per token, so that much fuel always suffices
def design(+ts: List<&2, K.Tok>) -> Result<&2, &2, String, A.Design>:
  design.with(Nat.mul(64n, 1n+count(ts, 0n)), ts)
