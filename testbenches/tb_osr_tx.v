`timescale 1ns/1ps

module tb_osr_tx;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg start = 1'b0;
    reg prog_enable = 1'b0;
    reg [31:0] wrap_target = 32'b0;
    reg [31:0] wrap_address = 32'b0;
    reg [31:0] instruction_in = 32'b0;
    reg write_enable = 1'b0;
    reg [31:0] tx_fifo_data_in = 32'b0;
    reg tx_fifo_write = 1'b0;
    wire tx_fifo_full;
    wire tx_fifo_empty;
    wire [2:0] tx_fifo_count;
    reg [31:0] osr_parallel_data_in = 32'b0;
    reg osr_parallel_load = 1'b0;
    wire [63:0] osr_parallel_data_out;
    wire [6:0] osr_valid_count;
    reg autopull_write = 1'b0;
    reg autopull_enable_in = 1'b0;
    wire autopull_enabled;
    reg autopush_write = 1'b0;
    reg autopush_enable_in = 1'b0;
    reg [2:0] autopush_threshold_log2_in = 3'd4;
    wire autopush_enabled;
    wire [2:0] autopush_threshold_log2;
    reg isr_clear = 1'b0;
    wire [31:0] isr_parallel_data_out;
    wire [5:0] isr_valid_count;
    reg rx_fifo_read = 1'b0;
    wire [31:0] rx_fifo_data_out;
    wire rx_fifo_full;
    wire rx_fifo_empty;
    wire [2:0] rx_fifo_count;
    wire [31:0] pc_out;
    wire [31:0] instruction_out;
    wire instruction_fifo_empty;
    wire [7:0] gpio_in;
    tri [7:0] gpio;
    reg [7:0] external_gpio_data = 8'b0001_0101;
    reg [7:0] external_gpio_enable = 8'b0001_1111;
    genvar pin;

    always #5 clk = ~clk;
    generate
        for (pin = 0; pin < 8; pin = pin + 1) begin : external_gpio_pins
            assign gpio[pin] = external_gpio_enable[pin] ? external_gpio_data[pin] : 1'bz;
        end
    endgenerate

    top_v1 dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .prog_enable(prog_enable),
        .wrap_target(wrap_target),
        .wrap_address(wrap_address),
        .instruction_in(instruction_in),
        .write_enable(write_enable),
        .tx_fifo_data_in(tx_fifo_data_in),
        .tx_fifo_write(tx_fifo_write),
        .tx_fifo_full(tx_fifo_full),
        .tx_fifo_empty(tx_fifo_empty),
        .tx_fifo_count(tx_fifo_count),
        .osr_parallel_data_in(osr_parallel_data_in),
        .osr_parallel_load(osr_parallel_load),
        .osr_parallel_data_out(osr_parallel_data_out),
        .osr_valid_count(osr_valid_count),
        .autopull_write(autopull_write),
        .autopull_enable_in(autopull_enable_in),
        .autopull_enabled(autopull_enabled),
        .autopush_write(autopush_write),
        .autopush_enable_in(autopush_enable_in),
        .autopush_threshold_log2_in(autopush_threshold_log2_in),
        .autopush_enabled(autopush_enabled),
        .autopush_threshold_log2(autopush_threshold_log2),
        .isr_clear(isr_clear),
        .isr_parallel_data_out(isr_parallel_data_out),
        .isr_valid_count(isr_valid_count),
        .rx_fifo_read(rx_fifo_read),
        .rx_fifo_data_out(rx_fifo_data_out),
        .rx_fifo_full(rx_fifo_full),
        .rx_fifo_empty(rx_fifo_empty),
        .rx_fifo_count(rx_fifo_count),
        .pc_out(pc_out),
        .instruction_out(instruction_out),
        .fifo_empty(instruction_fifo_empty),
        .gpio_in(gpio_in),
        .gpio(gpio)
    );

    task reset_design;
        begin
            @(negedge clk);
            rst_n = 1'b0;
            start = 1'b0;
            prog_enable = 1'b0;
            write_enable = 1'b0;
            tx_fifo_write = 1'b0;
            osr_parallel_load = 1'b0;
            autopull_write = 1'b0;
            autopush_write = 1'b0;
            isr_clear = 1'b0;
            rx_fifo_read = 1'b0;
            repeat (2) @(negedge clk);
            rst_n = 1'b1;
        end
    endtask

    task write_instruction;
        input [31:0] value;
        begin
            @(negedge clk);
            instruction_in = value;
            write_enable = 1'b1;
            @(negedge clk);
            write_enable = 1'b0;
        end
    endtask

    task write_tx_word;
        input [31:0] value;
        begin
            @(negedge clk);
            tx_fifo_data_in = value;
            tx_fifo_write = 1'b1;
            @(negedge clk);
            tx_fifo_write = 1'b0;
        end
    endtask

    task set_autopull;
        begin
            @(negedge clk);
            autopull_enable_in = 1'b1;
            autopull_write = 1'b1;
            @(negedge clk);
            autopull_write = 1'b0;
        end
    endtask

    task set_autopush;
        begin
            @(negedge clk);
            autopush_enable_in = 1'b1;
            autopush_threshold_log2_in = 3'd4;
            autopush_write = 1'b1;
            @(negedge clk);
            autopush_write = 1'b0;
        end
    endtask

    task program_wrap;
        input [31:0] target;
        input [31:0] address;
        begin
            @(negedge clk);
            wrap_target = target;
            wrap_address = address;
            prog_enable = 1'b1;
            @(negedge clk);
            prog_enable = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("/tmp/apio/tb_osr_tx.vcd");
        $dumpvars(0, tb_osr_tx);
        reset_design();
        external_gpio_enable = 8'b0000_1111;

        @(negedge clk);
        osr_parallel_data_in = 32'h0000_0005;
        osr_parallel_load = 1'b1;
        @(negedge clk);
        osr_parallel_load = 1'b0;
        if (osr_parallel_data_out !== 64'h0000_0000_0000_0005 || osr_valid_count !== 7'd32)
            $fatal(1, "CPU load did not write only the trailing OSR word");

        write_tx_word(32'h0000_0003);
        write_tx_word(32'hdead_beef);
        write_instruction(32'h6000_0000);
        write_instruction(32'h8042_8000);
        write_instruction(32'h5542_0000);
        write_instruction(32'h5742_0000);
        program_wrap(32'd2, 32'd3);
        set_autopull();
        start = 1'b1;
        @(posedge clk);
        #1;
        if (osr_parallel_data_out !== 64'h0000_0003_0000_0005 || osr_valid_count !== 7'd64)
            $fatal(1, "PULL did not append the TX word into the leading OSR half");
        if (tx_fifo_empty || tx_fifo_count !== 1)
            $fatal(1, "PULL consumed more than one TX FIFO word");

        @(posedge clk);
        #1;
        if (pc_out !== 32'd2 || gpio[4] !== 1'b1 || gpio[5] !== 1'b0 || gpio[6] !== 1'b1)
            $fatal(1, "SET/OUT mismatch: pc=%0d gpio=%b oe=%b osr=%h", pc_out, gpio, dut.gpio_oe_state, osr_parallel_data_out);

        wait (osr_valid_count == 0);
        @(posedge clk);
        #1;
        if (osr_valid_count !== 7'd32 || osr_parallel_data_out[31:0] !== 32'hdead_beef)
            $fatal(1, "autopull did not fetch the next TX word after OSR exhaustion");
        if (!tx_fifo_empty || tx_fifo_count !== 0)
            $fatal(1, "autopull did not consume the queued TX word");
        start = 1'b0;

        reset_design();
        external_gpio_enable = 8'b0001_1111;
        write_instruction(32'h4504_0000);
        write_instruction(32'h8042_8000);
        write_instruction(32'h5542_0000);
        write_instruction(32'h7000_0000);
        write_instruction(32'h8042_0000);
        program_wrap(32'd0, 32'd15);
        set_autopush();
        if (!autopush_enabled || autopush_threshold_log2 !== 3'd4)
            $fatal(1, "autopush configuration register was not programmed");
        @(negedge clk);
        osr_parallel_data_in = 32'h0000_002d;
        osr_parallel_load = 1'b1;
        @(negedge clk);
        osr_parallel_load = 1'b0;
        start = 1'b1;

        wait (pc_out == 1);
        wait (!dut.io_active);
        @(negedge clk);
        external_gpio_enable[4] = 1'b0;
        wait (pc_out == 2);
        wait (dut.osr_instruction_shift);
        @(posedge clk);
        #1;
        if (dut.gpio_oe_state[6:4] !== 3'b111)
            $fatal(1, "SET OUT did not persistently enable GPIO[4:6]");
        if (gpio[4] !== 1'b1 || gpio[5] !== 1'b0 || gpio[6] !== 1'b1)
            $fatal(1, "OUT mismatch: pins=%b base=%0d count=%0d osr=%h oe=%b", gpio[6:4], dut.active_gpio_base, dut.active_gpio_count, osr_parallel_data_out, dut.gpio_oe_state);
        if (osr_valid_count !== 7'd29)
            $fatal(1, "OUT did not shift exactly three OSR bits on its first cycle");
        wait (!dut.io_active);
        if (osr_valid_count !== 7'd17)
            $fatal(1, "five-cycle OUT did not consume exactly fifteen OSR bits");

        wait (pc_out == 3);
        #1;
        if (rx_fifo_count !== 1 || rx_fifo_empty)
            $fatal(1, "autopush did not place the threshold batch in RX FIFO");
        if (rx_fifo_data_out !== 32'h000a_d6b5)
            $fatal(1, "autopush sample mismatch: got %h expected 000ad6b5", rx_fifo_data_out);
        if (isr_valid_count !== 6'd5 || isr_parallel_data_out[4:0] !== 5'b10101)
            $fatal(1, "IN mismatch: valid=%0d isr=%h rx_count=%0d rx_data=%h pc=%0d", isr_valid_count, isr_parallel_data_out, rx_fifo_count, rx_fifo_data_out, pc_out);

        wait (rx_fifo_count == 2);
        #1;
		if (rx_fifo_count !== 2)
			$fatal(1, "PUSH did not enqueue the remaining ISR bits");
		@(negedge clk);
		rx_fifo_read = 1'b1;
		@(negedge clk);
		rx_fifo_read = 1'b0;
		if (rx_fifo_data_out !== 32'h0000_0015 || rx_fifo_count !== 1)
			$fatal(1, "RX FIFO did not retain the explicit PUSH word");
        wait (pc_out == 5);
        #1;
        if (dut.gpio_oe_state[6:4] !== 3'b000)
            $fatal(1, "SET IN did not clear the persistent output-enable bits");

        @(negedge clk);
        rx_fifo_read = 1'b1;
        @(negedge clk);
        rx_fifo_read = 1'b0;
        if (!rx_fifo_empty || rx_fifo_count !== 0)
            $fatal(1, "RX FIFO did not become empty after reading both pushed words");

        $display("PASS: CPU FIFOs, 64-bit OSR, decoder-driven IN, autopush and PUSH");
        $finish;
    end
endmodule
