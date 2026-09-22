`timescale 1ns / 1ps

module tb_ass_square_wave;
    localparam integer CLOCK_PERIOD_NS = 100;
    localparam [31:0] SET_GPIO_0 = 32'h2000_0001;
    localparam [31:0] DELAY = 32'h4000_0000;
    localparam [31:0] CLEAR_GPIO_0 = 32'h3000_0001;
    localparam [31:0] JUMP_LOOP = 32'h1000_0000;

    reg clk = 1'b0;
    reg rst_n = 1'b1;
    reg start = 1'b0;
    reg prog_enable = 1'b0;
    reg [31:0] instruction_in = 32'b0;
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
        .wrap_pc(32'd4),
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
        $dumpfile("/tmp/apio/tb_ass_square_wave.vcd");
        $dumpvars(0, tb_ass_square_wave);
        #15;
        rst_n = 1'b0;
        #35;
        rst_n = 1'b1;

        // SET GPIO[0]; DELAY; CLEAR GPIO[0]; DELAY; loop: JUMP loop.
        write_instruction(SET_GPIO_0);
        write_instruction(DELAY);
        write_instruction(CLEAR_GPIO_0);
        write_instruction(DELAY);
        write_instruction(JUMP_LOOP);

        @(negedge clk);
        prog_enable = 1'b1;
        @(posedge clk);
        @(negedge clk);
        prog_enable = 1'b0;
        start = 1'b1;

        for (cycle = 0; cycle < 7; cycle = cycle + 1) begin
            @(posedge clk);
            #1;
            case (cycle)
                0: if (pc_out !== 32'd1 || gpio_in[0] !== 1'b1)
                    $fatal(1, "SET mismatch: pc=%0d gpio=%b", pc_out, gpio_in[0]);
                1: if (pc_out !== 32'd1)
                    $fatal(1, "first DELAY did not hold PC: pc=%0d", pc_out);
                2: if (pc_out !== 32'd2)
                    $fatal(1, "first DELAY did not complete: pc=%0d", pc_out);
                3: if (pc_out !== 32'd3 || gpio_in[0] !== 1'b0)
                    $fatal(1, "CLEAR mismatch: pc=%0d gpio=%b", pc_out, gpio_in[0]);
                4: if (pc_out !== 32'd3)
                    $fatal(1, "second DELAY did not hold PC: pc=%0d", pc_out);
                5: if (pc_out !== 32'd4)
                    $fatal(1, "second DELAY did not complete: pc=%0d", pc_out);
                6: if (pc_out !== 32'd0)
                    $fatal(1, "JUMP mismatch: pc=%0d", pc_out);
                default: ;
            endcase
        end

        $display("PASS: assembly square-wave program executes with one-cycle delays");
        $finish;
    end
endmodule
    