`timescale 1ns/1ps

// Wrap test: the PC loops over SET and CLEAR without using a JUMP opcode.
module tb_square_wave_wrap;
    localparam integer CLOCK_PERIOD_NS = 100;
    localparam [31:0] SET_GPIO_0 = 32'h2000_0001;
    localparam [31:0] CLEAR_GPIO_0 = 32'h3000_0001;

    reg clk = 1'b0;
    reg rst_n = 1'b1;
    reg start = 1'b0;
    reg prog_enable = 1'b0;
    reg [31:0] wrap_pc = 32'd1;
    reg [31:0] instruction_in;
    reg write_enable = 1'b0;
    wire [31:0] pc_out;
    wire [31:0] instruction_out;
    wire fifo_empty;
    wire [7:0] gpio_in;
    wire [7:0] gpio;
    integer cycle;

    always #(CLOCK_PERIOD_NS / 2) clk = ~clk;

    top_v1 dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .prog_enable(prog_enable),
        .wrap_pc(wrap_pc),
        .instruction_in(instruction_in),
        .write_enable(write_enable),
        .pc_out(pc_out),
        .instruction_out(instruction_out),
        .fifo_empty(fifo_empty),
        .gpio_in(gpio_in),
        .gpio(gpio)
    );

    task write_instruction;
        input [31:0] value;
        begin
            @(negedge clk);
            instruction_in = value;
            write_enable = 1'b1;
            @(posedge clk);
            @(negedge clk);
            write_enable = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("/tmp/apio/tb_square_wave_wrap.vcd");
        $dumpvars(0, tb_square_wave_wrap);
        instruction_in = 32'b0;
        #15;
        rst_n = 1'b0;
        #35;
        rst_n = 1'b1;

        write_instruction(SET_GPIO_0);
        write_instruction(CLEAR_GPIO_0);

        // Program the inclusive terminal address; no jump instruction is used.
        @(negedge clk);
        prog_enable = 1'b1;
        @(posedge clk);
        @(negedge clk);
        prog_enable = 1'b0;
        start = 1'b1;

        for (cycle = 0; cycle < 8; cycle = cycle + 1) begin
            @(posedge clk);
            #1;
            if (pc_out !== ((cycle + 1) % 2)) begin
                $fatal(1, "wrap PC mismatch at cycle %0d: pc=%0d", cycle, pc_out);
            end
            if (gpio_in[0] !== ((cycle + 1) % 2)) begin
                $fatal(1, "wrap wave mismatch at cycle %0d: gpio=%b", cycle, gpio_in[0]);
            end
        end

        $display("PASS: wrap square wave is 5 MHz from a 10 MHz clock without JUMP");
        $finish;
    end
endmodule