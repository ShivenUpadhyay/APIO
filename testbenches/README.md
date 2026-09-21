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

Useful signals to inspect:

- Basic test: `clk`, `instruction`, `gpio_out`, and `gpio_in`.
- Wrap test: `clk`, `pc_out`, `instruction_out`, `gpio_in`, and `dut.gpio_out_reg`.
