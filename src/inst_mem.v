/*
Instruction memory module for storing instructions to be executed by the processor.
The module is parameterized to allow for different memory depths and data widths.
*/
module instruction_memory #(
    parameter integer MEM_DEPTH = 16,
    parameter integer DATA_WIDTH = 32,
    parameter integer ADDR_WIDTH = $clog2(MEM_DEPTH)
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [DATA_WIDTH-1:0] instruction_in,
    input  wire        write_enable,  /*required to write to the instruction memory; write_ptr is incremented on each write */
    input  wire [ADDR_WIDTH-1:0] read_addr,
    output wire [DATA_WIDTH-1:0] instruction_out,
    output wire        fifo_empty
);

    // Sequentially programmed instruction storage addressed by the PC.
    reg [DATA_WIDTH-1:0] instruction_mem [0:MEM_DEPTH-1];
    reg [ADDR_WIDTH-1:0] write_ptr;
    reg [ADDR_WIDTH:0] instruction_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 0;
            instruction_count <= 0;
        end else if (write_enable && write_ptr < MEM_DEPTH) begin
            instruction_mem[write_ptr] <= instruction_in;
            write_ptr <= write_ptr + 1;
            instruction_count <= instruction_count + 1;
        end
    end

    assign instruction_out = (read_addr < instruction_count) ? instruction_mem[read_addr] : 32'b0;
    assign fifo_empty = (instruction_count == 0);

endmodule


    