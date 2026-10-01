`timescale 1ns/1ps

module tb_square_wave_wrap;
    localparam integer CLOCK_PERIOD_NS = 100;
    localparam integer MAX_PROGRAM_LENGTH = 16;

    reg clk = 1'b0;
    reg rst_n = 1'b1;
    reg start = 1'b0;
    reg prog_enable = 1'b0;
    reg [31:0] wrap_target = 32'b0;
    reg [31:0] wrap_pc = 32'b0;
    reg [31:0] instruction_in = 32'b0;
    reg write_enable = 1'b0;
    reg [31:0] program_words [0:MAX_PROGRAM_LENGTH-1];
    reg [1023:0] program_hex_path;
    integer program_length;
    integer index;
    integer cycle;
    integer wrap_target_arg;
    integer wrap_pc_arg;
    wire [31:0] pc_out;
    wire [31:0] instruction_out;
    wire fifo_empty;
    wire [7:0] gpio_in;
    wire [7:0] gpio;

    always #(CLOCK_PERIOD_NS / 2) clk = ~clk;

    top_v1 dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .prog_enable(prog_enable),
        .wrap_target(wrap_target),
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

        if (!$value$plusargs("PROGRAM_HEX=%s", program_hex_path))
            $fatal(1, "missing +PROGRAM_HEX=<path>");
        if (!$value$plusargs("PROGRAM_LENGTH=%d", program_length))
            $fatal(1, "missing +PROGRAM_LENGTH=<count>");
        if (!$value$plusargs("WRAP_TARGET=%d", wrap_target_arg))
            $fatal(1, "missing +WRAP_TARGET=<address>");
        if (!$value$plusargs("WRAP_PC=%d", wrap_pc_arg))
            $fatal(1, "missing +WRAP_PC=<address>");
        if (program_length < 1 || program_length > MAX_PROGRAM_LENGTH)
            $fatal(1, "program length must be between 1 and %0d", MAX_PROGRAM_LENGTH);
        if (wrap_target_arg < 0 || wrap_pc_arg < wrap_target_arg || wrap_pc_arg >= program_length)
            $fatal(1, "wrap range must be within the loaded program");

        $readmemh(program_hex_path, program_words, 0, program_length - 1);
        wrap_target = wrap_target_arg;
        wrap_pc = wrap_pc_arg;

        #15;
        rst_n = 1'b0;
        #35;
        rst_n = 1'b1;

        for (index = 0; index < program_length; index = index + 1)
            write_instruction(program_words[index]);

        @(negedge clk);
        prog_enable = 1'b1;
        @(posedge clk);
        @(negedge clk);
        prog_enable = 1'b0;
        start = 1'b1;

        for (cycle = 0; cycle < 16; cycle = cycle + 1) begin
            @(posedge clk);
            #1;
            if (pc_out !== ((cycle < 4 || (cycle >= 8 && cycle < 12)) ? 32'd1 : 32'd0))
                $fatal(1, "wrap PC mismatch at cycle %0d: pc=%0d", cycle, pc_out);
            if (gpio_in[0] !== ((cycle < 4 || (cycle >= 8 && cycle < 12)) ? 1'b1 : 1'b0))
                $fatal(1, "wrap waveform mismatch at cycle %0d: gpio=%b", cycle, gpio_in[0]);
        end

        $display("PASS: assembled square-wave program wraps and produces f_clk/8");
        $finish;
    end
endmodule