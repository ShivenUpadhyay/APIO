#!/usr/bin/env bash
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
testbench_dir="$repo_root/testbenches"
programs_dir="$repo_root/programs"
output_dir="/tmp/apio"

usage() {
    echo "Usage: $0 <testbench-name|testbench-file.v|program-name>"
    echo "Available testbenches:"
    find "$testbench_dir" -maxdepth 1 -type f -name 'tb_*.v' -printf '  %f\n' | sort
    echo "Available programs:"
    find "$programs_dir" -mindepth 2 -maxdepth 2 -type f -name '*.txt' -printf '  %h\n' | sed "s#^$programs_dir/##" | sort -u
}

if [[ $# -ne 1 ]]; then
    usage >&2
    exit 2
fi

testbench="$1"
testbench="${testbench##*/}"
testbench="${testbench%.v}"
program_dir="$programs_dir/$testbench"
program_testbench="$program_dir/tb_${testbench}_wrap.v"
program_source="$program_dir/${testbench}.txt"
program_hex="$output_dir/${testbench}.hex"
program_metadata="$output_dir/${testbench}.meta"
is_program=0
program_length=0
wrap_target=0
wrap_pc=0

if [[ -f "$program_testbench" && -f "$program_source" ]]; then
    testbench_file="$program_testbench"
    is_program=1
else
    testbench_file="$testbench_dir/$testbench.v"
fi

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
if [[ $is_program -eq 1 ]]; then
    if [[ -x "$repo_root/.venv/bin/python" ]]; then
        python_command="$repo_root/.venv/bin/python"
    elif command -v python3 >/dev/null 2>&1; then
        python_command="$(command -v python3)"
    else
        echo "Error: Python 3 is required to assemble programs." >&2
        exit 127
    fi
    if ! "$python_command" "$programs_dir/assemble.py" "$program_source" --output "$program_hex" --metadata-output "$program_metadata"; then
        exit 1
    fi
    read -r program_length wrap_target wrap_pc < "$program_metadata"
fi
case "$testbench" in
    square_wave)
        testbench="tb_square_wave_wrap"
        sources=("$testbench_file" "$repo_root/top_v1.v" "$repo_root/src/"*.v)
        ;;
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

    simulator="$output_dir/$testbench.vvp"
    log_file="$output_dir/$testbench.log"
    vcd_file="$output_dir/$testbench.vcd"

echo "Compiling $testbench..."
if ! iverilog -g2012 -Wall -s "$testbench" -o "$simulator" "${sources[@]}" >"$log_file" 2>&1; then
    cat "$log_file"
    exit 1
fi

echo "Running $testbench..."
if [[ $is_program -eq 1 ]]; then
    vvp "$simulator" "+PROGRAM_HEX=$program_hex" "+PROGRAM_LENGTH=$program_length" "+WRAP_TARGET=$wrap_target" "+WRAP_PC=$wrap_pc" >>"$log_file" 2>&1
else
    vvp "$simulator" >>"$log_file" 2>&1
fi
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