# chips/lc4_single/export.bend: prints the processor as Verilog.
#
#   bend chips/lc4_single/export.bend -o build/lc4_single_export && build/lc4_single_export > out.v

import Base
import ../../hdl/verilog/ast.bend as A
import ../../hdl/verilog/print.bend as Pr
import ./chip.bend as C

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("// GENERATED from chips/lc4_single/chip.bend; do not edit.\n`timescale 1ns / 1ps\n`default_nettype none\n")
    IO.print(Pr.render(Pr.design(A.Design{[C.module()]})))
