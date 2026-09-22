#!/usr/bin/env bash
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
testbench_dir="$repo_root/testbenches"
output_dir="/tmp/apio"

usage() {
    echo "Usage: $0 <testbench-name|testbench-file.v>"
    echo "Available testbenches:"
    find "$testbench_dir" -maxdepth 1 -type f -name 'tb_*.v' -printf '  %f\n' | sort
}

if [[ $# -ne 1 ]]; then
    usage >&2
    exit 2
fi

testbench="$1"
testbench="${testbench##*/}"
testbench="${testbench%.v}"
testbench_file="$testbench_dir/$testbench.v"

if [[ ! -f "$testbench_file" ]]; then
    echo "Error: testbench not found: $testbench" >&2
    usage >&2
    exit 2
fi

if ! command -v iverilog >/dev/null 2>&1 || ! command -v vvp >/dev/null 2>&1; then
    echo "Error: iverilog and vvp are required." >&2
    exit 127
fi

mkdir -p "$output_dir"
simulator="$output_dir/$testbench.vvp"
log_file="$output_dir/$testbench.log"
vcd_file="$output_dir/$testbench.vcd"

case "$testbench" in
    tb_square_wave_basic)
        sources=("$testbench_file" "$repo_root/src/decoder_v1.v" "$repo_root/src/gpio.v")
        ;;
    tb_square_wave_wrap)
        sources=("$testbench_file" "$repo_root/top_v1.v" "$repo_root/src/"*.v)
        ;;
    tb_ass_square_wave)
        sources=("$testbench_file" "$repo_root/top_v1.v" "$repo_root/src/"*.v)
        ;;
    *)
        echo "Error: no source mapping is defined for $testbench" >&2
        exit 2
        ;;
esac

echo "Compiling $testbench..."
if ! iverilog -g2012 -Wall -s "$testbench" -o "$simulator" "${sources[@]}" >"$log_file" 2>&1; then
    cat "$log_file"
    exit 1
fi

echo "Running $testbench..."
vvp "$simulator" >>"$log_file" 2>&1
simulation_status=$?

cat "$log_file"
if [[ -f "$vcd_file" ]]; then
    echo "Waveform: $vcd_file"
fi

if [[ -f "$vcd_file" ]] && command -v gtkwave >/dev/null 2>&1; then
    gtkwave "$vcd_file" >/tmp/apio/"$testbench".gtkwave.log 2>&1 &
    echo "GTKWave started (PID $!)."
elif ! command -v gtkwave >/dev/null 2>&1; then
    echo "GTKWave is not installed; skipping waveform viewer." >&2
else
    echo "No waveform was generated; skipping GTKWave." >&2
fi

exit "$simulation_status"