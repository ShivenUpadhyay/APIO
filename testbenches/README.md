# Testbench Tools

The testbenches use a 10 MHz clock (`100 ns` period). The runner uses:

- `iverilog` to compile Verilog testbenches
- `vvp` to run the compiled simulations
- `GTKWave` to view generated VCD waveforms

Run a testbench by name or by `.v` filename:

```sh
./testbenches/run.sh tb_square_wave_basic
./testbenches/run.sh tb_square_wave_wrap.v
./testbenches/run.sh tb_osr_tx
./testbenches/run.sh uart_lb
./testbenches/run.sh tb_osr_tx
```

The script compiles and runs the selected testbench, prints its log, and opens
the generated VCD in GTKWave. Logs and VCD files are written to `/tmp/apio/`.

The basic test runs the decoder/GPIO path:

```sh
./testbenches/run.sh tb_square_wave_basic
```

The wrap test runs through `top_v1`:

```sh
./testbenches/run.sh tb_square_wave_wrap
```

The wrap test programs `SET GPIO[0], delay 3` and `CLEAR GPIO[0], delay 3`
into instruction memory. It verifies an `f_clk / 8` square wave and confirms
that the PC wraps from the second instruction back to address zero.

Program examples live under `programs/`. Each example pairs a plain-English
`.txt` source file with a self-checking testbench. The shared assembler converts
instructions and wrap directives to hex and metadata before simulation:

```sh
./testbenches/run.sh square_wave
```

`.wrap` marks the inclusive address compared against the program counter.
When they match, the PC loads the address marked by `.wrap_target`. The
testbench loads both assembled values into the programmable PC before starting
execution.

`tb_osr_tx` checks the CPU-facing TX/RX FIFOs, trailing-half OSR parallel
load, PULL and autopull behavior, decoder-driven OUT, five-cycle IN sampling,
autopush threshold handling, explicit PUSH, and persistent GPIO direction:

```sh
./testbenches/run.sh tb_osr_tx
```

The `uart_lb` program runs separate TX and RX instruction streams on two
`top_v1` instances, connects TX GPIO[0] to RX GPIO[1], and checks the complete
`hello world from APIO` message in the RX FIFO:

```sh
./testbenches/run.sh uart_lb
```

`tb_osr_tx` checks the CPU-facing TX/RX FIFOs, trailing-half parallel OSR load,
FIFO PULL into the 64-bit OSR, GPIO input sampling, threshold-based autopush,
and explicit PUSH:

```sh
./testbenches/run.sh tb_osr_tx
```
