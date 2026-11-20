# hdl/verilog/tok.bend: Verilog tokens.
#
# Keywords and symbols are constructors, not strings, so the parser can
# match on them.

import Base
import ./ast.bend as A

type Kw is Data:
  KwModule{}
  KwEndmodule{}
  KwInput{}
  KwOutput{}
  KwInout{}
  KwWire{}
  KwReg{}
  KwSigned{}
  KwParameter{}
  KwLocalparam{}
  KwAssign{}
  KwGenvar{}
  KwFor{}
  KwBegin{}
  KwEnd{}
  KwAlways{}
  KwPosedge{}
  KwNegedge{}
  KwOr{}
  KwIf{}
  KwElse{}

type Sym is Data:
  PLParen{}    # (
  PRParen{}    # )
  PLBrack{}    # [
  PRBrack{}    # ]
  PLBrace{}    # {
  PRBrace{}    # }
  PComma{}     # ,
  PSemi{}      # ;
  PColon{}     # :
  PQuest{}     # ?
  PDot{}       # .
  PHash{}      # #
  PAt{}        # @
  PEq{}        # =
  PTilde{}     # ~
  PBang{}      # !
  PMinus{}     # -
  PPlus{}      # +
  PStar{}      # *
  PSlash{}     # /
  PPercent{}   # %
  PAmp{}       # &
  PPipe{}      # |
  PCaret{}     # ^
  PShl{}       # <<
  PShr{}       # >>
  PSshl{}      # <<<
  PSshr{}      # >>>
  PLt{}        # <
  PLe{}        # <=  (also the nonblocking assignment)
  PGt{}        # >
  PGe{}        # >=
  PEqEq{}      # ==
  PNe{}        # !=
  PAndAnd{}    # &&
  POrOr{}      # ||

type Tok is Data:
  KId{s: String}                                       # an identifier
  KKw{k: Kw}                                           # a keyword
  KSys{s: String}                                      # $signed, without the $
  KNum{size: Maybe<&2, Nat>, radix: A.Radix, val: Nat} # 16'h8200, 7
  KSym{s: Sym}                                         # operators and punctuation

# Spellings
# ---------

def Kw.text(k: Kw) -> String:
  match k:
    case KwModule{}:
      "module"
    case KwEndmodule{}:
      "endmodule"
    case KwInput{}:
      "input"
    case KwOutput{}:
      "output"
    case KwInout{}:
      "inout"
    case KwWire{}:
      "wire"
    case KwReg{}:
      "reg"
    case KwSigned{}:
      "signed"
    case KwParameter{}:
      "parameter"
    case KwLocalparam{}:
      "localparam"
    case KwAssign{}:
      "assign"
    case KwGenvar{}:
      "genvar"
    case KwFor{}:
      "for"
    case KwBegin{}:
      "begin"
    case KwEnd{}:
      "end"
    case KwAlways{}:
      "always"
    case KwPosedge{}:
      "posedge"
    case KwNegedge{}:
      "negedge"
    case KwOr{}:
      "or"
    case KwIf{}:
      "if"
    case KwElse{}:
      "else"

def Sym.text(s: Sym) -> String:
  match s:
    case PLParen{}:
      "("
    case PRParen{}:
      ")"
    case PLBrack{}:
      "["
    case PRBrack{}:
      "]"
    case PLBrace{}:
      "{"
    case PRBrace{}:
      "}"
    case PComma{}:
      ","
    case PSemi{}:
      ";"
    case PColon{}:
      ":"
    case PQuest{}:
      "?"
    case PDot{}:
      "."
    case PHash{}:
      "#"
    case PAt{}:
      "@"
    case PEq{}:
      "="
    case PTilde{}:
      "~"
    case PBang{}:
      "!"
    case PMinus{}:
      "-"
    case PPlus{}:
      "+"
    case PStar{}:
      "*"
    case PSlash{}:
      "/"
    case PPercent{}:
      "%"
    case PAmp{}:
      "&"
    case PPipe{}:
      "|"
    case PCaret{}:
      "^"
    case PShl{}:
      "<<"
    case PShr{}:
      ">>"
    case PSshl{}:
      "<<<"
    case PSshr{}:
      ">>>"
    case PLt{}:
      "<"
    case PLe{}:
      "<="
    case PGt{}:
      ">"
    case PGe{}:
      ">="
    case PEqEq{}:
      "=="
    case PNe{}:
      "!="
    case PAndAnd{}:
      "&&"
    case POrOr{}:
      "||"

def kws() -> List<&2, Kw>:
  [KwModule{}, KwEndmodule{}, KwInput{}, KwOutput{}, KwInout{}, KwWire{}, KwReg{}, KwSigned{}, KwParameter{}, KwLocalparam{}, KwAssign{}, KwGenvar{}, KwFor{}, KwBegin{}, KwEnd{}, KwAlways{}, KwPosedge{}, KwNegedge{}, KwOr{}, KwIf{}, KwElse{}]

def syms() -> List<&2, Sym>:
  [PLParen{}, PRParen{}, PLBrack{}, PRBrack{}, PLBrace{}, PRBrace{}, PComma{}, PSemi{}, PColon{}, PQuest{}, PDot{}, PHash{}, PAt{}, PEq{}, PTilde{}, PBang{}, PMinus{}, PPlus{}, PStar{}, PSlash{}, PPercent{}, PAmp{}, PPipe{}, PCaret{}, PShl{}, PShr{}, PSshl{}, PSshr{}, PLt{}, PLe{}, PGt{}, PGe{}, PEqEq{}, PNe{}, PAndAnd{}, POrOr{}]

def Kw.find.if(+k: Kw, rest: Maybe<&2, Kw>, hit: Bool) -> Maybe<&2, Kw>:
  match hit:
    case True{}:
      Some{k}
    case False{}:
      rest

def Kw.find(ks: List<&2, Kw>, +s: String) -> Maybe<&2, Kw>:
  match ks:
    case Nil{}:
      None{}
    case Con{+k, t}:
      Kw.find.if(k, Kw.find(t, s), String.eq(Kw.text(k), s))

# the keyword spelled s, if any
def Kw.of(+s: String) -> Maybe<&2, Kw>:
  Kw.find(kws(), s)

def Sym.find.if(+k: Sym, rest: Maybe<&2, Sym>, hit: Bool) -> Maybe<&2, Sym>:
  match hit:
    case True{}:
      Some{k}
    case False{}:
      rest

def Sym.find(ks: List<&2, Sym>, +s: String) -> Maybe<&2, Sym>:
  match ks:
    case Nil{}:
      None{}
    case Con{+k, t}:
      Sym.find.if(k, Sym.find(t, s), String.eq(Sym.text(k), s))

# the symbol spelled s, if any
def Sym.of(+s: String) -> Maybe<&2, Sym>:
  Sym.find(syms(), s)

# the token for an identifier or keyword spelled s
def word(+s: String, k: Maybe<&2, Kw>) -> Tok:
  match k:
    case None{}:
      KId{s}
    case Some{kw}:
      KKw{kw}
