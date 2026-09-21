module instruction_memory #(
    parameter integer MEM_DEPTH = 16,
    parameter integer DATA_WIDTH = 32,
    parameter integer ADDR_WIDTH = $clog2(MEM_DEPTH)
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [DATA_WIDTH-1:0] instruction_in,
    input  wire        write_enable,
    output wire [DATA_WIDTH-1:0] instruction_out,
    output wire        fifo_empty
);

    // FIFO storage
    reg [DATA_WIDTH-1:0] fifo_mem [0:MEM_DEPTH-1];
    reg [ADDR_WIDTH-1:0] write_ptr;
    reg [ADDR_WIDTH-1:0] read_ptr;
    reg [ADDR_WIDTH:0] fifo_count;

    // Write logic
    always @(posedge clk or negedge rst_n)
        begin
        if (!rst_n) begin
            write_ptr <= 0;
            fifo_count <= 0;
        end 
        else if (write_enable && fifo_count < MEM_DEPTH) 
        begin
            fifo_mem[write_ptr] <= instruction_in;
            write_ptr <= write_ptr + 1;
            fifo_count <= fifo_count + 1;
        end
    end

    // Read logic
    assign instruction_out = (fifo_count > 0) ? fifo_mem[read_ptr] : 32'b0;

    always @(posedge clk or negedge rst_n)
        begin
        if (!rst_n) begin
            read_ptr <= 0;
        end 
        else if (fifo_count > 0)
        begin
            read_ptr <= read_ptr + 1;
            fifo_count <= fifo_count - 1;
        end
    end

    // FIFO empty flag
    assign fifo_empty = (fifo_count == 0);

endmodule


    