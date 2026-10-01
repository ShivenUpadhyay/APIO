# UART Loopback

Run the TX/RX assembly programs in the dual-top loopback testbench:

```sh
./testbenches/run.sh uart_lb
```

The bench assembles `uart_tx.asm` and `uart_rx.asm`, loads each instruction
stream into a separate `top_v1`, and connects transmitter GPIO[0] to receiver
GPIO[1]. Both use 8N1 framing, least-significant data bit first. The TX FIFO is
preloaded with packed words, each holding three 10-bit UART frames. The TX
program pulls a word into its OSR and emits one bit per paced `OUT`; the RX
program waits for a low start bit, samples eight bits, and pushes each byte to
its RX FIFO. The bench drains the RX FIFO and checks `hello world from APIO`.

The current simulation uses a 10 ns clock, `BIT_DELAY = 9` (ten clocks per
UART bit), and `START_TO_BIT0_DELAY = 14` (start detection to the middle of the
first data bit).

## Waveform Signals

GTKWave opens `/tmp/apio/tb_uart_lb.vcd`. Start in the `tb_uart_lb` scope:

- `tx_gpio[0]`: serial TX line. Check the low start bit, eight LSB-first data
  bits, and high stop bit.
- `rx_gpio[1]` and `rx_gpio_in[1]`: the connected RX line and the receiver's
  sampled input. They should follow `tx_gpio[0]`.
- `tx_pc_out` and `rx_pc_out`: current instruction addresses for the two
  programs. The RX PC remains on `WAIT 0 PIN` while idle and proceeds when a
  start bit arrives.
- `tx_instruction_out` and `rx_instruction_out`: the currently fetched
  assembly instruction words.
- `tx_fifo_count`, `tx_fifo_empty`, and `uart_tx.tx_fifo_i.data_out`: TX queue
  status and the packed word consumed by PULL.
- `uart_tx.osr_i.parallel_data_out[31:0]` and
  `uart_tx.osr_i.valid_count`: outgoing serial bits and remaining valid bits.
- `uart_rx.isr_i.parallel_data_out`, `uart_rx.isr_i.valid_count`,
  `rx_fifo_count`, and `rx_fifo_data_out`: captured bits, pushed-byte queue
  status, and the next received word. The received byte is in
  `rx_fifo_data_out[31:24]`.
- `rx_fifo_read`: asserted by the testbench as it removes each received byte.

The full hierarchical VCD is saved at `/tmp/apio/tb_uart_lb.vcd` for stepping
through individual start/data/stop bit intervals.
