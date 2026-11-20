# AGENTS

bend-fpga designs hardware in Bend and proves it correct. `bend` is on the
PATH (packaged in `.jail.nix`, pinned to bendlang/bend 0e2f38f).

When using Bend:
- run `bend guide` to learn it (and `bend base <Name>` for Base)
- laws live in `LAWS.bend` files, proofs in the `PROOF.bend` beside them
- run `make check` (`bend PROOF.bend`) before committing: it must print
  ALL PROOFS CHECK
- never edit a `LAWS.bend` to make a proof go through; fix the code

Layout:

    LAWS.bend, PROOF.bend   every law, and the gate that proves them all
    isa/lc4/                the LC4 ISA: spec.bend, its laws, trace.bend
                            (the spec against PennSim traces)
    hdl/bits.bend           bit-vector operations on Base's Word(n)
    hdl/mem.bend            memories and register files (a trie)
    hdl/dsl.bend            the circuit DSL: dual-rail signals (value and
                            Verilog), the Build monad
    hdl/verilog/            Verilog AST, tokens, lexer, parser, printer
    chips/<chip>/           chip.bend (the design), LAWS.bend, PROOF.bend,
                            export.bend (prints its Verilog)
    tools/vtool.bend        Verilog files: print, roundtrip
    tools/simlab.sh         the CIS 371 lab testbench in iverilog
    tools/gen/              generators of mechanical proofs (bun)
    vendor/cis371-lab3/     the CIS 371 lab 3 code, traces and testbench

Bend pitfalls met here (all from `bend guide`, restated):
- a `match` scrutinizes a parameter or a pattern variable, never a computed
  value; pass the value to a helper. Params are matched in binder order,
  and a field can't be matched after a later sibling was.
- recursion must shrink the first argument that changes; no mutual
  recursion (use a mode argument; see hdl/verilog/parse.bend)
- `bend file.bend` runs IO on the JS backend, whose stack is small; build
  native binaries (`-o build/x`) for real inputs
- Nat.div / Nat.mod are machine division at runtime; don't recurse on a
  Nat's value
- the shell tool's timeout is in milliseconds

Proof generators: `bun tools/gen/lc4_proofs.ts` (isa/lc4/PROOF.bend) and
`bun tools/gen/lc4_chip_proof.ts <chip-dir> ...` (chip PROOF.bend files).
Regenerate, never hand-edit, a generated file.
