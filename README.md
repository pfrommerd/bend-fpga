# bend-fpga

Hardware designed in [Bend](https://github.com/bendlang/bend), with laws
that state what a circuit must do and proofs that it does it. The first
target is LC4, the 16-bit ISA of UPenn's CIS 240/371/5710.

## What is proven

`make check` (`bend PROOF.bend`) checks every law:

| Law | File | Claim |
|---|---|---|
| `decode_encode` | isa/lc4/LAWS.bend | decoding an encoded instruction gives it back, fields included |
| `priv_unobservable` | isa/lc4/LAWS.bend | the privilege bit PSR[15] never changes what a step computes |
| `implements_lc4` | chips/lc4_single/LAWS.bend | one cycle of the single-cycle chip is one LC4 instruction, from every state |
| `implements_lc4` | chips/lc4_multi/LAWS.bend | two cycles (fetch, execute) of the multi-cycle chip are one LC4 instruction, from every fetch state |

The chip laws quantify over every PC, NZP value, register file and memory:
wherever the spec takes a step, the chip reaches the same machine.

## What is tested

- `make traces`: the LC4 spec reproduces PennSim's traces for the 7 lab
  programs (229,917 instructions), field by field.
- `make sim`: each chip's exported Verilog runs the lab's own testbench in
  iverilog against the same traces (0 errors on all 7), and so does the
  lab 3 processor after a parse/print round trip through Bend.
- `make roundtrip`: every lab Verilog file parses, prints, and parses back
  to the same AST.

## How it fits

- **The spec** (`isa/lc4/spec.bend`): decode, encode, execute, one step of
  the machine (PC, NZP, PSR[15], 8 registers, 64K words).
- **The DSL** (`hdl/dsl.bend`): a signal is dual-rail, its value (a Word,
  what proofs see) and the Verilog expression that computes it (what export
  prints). Circuits are Bend functions in a `Build` monad that declares
  named wires. A chip is proven on its values and exported from its
  expressions.
- **Verilog** (`hdl/verilog/`): an AST of a synthesizable subset (modules,
  ports, parameters, wires, assigns, instances, generate loops, always
  blocks), a lexer, a parser and a printer.

## Trusted, not proven

- That each DSL operator's value is what its Verilog expression computes
  (e.g. `slt` and `$signed(a) < $signed(b)`). Simulation checks every
  exported chip against PennSim's traces.
- That a chip reaches values only through DSL operators (export prints the
  branch it took otherwise).
- Nbit_reg and the lab memory model, outside the chips.
- The Verilog round trip is tested on every lab file but not yet proven.

## Layout

See AGENTS.md.

## Running

Run `git submodule update --init` to fetch the lab files used by the trace,
round-trip, and simulation targets. The lab repository requires GitHub access.

    make check       # the proofs
    make traces      # the spec vs PennSim
    make roundtrip   # the Verilog front end on the lab files
    make sim         # the chips (and the lab) in iverilog
    make all
