# chips/lc4_multi/export.bend: prints the processor as Verilog.

import Base
import ../../hdl/verilog/ast.bend as A
import ../../hdl/verilog/print.bend as Pr
import ./chip.bend as C

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("// GENERATED from chips/lc4_multi/chip.bend; do not edit.\n`timescale 1ns / 1ps\n`default_nettype none\n")
    IO.print(Pr.render(Pr.design(A.Design{[C.module()]})))
