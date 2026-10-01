# APIO

## Current Hardware Architecture

The current design is a small programmed instruction engine:

```text
instruction_in -> inst_mem -> decoder_v1 -> delay_counter -> prog_counter
                                  |              ^                |
                                  |              |                +-- wrap/jump
                                  |              +------ start    |
                                  |                               +-- address
                                  +-- IN/OUT/PULL/PUSH/SET/WAIT

CPU TX write -> TX FIFO -> PULL -> OSR -> GPIO output mux -> GPIO pins
CPU RX read  <- RX FIFO <- PUSH <- ISR <- GPIO input pins
```

`inst_mem` is programmed sequentially while `write_enable` is high.
The program counter addresses the memory, and `decoder_v1` translates the
current instruction into GPIO, jump, and delay controls. `prog_counter`
advances only when the internal execution enable from `delay_counter` is
asserted.

The external `start` input enables execution. It does not directly force the
PC to increment: the delay counter can temporarily suppress the internal
execution enable while an instruction delay is active. `SET` programs
persistent GPIO direction bits, while `IN` and `OUT` perform their selected
number of per-cycle samples or shifts.

### Instruction Format

Every 32-bit instruction includes its delay value:

```text
31       28 27       24 23                         0
+-----------+-----------+----------------------------+
|   opcode  | delay[3:0]|          operand           |
+-----------+-----------+----------------------------+
```

The delay field is normally the number of additional clock cycles to hold
before the next instruction executes. `IN` and `OUT` instead use this field as
their total number of sample/shift cycles. For example:

```text
SET GPIO[0], delay 3   = 32'h2300_0001
CLEAR GPIO[0], delay 3 = 32'h3300_0001
```

Each instruction executes on one clock edge, followed by three suppressed
execution edges. Together, these two instructions generate a square wave with
eight clock cycles per full period, or `f_clk / 8`.

### Instruction Set

GPIO ranges are inclusive. In assembly, `GPIO[4:6]` means pins 4, 5, and 6.

- `JUMP` (`0001`): load the PC from the low 24-bit operand. The delay field is
  unused.
- `SET_GPIO` (`0010`, legacy): set output data for the pins selected by the
  low eight operand bits. The delay field retains the legacy per-instruction
  delay behavior.
- `CLEAR_GPIO` (`0011`, legacy): clear output data for the pins selected by
  the low eight operand bits. The delay field retains the legacy
  per-instruction delay behavior.
- `IN GPIO[first:last], cycles` (`0100`): sample the selected GPIO pins into
  the ISR on each of `cycles` consecutive clocks. Each sample is appended to
  the ISR; the delay field encodes the total cycle count.
- `OUT GPIO[first:last], cycles` (`0101`): drive the selected GPIO pins from
  the low OSR bits and shift the OSR by the number of selected pins on each of
  `cycles` consecutive clocks. The delay field encodes the total cycle count.
- `PULL` (`0110`): transfer one word from the TX FIFO into available OSR
  space. It does not add a delay.
- `PUSH` (`0111`): transfer the valid ISR data to the RX FIFO. It does not add
  a delay.
- `SET GPIO[first:last], OUT|IN` (`1000`): persistently set the GPIO output
  enable bits for the selected pins. `OUT` enables output; `IN` disables
  output. The delay field is unused.
- `WAIT cycles` (`1001`): load the delay counter for the requested number of
  wait cycles without changing GPIO or either shift register.
- `WAIT level PIN` (`1010`): hold the PC on this instruction until the
  selected pin equals `level` (`0` detects a UART start bit, `1` waits for idle).
- `NOP [cycles]`: no peripheral action; optionally load a delay. This is
  assembled as a `WAIT` with no pin condition.

For `IN` and `OUT`, the operand stores the base pin in bits `[23:20]` and
`count - 1` in bits `[19:16]`; the delay nibble is their cycle count. `SET`
uses the same base/count fields and bit 15 for direction (`1` = `OUT`, `0` =
`IN`). `PULL`, `PUSH`, and `WAIT` do not use GPIO range fields.

For UART-style bit timing, write `IN PINS, 1 [BIT_DELAY]` or
`OUT PINS, 1 [BIT_DELAY]`. The optional bracketed delay marks a paced
single-bit operation: it samples/shifts once, then holds the operation for the
configured delay. Without the bracketed delay, `IN`/`OUT` perform the specified
number of consecutive range samples/shifts. Assembly files may declare
constants with `.define NAME value` and select the meaning of `PIN`/`PINS` with
`.pin number`.

The OSR is a $2 \times OSR_WIDTH$ shift register (64 bits by default). CPU parallel
loads write only the trailing `OSR_WIDTH` bits; `PULL` appends a FIFO word
above the current valid bits. `OUT` shifts right by the selected pin count.
Autopull fetches a queued TX word when the OSR valid-bit count reaches zero.
The input shift register (ISR) width is independently parameterized
(`ISR_WIDTH`, 32 bits by default); it accumulates GPIO samples and tracks its
valid-bit count. Autopush compares that count against a CPU-programmed
power-of-two threshold, stored as a base-2 exponent, and writes the accumulated
word to the RX FIFO. This input-shift-register acronym is separate from
interrupt service routines, which are not implemented.

The CPU-facing interface is exposed as explicit `top_v1` ports: TX FIFO data,
write, full, empty, and count; RX FIFO data, read, full, empty, and count; OSR
parallel load/data/valid count; and autopull/autopush configuration. The RTL
does not yet define a memory-mapped CPU bus.

The UART loopback example runs the TX and RX programs on separate `top_v1`
instances and connects TX GPIO[0] to RX GPIO[1]:

```sh
./testbenches/run.sh uart_lb
```

It checks the received bytes for `hello world from APIO`.

## Interrupt Service Routines

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
./synthesize.sh decoder_v1 --hier
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
