# Testbench Tools

The testbenches use a 10 MHz clock (`100 ns` period). The runner uses:

- `iverilog` to compile Verilog testbenches
- `vvp` to run the compiled simulations
- `GTKWave` to view generated VCD waveforms

Run a testbench by name or by `.v` filename:

```sh
./testbenches/run.sh tb_square_wave_basic
./testbenches/run.sh tb_square_wave_wrap.v
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

`.wrap_target` selects the first address in the loop, and `.wrap` marks its
inclusive final instruction. The testbench loads both values into the
programmable program counter before starting execution.
