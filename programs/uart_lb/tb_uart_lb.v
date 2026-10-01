`timescale 1ns/1ps

module tb_uart_lb;
    localparam integer CLOCK_PERIOD_NS = 10;
    localparam integer PROGRAM_DEPTH = 64;
    localparam integer TX_WORD_COUNT = 7;
    localparam integer RX_EXPECTED_BYTES = 21;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg tx_start = 1'b0;
    reg rx_start = 1'b0;
    reg tx_prog_enable = 1'b0;
    reg rx_prog_enable = 1'b0;
    reg [31:0] tx_wrap_target = 0;
    reg [31:0] tx_wrap_address = 0;
    reg [31:0] rx_wrap_target = 0;
    reg [31:0] rx_wrap_address = 0;
    reg [31:0] tx_instruction_in = 0;
    reg [31:0] rx_instruction_in = 0;
    reg tx_instruction_write = 1'b0;
    reg rx_instruction_write = 1'b0;
    reg [31:0] tx_fifo_word = 0;
    reg tx_fifo_write = 1'b0;
    wire tx_fifo_full;
    wire tx_fifo_empty;
    wire [3:0] tx_fifo_count;
    reg [31:0] tx_program [0:PROGRAM_DEPTH-1];
    reg [31:0] rx_program [0:PROGRAM_DEPTH-1];
    reg [1023:0] tx_hex_path;
    reg [1023:0] rx_hex_path;
    integer tx_program_length;
    integer tx_wrap_target_arg;
    integer tx_wrap_address_arg;
    integer rx_program_length;
    integer rx_wrap_target_arg;
    integer rx_wrap_address_arg;
    integer index;
    integer word_index;
    integer char_index;
    integer received_count;
    reg [31:0] packed_word;
    reg [7:0] expected [0:RX_EXPECTED_BYTES-1];
    reg [31:0] tx_words [0:TX_WORD_COUNT-1];

    wire [31:0] tx_pc_out;
    wire [31:0] tx_instruction_out;
    wire tx_instruction_fifo_empty;
    wire [7:0] tx_gpio_in;
    tri [7:0] tx_gpio;
    wire tx_pin;

    wire [31:0] rx_pc_out;
    wire [31:0] rx_instruction_out;
    wire rx_instruction_fifo_empty;
    wire [7:0] rx_gpio_in;
    tri [7:0] rx_gpio;
    wire rx_pin;
    wire [5:0] rx_fifo_count;
    wire [31:0] rx_fifo_data_out;
    wire rx_fifo_empty;
    wire rx_fifo_full;
    reg rx_fifo_read = 1'b0;
    reg [31:0] baud_frequency_hz = 32'd10_000_000;
    wire baud_clk;
    wire baud_sync = uart_rx.decoder_io_start && uart_rx.decoder_input_shift;

    always #(CLOCK_PERIOD_NS / 2) clk = ~clk;

    assign tx_pin = tx_gpio[0];
    assign rx_gpio[1] = tx_gpio[0];
    assign rx_pin = rx_gpio[1];

    fractional_clock_divider #(
        .CLOCK_FREQUENCY_HZ(100_000_000)
    ) baud_clock_debug_i (
        .clk(clk),
        .rst_n(rst_n),
        .enable(rx_start),
        .sync(baud_sync),
        .output_frequency_hz(baud_frequency_hz),
        .divided_clk(baud_clk)
    );

    top_v1 #(
        .TX_FIFO_DEPTH(8),
        .RX_FIFO_DEPTH(32),
        .INSTRUCTION_MEM_DEPTH(PROGRAM_DEPTH)
    ) uart_tx (
        .clk(clk),
        .rst_n(rst_n),
        .start(tx_start),
        .prog_enable(tx_prog_enable),
        .wrap_target(tx_wrap_target),
        .wrap_address(tx_wrap_address),
        .instruction_in(tx_instruction_in),
        .write_enable(tx_instruction_write),
        .tx_fifo_data_in(tx_fifo_word),
        .tx_fifo_write(tx_fifo_write),
        .tx_fifo_full(tx_fifo_full),
        .tx_fifo_empty(tx_fifo_empty),
        .tx_fifo_count(tx_fifo_count),
        .osr_parallel_data_in(32'b0),
        .osr_parallel_load(1'b0),
        .osr_parallel_data_out(),
        .osr_valid_count(),
        .autopull_write(1'b0),
        .autopull_enable_in(1'b0),
        .autopull_enabled(),
        .autopush_write(1'b0),
        .autopush_enable_in(1'b0),
        .autopush_threshold_log2_in(3'b0),
        .autopush_enabled(),
        .autopush_threshold_log2(),
        .isr_clear(1'b0),
        .isr_parallel_data_out(),
        .isr_valid_count(),
        .rx_fifo_read(1'b0),
        .rx_fifo_data_out(),
        .rx_fifo_full(),
        .rx_fifo_empty(),
        .rx_fifo_count(),
        .pc_out(tx_pc_out),
        .instruction_out(tx_instruction_out),
        .fifo_empty(tx_instruction_fifo_empty),
        .gpio_in(tx_gpio_in),
        .gpio(tx_gpio)
    );

    top_v1 #(
        .TX_FIFO_DEPTH(4),
        .RX_FIFO_DEPTH(32),
        .INSTRUCTION_MEM_DEPTH(PROGRAM_DEPTH)
    ) uart_rx (
        .clk(clk),
        .rst_n(rst_n),
        .start(rx_start),
        .prog_enable(rx_prog_enable),
        .wrap_target(rx_wrap_target),
        .wrap_address(rx_wrap_address),
        .instruction_in(rx_instruction_in),
        .write_enable(rx_instruction_write),
        .tx_fifo_data_in(32'b0),
        .tx_fifo_write(1'b0),
        .tx_fifo_full(),
        .tx_fifo_empty(),
        .tx_fifo_count(),
        .osr_parallel_data_in(32'b0),
        .osr_parallel_load(1'b0),
        .osr_parallel_data_out(),
        .osr_valid_count(),
        .autopull_write(1'b0),
        .autopull_enable_in(1'b0),
        .autopull_enabled(),
        .autopush_write(1'b0),
        .autopush_enable_in(1'b0),
        .autopush_threshold_log2_in(3'b0),
        .autopush_enabled(),
        .autopush_threshold_log2(),
        .isr_clear(1'b0),
        .isr_parallel_data_out(),
        .isr_valid_count(),
        .rx_fifo_read(rx_fifo_read),
        .rx_fifo_data_out(rx_fifo_data_out),
        .rx_fifo_full(rx_fifo_full),
        .rx_fifo_empty(rx_fifo_empty),
        .rx_fifo_count(rx_fifo_count),
        .pc_out(rx_pc_out),
        .instruction_out(rx_instruction_out),
        .fifo_empty(rx_instruction_fifo_empty),
        .gpio_in(rx_gpio_in),
        .gpio(rx_gpio)
    );

    task write_tx_instruction;
        input [31:0] value;
        begin
            @(negedge clk);
            tx_instruction_in = value;
            tx_instruction_write = 1'b1;
            @(negedge clk);
            tx_instruction_write = 1'b0;
        end
    endtask

    task write_rx_instruction;
        input [31:0] value;
        begin
            @(negedge clk);
            rx_instruction_in = value;
            rx_instruction_write = 1'b1;
            @(negedge clk);
            rx_instruction_write = 1'b0;
        end
    endtask

    task program_tx_wrap;
        begin
            @(negedge clk);
            tx_wrap_target = tx_wrap_target_arg;
            tx_wrap_address = tx_wrap_address_arg;
            tx_prog_enable = 1'b1;
            @(negedge clk);
            tx_prog_enable = 1'b0;
        end
    endtask

    task program_rx_wrap;
        begin
            @(negedge clk);
            rx_wrap_target = rx_wrap_target_arg;
            rx_wrap_address = rx_wrap_address_arg;
            rx_prog_enable = 1'b1;
            @(negedge clk);
            rx_prog_enable = 1'b0;
        end
    endtask

    task write_tx_word;
        input [31:0] value;
        begin
            @(negedge clk);
            tx_fifo_word = value;
            tx_fifo_write = 1'b1;
            @(negedge clk);
            tx_fifo_write = 1'b0;
        end
    endtask

    task pop_rx_word;
        output [31:0] value;
        begin
            while (rx_fifo_empty)
                @(negedge clk);
            value = rx_fifo_data_out;
            rx_fifo_read = 1'b1;
            @(negedge clk);
            rx_fifo_read = 1'b0;
        end
    endtask

    reg [31:0] observed_word;

    initial begin
        $dumpfile("/tmp/apio/tb_uart_lb.vcd");
        $dumpvars(0, tb_uart_lb);
        expected[0] = 8'h68;
        expected[1] = 8'h65;
        expected[2] = 8'h6c;
        expected[3] = 8'h6c;
        expected[4] = 8'h6f;
        expected[5] = 8'h20;
        expected[6] = 8'h77;
        expected[7] = 8'h6f;
        expected[8] = 8'h72;
        expected[9] = 8'h6c;
        expected[10] = 8'h64;
        expected[11] = 8'h20;
        expected[12] = 8'h66;
        expected[13] = 8'h72;
        expected[14] = 8'h6f;
        expected[15] = 8'h6d;
        expected[16] = 8'h20;
        expected[17] = 8'h41;
        expected[18] = 8'h50;
        expected[19] = 8'h49;
        expected[20] = 8'h4f;

        if (!$value$plusargs("TX_HEX=%s", tx_hex_path))
            $fatal(1, "missing +TX_HEX=<path>");
        if (!$value$plusargs("TX_LENGTH=%d", tx_program_length))
            $fatal(1, "missing +TX_LENGTH=<count>");
        if (!$value$plusargs("TX_WRAP_TARGET=%d", tx_wrap_target_arg))
            $fatal(1, "missing +TX_WRAP_TARGET=<address>");
        if (!$value$plusargs("TX_WRAP_ADDRESS=%d", tx_wrap_address_arg))
            $fatal(1, "missing +TX_WRAP_ADDRESS=<address>");
        if (!$value$plusargs("RX_HEX=%s", rx_hex_path))
            $fatal(1, "missing +RX_HEX=<path>");
        if (!$value$plusargs("RX_LENGTH=%d", rx_program_length))
            $fatal(1, "missing +RX_LENGTH=<count>");
        if (!$value$plusargs("RX_WRAP_TARGET=%d", rx_wrap_target_arg))
            $fatal(1, "missing +RX_WRAP_TARGET=<address>");
        if (!$value$plusargs("RX_WRAP_ADDRESS=%d", rx_wrap_address_arg))
            $fatal(1, "missing +RX_WRAP_ADDRESS=<address>");
        if (!$value$plusargs("BAUD_FREQUENCY_HZ=%d", baud_frequency_hz))
            baud_frequency_hz = 32'd10_000_000;
        if (baud_frequency_hz == 0 || baud_frequency_hz > 50_000_000)
            $fatal(1, "baud frequency must be between 1 and 50000000 Hz");
        if (tx_program_length > PROGRAM_DEPTH || rx_program_length > PROGRAM_DEPTH)
            $fatal(1, "UART program exceeds instruction memory capacity");

        $readmemh(tx_hex_path, tx_program, 0, tx_program_length - 1);
        $readmemh(rx_hex_path, rx_program, 0, rx_program_length - 1);
        #25 rst_n = 1'b1;

        for (index = 0; index < tx_program_length; index = index + 1)
            write_tx_instruction(tx_program[index]);
        for (index = 0; index < rx_program_length; index = index + 1)
            write_rx_instruction(rx_program[index]);
        program_tx_wrap();
        program_rx_wrap();

        char_index = 0;
        for (word_index = 0; word_index < TX_WORD_COUNT; word_index = word_index + 1) begin
            packed_word = 32'b0;
            for (index = 0; index < 3; index = index + 1) begin
                if (char_index < RX_EXPECTED_BYTES)
                    packed_word[index * 10 +: 10] = {1'b1, expected[char_index], 1'b0};
                else
                    packed_word[index * 10 +: 10] = 10'h3ff;
                char_index = char_index + 1;
            end
            packed_word[31:30] = 2'b11;
            tx_words[word_index] = packed_word;
            write_tx_word(packed_word);
        end

        rx_start = 1'b1;
        repeat (3) @(negedge clk);
        tx_start = 1'b1;

        received_count = 0;
        while (received_count < RX_EXPECTED_BYTES) begin
            pop_rx_word(observed_word);
            if (observed_word[31:24] !== expected[received_count])
                $fatal(1, "UART byte %0d mismatch: received 0x%02x expected 0x%02x (word=%08x)",
                       received_count, observed_word[31:24], expected[received_count], observed_word);
            received_count = received_count + 1;
        end

        $display("PASS: UART loopback received \"hello world from APIO\" (%0d bytes)", received_count);
        $finish;
    end

    initial begin
        #2000000;
        $fatal(1, "UART loopback timed out");
    end
endmodule
