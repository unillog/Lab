#!/bin/bash
# Run an RTL design under EdgeX.
#
#   ./run_edgex.sh <top> <file.sv> [more.sv ...]        # simulate
#   WAVE=1 ./run_edgex.sh <top> <file.sv>               # + dump wave.vcd
#
# Exit codes follow EdgeX's own contract (Doc/EdgeX_UXUI.md UX-EXIT-01):
#   0 ok  2 usage  3 environment  4 source  5 codegen/run  6 divergence
set -u

if [ $# -lt 2 ]; then
    echo "usage: $0 <top-module> <source.sv> [more.sv ...]" >&2
    exit 2
fi

here="$(cd "$(dirname "$0")" && pwd)"
edgex="$here/../src/build/bin/edgex"

if [ ! -x "$edgex" ]; then
    echo "error: edgex not built at $edgex" >&2
    echo "       build it with: cmake --build $here/../src/build" >&2
    exit 3
fi

top="$1"; shift

wave_args=()
if [ "${WAVE:-0}" != "0" ]; then
    wave_args=(-vcd "$here/wave.vcd")
fi

# EDGEX_ALLOW_LEGACY silences the remark about the flat CLI form; the
# subcommand form is `edgex run`, which is what we use here.
EDGEX_ALLOW_LEGACY=1 "$edgex" run "$@" \
    -top "$top" \
    -timescale 1ns/1ps \
    --no-run-record \
    "${wave_args[@]+"${wave_args[@]}"}"
rc=$?

if [ "${WAVE:-0}" != "0" ] && [ $rc -eq 0 ]; then
    echo "wave: $here/wave.vcd"
fi
exit $rc
