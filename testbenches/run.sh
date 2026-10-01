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
    find "$programs_dir" -mindepth 2 -maxdepth 2 -type f \( -name '*.txt' -o -name '*.asm' \) -printf '  %h\n' | sed "s#^$programs_dir/##" | sort -u
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
is_uart_loopback=0
program_length=0
wrap_target=0
wrap_address=0

if [[ "$testbench" == "uart_lb" && -f "$program_dir/tb_uart_lb.v" ]]; then
    testbench_file="$program_dir/tb_uart_lb.v"
    is_uart_loopback=1
elif [[ -f "$program_testbench" && -f "$program_source" ]]; then
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
if [[ $is_program -eq 1 || $is_uart_loopback -eq 1 ]]; then
    if [[ -x "$repo_root/.venv/bin/python" ]]; then
        python_command="$repo_root/.venv/bin/python"
    elif command -v python3 >/dev/null 2>&1; then
        python_command="$(command -v python3)"
    else
        echo "Error: Python 3 is required to assemble programs." >&2
        exit 127
    fi
    if [[ $is_program -eq 1 ]]; then
        if ! "$python_command" "$programs_dir/assemble.py" "$program_source" --output "$program_hex" --metadata-output "$program_metadata"; then
            exit 1
        fi
        read -r program_length wrap_target wrap_address < "$program_metadata"
    fi
fi
if [[ $is_uart_loopback -eq 1 ]]; then
    for uart_direction in tx rx; do
        uart_source="$program_dir/uart_${uart_direction}.asm"
        if ! "$python_command" "$programs_dir/assemble.py" "$uart_source" \
            --output "$output_dir/uart_lb_${uart_direction}.hex" \
            --metadata-output "$output_dir/uart_lb_${uart_direction}.meta"; then
            exit 1
        fi
    done
    read -r tx_program_length tx_wrap_target tx_wrap_address < "$output_dir/uart_lb_tx.meta"
    read -r rx_program_length rx_wrap_target rx_wrap_address < "$output_dir/uart_lb_rx.meta"
fi
case "$testbench" in
    uart_lb)
        testbench="tb_uart_lb"
        sources=("$testbench_file" "$repo_root/top_v1.v" "$repo_root/src/"*.v)
        ;;
    square_wave)
        testbench="tb_square_wave_wrap"
        sources=("$testbench_file" "$repo_root/top_v1.v" "$repo_root/src/"*.v)
        ;;
    tb_square_wave_basic)
        sources=("$testbench_file" "$repo_root/src/decoder_v1.v" "$repo_root/src/gpio.v")
        ;;
    tb_osr_tx)
        sources=("$testbench_file" "$repo_root/top_v1.v" "$repo_root/src/"*.v)
        ;;
    tb_fractional_clock_divider)
        sources=("$testbench_file" "$repo_root/src/fractional_clock_divider.v")
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
    vvp "$simulator" "+PROGRAM_HEX=$program_hex" "+PROGRAM_LENGTH=$program_length" "+WRAP_TARGET=$wrap_target" "+WRAP_ADDRESS=$wrap_address" >>"$log_file" 2>&1
elif [[ $is_uart_loopback -eq 1 ]]; then
    baud_frequency_hz="${APIO_UART_BAUD_HZ:-10000000}"
    vvp "$simulator" \
        "+TX_HEX=$output_dir/uart_lb_tx.hex" "+TX_LENGTH=$tx_program_length" \
        "+TX_WRAP_TARGET=$tx_wrap_target" "+TX_WRAP_ADDRESS=$tx_wrap_address" \
        "+RX_HEX=$output_dir/uart_lb_rx.hex" "+RX_LENGTH=$rx_program_length" \
        "+RX_WRAP_TARGET=$rx_wrap_target" "+RX_WRAP_ADDRESS=$rx_wrap_address" \
        "+BAUD_FREQUENCY_HZ=$baud_frequency_hz" >>"$log_file" 2>&1
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