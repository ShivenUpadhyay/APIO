# APIO

## Current Hardware Architecture

The current design is a small programmed instruction engine:

```text
instruction_in -> inst_mem -> decoder_v1 -> control signals
                     ^                       |
                     |                       v
                     +------------------- prog_counter <- delay_counter
                                              ^
                                              |
                                             start
```

`inst_mem` is programmed sequentially while `write_enable` is high.
The program counter addresses the memory, and `decoder_v1` translates the
current instruction into GPIO, jump, and delay controls. `prog_counter`
advances only when the internal execution enable from `delay_counter` is
asserted.

The external `start` input enables execution. It does not directly force the
PC to increment: the delay counter can temporarily suppress the internal
execution enable while an instruction delay is active. GPIO state changes use
the same execution enable, so a delayed instruction performs its GPIO action
once and does not repeat while waiting.

### Instruction Format

Every 32-bit instruction includes its delay value:

```text
31       28 27       24 23                         0
+-----------+-----------+----------------------------+
|   opcode  | delay[3:0]|          operand           |
+-----------+-----------+----------------------------+
```

The delay field is the number of additional clock cycles to hold before the
next instruction executes. For example:

```text
SET GPIO[0], delay 3   = 32'h2300_0001
CLEAR GPIO[0], delay 3 = 32'h3300_0001
```

Each instruction executes on one clock edge, followed by three suppressed
execution edges. Together, these two instructions generate a square wave with
eight clock cycles per full period, or `f_clk / 8`.

Supported opcodes are `JUMP` (`0001`), `SET_GPIO` (`0010`), and `CLEAR_GPIO`
(`0011`). Jump operands use the low 24 bits; GPIO instructions use the low
eight bits.

## ISR

Interrupt service routines are not implemented in the current RTL. There is no
interrupt input, interrupt vector, return-from-interrupt instruction, or
register state for saving the interrupted PC.

A future ISR implementation would need an interrupt request input, an enabled
interrupt state, a vector address, and a saved return PC. The control sequence
would be:

1. Finish the current instruction and stop normal PC execution.
2. Save `pc_out` into an interrupt-return register.
3. Load the ISR vector into the PC.
4. Execute the handler and return with a dedicated `IRET` instruction.
5. Restore the saved PC and resume the delay-counter-controlled instruction stream.

The delay counter should be drained or explicitly cancelled on interrupt entry
so an interrupted instruction cannot be executed twice.

## Tools

The synthesis workflows use:

- `Yosys` for RTL synthesis, checks, and netlist generation
- `ABC` through Yosys for gate mapping
- `xdot` for the hierarchical block diagram
- `netlistsvg` for conventional gate-symbol diagrams
- `Inkscape` for PDF export of gate diagrams
- `xdg-open` to open generated GUI files

Install the optional gate-diagram renderer with:

```sh
npm install -g netlistsvg
```

## Synthesis

Use the synthesis script to run Yosys, generate the synthesized Verilog, and
optionally open a schematic view.

```sh
./synthesize.sh top_v1
./synthesize.sh top_v1 --hier
./synthesize.sh top_v1 --gates
```

Available modes:

| Command | Result |
| --- | --- |
| `./synthesize.sh top_v1` | Synthesis report and netlist generation |
| `./synthesize.sh top_v1 --hier` | Hierarchical module view |
| `./synthesize.sh top_v1 --gui` | Alias for `--hier` |
| `./synthesize.sh top_v1 --sch` | Alias for `--hier` |
| `./synthesize.sh top_v1 --gates` | Flattened gate-symbol PDF/SVG view |

Output is written to `/tmp/apio/`:

```text
/tmp/apio/top_v1_synthesis.log
/tmp/apio/top_v1_synthesized.v
```

To inspect a child module, pass its module name to the same script:

```sh
./synthesize.sh decoder --hier
```

This resolves the matching file in `src/` and opens the hierarchy viewer for
that module. The generated DOT and related files remain under `/tmp/apio/`.

For flattened gate diagrams, install the optional SVG renderer:

```sh
npm install -g netlistsvg
```

Then run:

```sh
./synthesize.sh top_v1 --gates
```
