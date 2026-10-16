#!/usr/bin/env bash
################################################################################
# Project name: EdgeX                                                          #
# File name   : gen_jit.sh                                                     #
# Description : Regenerate the JIT code dump for the gSerDesQuad design        #
# Time        : 2026-10-16                                                     #
# Version     : 0.3.0                                                          #
# Copyright (C) 2026 by Unillog                                                #
################################################################################
#
# Regenerates every artefact in this directory from source. Run it from
# anywhere; paths are resolved against the repository root.
#
#   ./gen_jit.sh            regenerate all three layers
#   ./gen_jit.sh ir         edgex-dialect MLIR only
#   ./gen_jit.sh llvm       LLVM-dialect MLIR only
#   ./gen_jit.sh obj        JIT object cache + disassembly only
#
set -u

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
binary="$root/Dev/src/build/bin/edgex"
quad="$root/Dev/src/test/regression/gSerDesQuad"
design="$quad/design"
copied="$design/copied"
top="gserdes_quad_tb"

sources=(
    "$copied/gserdes_pkg.sv"
    "$copied/rnm_pkg.sv"
    "$copied/rnm_math_pkg.sv"
    "$copied/rnm_noise_pkg.sv"
    "$copied/pcs_pkg.sv"
    "$copied/gray_encoder.sv"
    "$copied/gray_decoder.sv"
    "$copied/prbs15_generator.sv"
    "$copied/prbs15_checker.sv"
    "$copied/pcs_tx.sv"
    "$copied/pcs_rx.sv"
    "$copied/pcs_top.sv"
    "$design/gserdes_quad_pkg.sv"
    "$design/quad_clkgen.sv"
    "$design/cal_arbiter.sv"
    "$design/lane_coupling_proxy.sv"
    "$design/gserdes_quad_top.sv"
    "$quad/testbench/tests/$top.sv"
)

if [ ! -x "$binary" ]; then
    echo "error: $binary not found -- build EdgeX first" >&2
    exit 1
fi
for f in "${sources[@]}"; do
    [ -f "$f" ] || { echo "error: missing source $f" >&2; exit 1; }
done

what="${1:-all}"

# Provenance: the dump belongs to one exact tree state. Record it so a
# reader can tell whether this directory still matches the sources.
stamp() {
    {
        echo "generated : $(date -Is)"
        echo "commit    : $(cd "$root" && git rev-parse --short HEAD)"
        echo "dirty     : $(cd "$root" && git status --porcelain | wc -l) file(s) uncommitted"
        echo "diff md5  : $(cd "$root" && git diff HEAD | md5sum | cut -d' ' -f1)"
        echo "binary    : $(stat -c '%y' "$binary" | cut -d'.' -f1)"
        echo "top       : $top"
        echo "sources   : ${#sources[@]} files"
    } > "$here/PROVENANCE.txt"
}

if [ "$what" = all ] || [ "$what" = ir ]; then
    echo "[1/3] edgex-dialect MLIR ..."
    "$binary" run --emit-ir "${sources[@]}" -top "$top" \
        > "$here/gserdes_quad.edgex.mlir" 2> "$here/.gen_ir.log"
    echo "      $(wc -l < "$here/gserdes_quad.edgex.mlir") lines"
fi

if [ "$what" = all ] || [ "$what" = llvm ]; then
    echo "[2/3] LLVM-dialect MLIR ..."
    "$binary" run --emit-llvm "${sources[@]}" -top "$top" \
        > "$here/gserdes_quad.llvm.mlir" 2> "$here/.gen_llvm.log"
    echo "      $(wc -l < "$here/gserdes_quad.llvm.mlir") lines"
fi

if [ "$what" = all ] || [ "$what" = obj ]; then
    echo "[3/3] JIT object cache + disassembly ..."
    rm -rf "$here/jit-cache"
    mkdir -p "$here/jit-cache"
    "$binary" run --no-run-record -cache "$here/jit-cache" \
        "${sources[@]}" -top "$top" \
        > "$here/.gen_run.log" 2>&1
    objs="$(find "$here/jit-cache" -name '*.o' | sort)"
    if [ -n "$objs" ]; then
        # One .o per SystemVerilog process; disassemble every one of them
        # in a stable (sorted) order so the dump diffs cleanly run to run.
        {
            for o in $objs; do
                echo "##########################################################"
                echo "# object: $(basename "$o")"
                nm -t d "$o" 2>/dev/null | awk '$2=="T"{print "# symbol: "$3}'
                echo "##########################################################"
                objdump -d --no-show-raw-insn "$o" | tail -n +4
                echo
            done
        } > "$here/gserdes_quad.jit.asm"
        {
            printf "%-10s %-66s %s\n" "SIZE" "SYMBOL" "OBJECT"
            for o in $objs; do
                nm -S -t d "$o" 2>/dev/null \
                    | awk -v f="$(basename "$o")" \
                          '$3=="T"{printf "%-10s %-66s %s\n", $2, $4, f}'
            done
        } > "$here/gserdes_quad.jit.symbols"
        echo "      $(echo "$objs" | wc -l) objects," \
             "$(wc -l < "$here/gserdes_quad.jit.asm") lines of x86-64"
    else
        echo "      warning: no .o produced in jit-cache" >&2
    fi
fi

stamp
echo "done -- see PROVENANCE.txt"
