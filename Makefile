# bend-fpga: provable hardware in Bend.
#
#   make check      check every law and proof (the gate)
#   make traces     run the LC4 spec against the PennSim traces
#   make roundtrip  parse and reprint every lab Verilog file: the same AST?
#   make sim        simulate the exported chips (and the reprinted lab) in
#                   iverilog against the lab testbench and its traces
#   make verilog    export every chip to build/<chip>.v
#   make all        all of the above

BEND   := bend
LAB    := vendor/cis371-lab3
TESTS  := test_alu test_br test_mem test_ld_br test_all house wireframe
LABV   := lc4_single lc4_alu lc4_cla lc4_decoder lc4_divider lc4_regfile
CHIPS  := lc4_single lc4_multi

.PHONY: all check traces roundtrip sim verilog clean
.SECONDARY:

all: check traces roundtrip verilog sim

check:
	$(BEND) PROOF.bend

build/lc4_trace: isa/lc4/*.bend hdl/*.bend
	@mkdir -p build
	$(BEND) isa/lc4/trace.bend -o $@

traces: build/lc4_trace
	@for t in $(TESTS); do printf '%-12s ' $$t; ./build/lc4_trace $(LAB)/test_data/$$t.hex $(LAB)/test_data/$$t.ctrace; done

build/vtool: tools/vtool.bend hdl/verilog/*.bend
	@mkdir -p build
	$(BEND) tools/vtool.bend -o $@

roundtrip: build/vtool
	@for f in $(LABV) include/register; do printf '%-20s ' $$f; ./build/vtool roundtrip $(LAB)/$$f.v; done

build/%_export: chips/%/*.bend hdl/*.bend hdl/verilog/*.bend
	@mkdir -p build
	$(BEND) chips/$*/export.bend -o $@

build/%.v: build/%_export
	./build/$*_export > $@

verilog: $(foreach c,$(CHIPS),build/$(c).v)

build/printed/%.v: $(LAB)/%.v build/vtool
	@mkdir -p build/printed
	./build/vtool print $< > $@

sim: verilog $(foreach f,$(LABV),build/printed/$(f).v)
	@for c in $(CHIPS); do for t in $(TESTS); do printf '%-12s %-12s ' $$c $$t; \
	  IVFLAGS=-g2005 tools/simlab.sh $$c $$t build/$$c.v | tail -1 | sed 's/ \[.*//'; done; done
	@for t in $(TESTS); do printf '%-12s %-12s ' lab3-printed $$t; \
	  IVFLAGS=-g2005 tools/simlab.sh printed $$t $(foreach f,$(LABV),build/printed/$(f).v) | tail -1 | sed 's/ \[.*//'; done

clean:
	rm -rf build
