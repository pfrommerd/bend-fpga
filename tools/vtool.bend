# tools/vtool.bend: the Verilog front end on files.
#
#   vtool print <file.v>       parse a file and print it back
#   vtool roundtrip <file.v>   parse, print, parse again: the same AST?
#
# Build: make build/vtool

import Base
import ../hdl/verilog/ast.bend as A
import ../hdl/verilog/tok.bend as K
import ../hdl/verilog/lex.bend as L
import ../hdl/verilog/parse.bend as P
import ../hdl/verilog/print.bend as Pr
import ../isa/lc4/trace.bend as T

def front.go(r: Result<&2, &2, String, List<&2, K.Tok>>) -> Result<&2, &2, String, A.Design>:
  match r:
    case Fail{e}:
      Fail{"lex error: " ++ e}
    case Done{ts}:
      P.design(ts)

def front(s: String) -> Result<&2, &2, String, A.Design>:
  front.go(L.lex(s))

# the source text of a design
def back(d: A.Design) -> String:
  Pr.render(Pr.design(d))

def print(r: Result<&2, &2, String, A.Design>) -> String:
  match r:
    case Fail{e}:
      "ERROR: " ++ e
    case Done{d}:
      back(d)

def verdict(same: Bool) -> String:
  match same:
    case True{}:
      "ROUNDTRIP OK"
    case False{}:
      "ROUNDTRIP FAILED: the printed text parses to a different design"

def again(+s1: String, r: Result<&2, &2, String, A.Design>) -> String:
  match r:
    case Fail{e}:
      "ROUNDTRIP FAILED: the printed text does not parse: " ++ e
    case Done{d2}:
      verdict(String.eq(s1, back(d2)))

def roundtrip(r: Result<&2, &2, String, A.Design>) -> String:
  match r:
    case Fail{e}:
      "ERROR: " ++ e
    case Done{d}:
      +s1 = back(d)
      again(s1, front(s1))

def run.go(is_print: Bool, src: String) -> String:
  match is_print:
    case True{}:
      print(front(src))
    case False{}:
      roundtrip(front(src))

def run(cmd: String, src: String) -> String:
  run.go(String.eq(cmd, "print"), src)

def main.go(args: List<String>) -> IO(Unit):
  match args:
    case Con{_, Con{cmd, Con{file, _}}}:
      do IO<Unit>:
        src : String <- T.read_all(file)
        IO.print(run(cmd, src))
    case _:
      IO.print("usage: vtool print|roundtrip <file.v>")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    main.go(args)
