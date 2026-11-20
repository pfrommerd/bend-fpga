# hdl/verilog/ast.bend: the syntax of a synthesizable Verilog subset.
#
# The AST keeps everything structural: names, declaration order, port and
# connection order, parameters, generate loops, and the exact operator
# tree of every expression (parentheses are not kept: the tree already says
# how an expression groups). It does not keep comments, whitespace, or the
# directives the lexer drops (`timescale, `default_nettype, `include, and
# `ifndef NDEBUG blocks, which grading builds without).
#
# Bend has no mutual recursion, so the lists inside an expression (a
# concatenation's parts, a call's arguments) are made of expressions too:
# VNil{} and VCon{h, t}. The same holds for items and statements.

import Base

# Operators
# ---------

type UOp is Data:
  UNot{}    # ~
  ULNot{}   # !
  UNeg{}    # -
  URAnd{}   # &  (reduction)
  UROr{}    # |  (reduction)
  URXor{}   # ^  (reduction)

type BOp is Data:
  BMul{}    # *
  BDiv{}    # /
  BMod{}    # %
  BAdd{}    # +
  BSub{}    # -
  BShl{}    # <<
  BShr{}    # >>
  BSshl{}   # <<<
  BSshr{}   # >>>
  BLt{}     # <
  BLe{}     # <=
  BGt{}     # >
  BGe{}     # >=
  BEq{}     # ==
  BNe{}     # !=
  BAnd{}    # &
  BXor{}    # ^
  BOr{}     # |
  BLAnd{}   # &&
  BLOr{}    # ||

# Expressions
# -----------

# the base a literal is written in: 4'b0001, 3'd7, 16'h8200, 8'o17
type Radix is Data:
  RBin{}
  ROct{}
  RDec{}
  RHex{}

type Expr is Data:
  VId{name: String}                         # x
  VNum{size: Maybe<&2, Nat>, radix: Radix, val: Nat}  # 16'h8200, or 7 (no size)
  VIdx{e: Expr, i: Expr}                    # e[i]
  VSli{e: Expr, hi: Expr, lo: Expr}         # e[hi:lo]
  VUn{op: UOp, e: Expr}                     # ~e
  VBin{op: BOp, a: Expr, b: Expr}           # a + b
  VCond{c: Expr, a: Expr, b: Expr}          # c ? a : b
  VCat{es: Expr}                            # {a, b, c}
  VRep{n: Expr, es: Expr}                   # {n{a, b}}
  VSys{name: String, args: Expr}            # $signed(e)
  VNil{}                                    # the end of a list of expressions
  VCon{h: Expr, t: Expr}                    # an expression, then the rest

# Declarations
# ------------

type Dir is Data:
  DIn{}
  DOut{}
  DInout{}

type Net is Data:
  NWire{}
  NReg{}
  NNone{}   # a port declared with no net keyword

# [hi:lo]
type Range is Data:
  Range{hi: Expr, lo: Expr}

# input wire [15:0] a, b
type Port is Data:
  Port{dir: Dir, net: Net, range: Maybe<&2, Range>, names: List<&2, String>}

# parameter n = 16 (in a module header)
type Param is Data:
  Param{name: String, value: Expr}

# x, or x = e, in a net declaration
type Decl is Data:
  Decl{name: String, init: Maybe<&2, Expr>}

# .port(e) or .port() when named, e when positional
type Conn is Data:
  Conn{port: Maybe<&2, String>, e: Maybe<&2, Expr>}

# posedge clk, negedge clk, or *
type Sens is Data:
  SPos{name: String}
  SNeg{name: String}
  SAll{}

# Statements (inside always blocks)
# ---------------------------------

type Stmt is Data:
  TBlock{body: Stmt}                        # begin .. end (a TNil/TCon list)
  TIf{c: Expr, t: Stmt, e: Stmt}            # if (c) t else e; e is TSkip{} if absent
  TSet{lhs: Expr, rhs: Expr}                # lhs = rhs;
  TSetNb{lhs: Expr, rhs: Expr}              # lhs <= rhs;
  TSkip{}                                   # no else branch
  TNil{}
  TCon{h: Stmt, t: Stmt}

# Module items
# ------------

type Item is Data:
  INet{net: Net, signed: Bool, range: Maybe<&2, Range>, decls: List<&2, Decl>}   # wire [15:0] a = e, b;
  IAssign{delay: Maybe<&2, Expr>, lhs: Expr, rhs: Expr}  # assign #(d) lhs = rhs;
  IGenvar{names: List<&2, String>}          # genvar i;
  IParam{local: Bool, name: String, value: Expr}  # (local)parameter x = e;
  IFor{var: String, init: Expr, cond: Expr, step: Expr, label: Maybe<&2, String>, body: Item}
                                            # for (i = init; cond; i = step) begin [: label] body end
  IInst{mod: String, params: List<&2, Conn>, name: String, conns: List<&2, Conn>}
                                            # mod #(params) name (conns);
  IAlways{sens: List<&2, Sens>, body: Stmt} # always @(sens) body
  INil{}
  ICon{h: Item, t: Item}

# Modules
# -------

type Module is Data:
  Module{name: String, params: List<&2, Param>, ports: List<&2, Port>, body: Item}

# a source file: its modules in order
type Design is Data:
  Design{mods: List<&2, Module>}
