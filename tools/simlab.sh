#!/bin/sh
# Runs the CIS 371 lab 3 testbench (iverilog) on a set of processor sources.
#
#   tools/simlab.sh <name> <test> <src.v>...
#
# <test> names a trace in vendor/cis371-lab3/test_data (test_alu, house,
# ...). The sources are the processor's: lc4_processor and what it uses,
# without Nbit_reg and the memory, which come from the lab's include/.
set -e
here="$(cd "$(dirname "$0")/.." && pwd)"
lab="$here/vendor/cis371-lab3"
name="$1"; test="$2"; shift 2
dir="$here/build/sim/$name/$test"
rm -rf "$dir"; mkdir -p "$dir/include"
cp "$lab"/include/*.v "$dir/include/"
cp "$lab/testbench_lc4_processor.v" "$lab/print_points.v" "$dir/"
cat > "$dir/.set_testcase.v" <<EOF
\`define INPUT_FILE "$lab/test_data/$test.ctrace"
\`define MEMORY_IMAGE_FILE "$lab/test_data/$test.hex"
EOF
# iverilog reads "const" as a keyword (Vivado does not): the lab names an
# instance so, which is renamed in a copy (an instance name only)
mkdir -p "$dir/src"
srcs=""
for f in "$@"; do
  sed -E "s/ (const|logic) *[(]/ \\1_i(/" "$f" > "$dir/src/$(basename "$f")"
  srcs="$srcs src/$(basename "$f")"
done
cd "$dir"
iverilog $IVFLAGS -I include -DNDEBUG -o sim -s test_processor testbench_lc4_processor.v $srcs \
  include/register.v include/lc4_memory.v include/clock_util.v include/delay_eight_cycles.v include/bram.v
vvp -n sim | grep -E 'Simulation finished|Error at line' | head -5
