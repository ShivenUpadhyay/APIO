#!/usr/bin/env bash
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
output_dir="/tmp/apio"

usage() {
    echo "Usage: $0 <top-module-name|top-file.v> [--gui|--sch|--hier|--gates]"
    echo "Example: $0 top_v1"
    echo "Example: $0 top_v1 --gui"
    echo "Example: $0 top_v1 --gates"
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage >&2
    exit 2
fi

show_schematic=0
show_hierarchy=0
if [[ $# -eq 2 ]]; then
    case "$2" in
        --sch|--gui)
            show_hierarchy=1
            ;;
        --hier)
            show_hierarchy=1
            ;;
        --gates)
            show_schematic=1
            ;;
        *)
            echo "Error: unknown option: $2" >&2
            usage >&2
            exit 2
            ;;
    esac
fi

top_input="$1"
top_name="$(basename "${top_input%.v}")"
top_file=""

if [[ "$top_input" == */* || "$top_input" == *.v ]]; then
    top_file="$repo_root/${top_input#./}"
elif [[ -f "$repo_root/$top_name.v" ]]; then
    top_file="$repo_root/$top_name.v"
else
    while IFS= read -r candidate; do
        if grep -Eq "^[[:space:]]*module[[:space:]]+${top_name}([[:space:]]*#?\(|[[:space:]]*$)" "$candidate"; then
            top_file="$candidate"
            break
        fi
    done < <(find "$repo_root" -type f -name '*.v' | sort)
fi

if [[ -z "$top_file" || ! -f "$top_file" ]]; then
    echo "Error: top file or module not found: $top_input" >&2
    usage >&2
    exit 2
fi

if ! command -v yosys >/dev/null 2>&1; then
    echo "Error: yosys is required." >&2
    exit 127
fi

mkdir -p "$output_dir"
log_file="$output_dir/${top_name}_synthesis.log"
netlist_file="$output_dir/${top_name}_synthesized.v"
dot_file="$output_dir/${top_name}_netlist.dot"
hier_dot_file="$output_dir/${top_name}_hierarchy.dot"
json_file="$output_dir/${top_name}_netlist.json"
svg_file="$output_dir/${top_name}_netlist.svg"
pdf_file="$output_dir/${top_name}_netlist.pdf"
netlistsvg_cmd=()

echo "Synthesizing top module: $top_name"
read_sources=("$top_file")
for src_file in "$repo_root"/src/*.v; do
    if [[ -f "$src_file" && "$src_file" != "$top_file" ]]; then
        read_sources+=("$src_file")
    fi
done

read_sources_csv=""
for source in "${read_sources[@]}"; do
    if [[ -n "$read_sources_csv" ]]; then
        read_sources_csv+=" "
    fi
    read_sources_csv+="$source"
done

yosys_commands="read_verilog -sv $read_sources_csv; hierarchy -top $top_name; proc; check; stat; write_verilog -noattr $netlist_file"
if [[ $show_schematic -eq 1 ]]; then
    if ! command -v xdg-open >/dev/null 2>&1; then
        echo "Error: xdg-open is required for --gates." >&2
        exit 127
    fi
    if ! command -v inkscape >/dev/null 2>&1; then
        echo "Error: inkscape is required to create the PDF gate schematic." >&2
        exit 127
    fi
    if command -v netlistsvg >/dev/null 2>&1; then
        netlistsvg_cmd=(netlistsvg)
    elif [[ -x "$HOME/.local/node_modules/.bin/netlistsvg" ]]; then
        netlistsvg_cmd=("$HOME/.local/node_modules/.bin/netlistsvg")
    else
        echo "Error: netlistsvg is required for --gates." >&2
        echo "Install it with: npm install -g netlistsvg" >&2
        exit 127
    fi
    if ! command -v node >/dev/null 2>&1; then
        echo "Error: node is required for netlistsvg JSON preparation." >&2
        exit 127
    fi
    yosys_commands="read_verilog -sv $read_sources_csv; synth -top $top_name; abc -g simple; check; stat; write_verilog -noattr $netlist_file; write_json $json_file"
elif [[ $show_hierarchy -eq 1 ]]; then
    if ! command -v xdot >/dev/null 2>&1; then
        echo "Error: xdot is required for --hier." >&2
        exit 127
    fi
    yosys_commands="read_verilog -sv $read_sources_csv; hierarchy -top $top_name; proc; opt; check; stat; write_verilog -noattr $netlist_file; show -format dot -prefix $output_dir/${top_name}_hierarchy $top_name"
else
    yosys_commands="read_verilog -sv $read_sources_csv; hierarchy -top $top_name; proc; check; stat; write_verilog -noattr $netlist_file"
fi

if ! yosys -p "$yosys_commands" >"$log_file" 2>&1; then
    cat "$log_file"
    exit 1
fi

cat "$log_file"
echo "Synthesis log: $log_file"
echo "Synthesized Verilog: $netlist_file"

if [[ $show_schematic -eq 1 ]]; then
    # netlistsvg does not accept inout ports; mark external GPIO pins as inputs
    # in the visualization copy only. The synthesized RTL/netlist is unchanged.
    if ! node - "$json_file" <<'NODE'
const fs = require('fs');
const file = process.argv[2];
const netlist = JSON.parse(fs.readFileSync(file, 'utf8'));
for (const moduleData of Object.values(netlist.modules || {})) {
    for (const portData of Object.values(moduleData.ports || {})) {
        if (portData.direction === 'inout') {
            portData.direction = 'input';
        }
    }
    for (const cellData of Object.values(moduleData.cells || {})) {
        for (const directionKey of Object.keys(cellData.port_directions || {})) {
            if (cellData.port_directions[directionKey] === 'inout') {
                cellData.port_directions[directionKey] = 'input';
            }
        }
    }
}
fs.writeFileSync(file, JSON.stringify(netlist));
NODE
    then
        echo "Error: failed to prepare JSON for netlistsvg." >&2
        exit 1
    fi
    if ! "${netlistsvg_cmd[@]}" "$json_file" -o "$svg_file" >>"$log_file" 2>&1; then
        cat "$log_file"
        exit 1
    fi
    if ! inkscape "$svg_file" --export-type=pdf --export-filename="$pdf_file" >>"$log_file" 2>&1; then
        cat "$log_file"
        exit 1
    fi
    gui_log="$output_dir/${top_name}_gui.log"
    xdg-open "$pdf_file" >"$gui_log" 2>&1 &
    echo "Schematic PDF: $pdf_file"
    echo "Schematic SVG: $svg_file"
    echo "Yosys JSON: $json_file"
    echo "Schematic GUI started (PID $!)."
elif [[ $show_hierarchy -eq 1 ]]; then
    hierarchy_log="$output_dir/${top_name}_hierarchy_gui.log"
    xdot "$hier_dot_file" >"$hierarchy_log" 2>&1 &
    echo "Hierarchical schematic: $hier_dot_file"
    echo "Hierarchy viewer started (PID $!)."
fi