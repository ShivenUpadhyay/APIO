`timescale 1ns/1ps

// Basic decoder/GPIO test: a 10 MHz clock drives a 5 MHz square wave.
module tb_square_wave_basic;
    localparam integer CLOCK_PERIOD_NS = 100;
    localparam [31:0] SET_GPIO_0 = 32'h2000_0001;
    localparam [31:0] CLEAR_GPIO_0 = 32'h3000_0001;

    reg clk = 1'b0;
    reg [31:0] instruction;
    wire jump;
    wire [31:0] jump_addr;
    wire [7:0] gpio_set;
    wire [7:0] gpio_clear;
    wire delay;
    reg [7:0] gpio_out = 8'b0;
    reg [7:0] gpio_oe = 8'b0;
    wire [7:0] gpio_in;
    wire [7:0] gpio;
    integer cycle;

    always #(CLOCK_PERIOD_NS / 2) clk = ~clk;

    decoder decoder_i (
        .instruction(instruction),
        .jump(jump),
        .jump_addr(jump_addr),
        .gpio_set(gpio_set),
        .gpio_clear(gpio_clear),
        .delay(delay)
    );

    aio_gpio gpio_i (
        .clk(clk),
        .gpio_out(gpio_out),
        .gpio_oe(gpio_oe),
        .gpio_in(gpio_in),
        .gpio(gpio)
    );

    // This is the minimal execution state needed for the basic waveform.
    always @(posedge clk) begin
        gpio_out <= (gpio_out | gpio_set) & ~gpio_clear;
        gpio_oe <= gpio_oe | gpio_set | gpio_clear;
    end

    initial begin
        $dumpfile("/tmp/apio/tb_square_wave_basic.vcd");
        $dumpvars(0, tb_square_wave_basic);
        instruction = SET_GPIO_0;
        for (cycle = 0; cycle < 8; cycle = cycle + 1) begin
            @(negedge clk);
            instruction = (cycle[0] == 1'b0) ? SET_GPIO_0 : CLEAR_GPIO_0;
            @(posedge clk);
            #1;
            if (gpio_in[0] !== ((cycle + 1) % 2)) begin
                $fatal(1, "basic wave mismatch at cycle %0d: gpio=%b", cycle, gpio_in[0]);
            end
        end
        $display("PASS: basic square wave is 5 MHz from a 10 MHz clock");
        $finish;
    end
endmodule