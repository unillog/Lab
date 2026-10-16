#!/bin/bash
# Run the same RTL design under QuestaSim, as the reference model.
#
#   ./run_questa.sh <top> <file.sv> [more.sv ...]
#
# Questa is a Windows install driven from WSL; scripts/run_questa_wsl.py
# owns that bridge (staging sources onto a Windows-visible work dir,
# calling vlog/vsim, collecting the transcript). Use it rather than
# calling vlog.exe by hand -- it fail-closes when the tool is missing
# instead of quietly reporting success.
#
# Note on its report line: the script decides PASS/FAIL by looking for a
# "[PASS]" / "PASS" line from the testbench. A design that only prints
# values and never scores itself is reported FAIL -- that is the
# fail-closed direction, not a real divergence. Read the transcript.
set -u

if [ $# -lt 2 ]; then
    echo "usage: $0 <top-module> <source.sv> [more.sv ...]" >&2
    exit 2
fi

here="$(cd "$(dirname "$0")" && pwd)"
runner="$here/../src/scripts/run_questa_wsl.py"

if [ ! -f "$runner" ]; then
    echo "error: run_questa_wsl.py not found at $runner" >&2
    exit 3
fi

top="$1"; shift

# The runner takes source names relative to --design-dir; pass basenames
# and point --design-dir at wherever the first source lives.
design_dir="$(cd "$(dirname "$1")" && pwd)"
names=()
for f in "$@"; do
    names+=("$(basename "$f")")
done

python3 "$runner" all \
    --design-dir "$design_dir" \
    --sources "${names[@]}" \
    --top "$top"
rc=$?

echo
echo "transcript: /mnt/c/Users/Public/edgex_questa_work/transcript"
exit $rc
