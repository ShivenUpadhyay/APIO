# Wrapped Square Wave

Run the assembled program and its `top_v1` testbench from the repository root:

```sh
./testbenches/run.sh square_wave
```

The assembly begins with `JUMP 1`, so execution skips the setup address and
starts at `.wrap_target`. It sets GPIO[0], waits three additional cycles,
clears GPIO[0], waits three more cycles, then `.wrap` sends the PC back to the
programmed target. Each level lasts four clocks, producing a full period of
eight clocks (`f_clk / 8`).

## Waveform Signals

GTKWave opens `/tmp/apio/tb_square_wave_wrap.vcd`. Useful signals in the
`tb_square_wave_wrap` scope are:

- `clk`, `rst_n`, and `start`: clock, reset, and execution start.
- `pc_out`: after the initial jump, alternates between instruction addresses 1
  and 2; it jumps from the `.wrap` address back to the `.wrap_target` address.
- `instruction_out`: current instruction fetched from instruction memory.
- `gpio_in[0]` and `gpio[0]`: sampled and physical GPIO[0] level; the physical
  pin is initially high impedance until configured as an output.

Expand `dut.delay_counter_i.delay_count` to see the three suppressed clocks
between executions. `dut.program_counter_i.wrap_address_reg` and
`dut.program_counter_i.wrap_target_reg` show the programmed loop bounds.
