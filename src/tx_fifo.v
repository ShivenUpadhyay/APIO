module tx_fifo #(
    parameter integer DATA_WIDTH = 32,
    parameter integer FIFO_DEPTH = 4,
    parameter integer ADDR_WIDTH = (FIFO_DEPTH <= 1) ? 1 : $clog2(FIFO_DEPTH),
    parameter integer COUNT_WIDTH = $clog2(FIFO_DEPTH + 1)
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire                  write_enable,
    input  wire                  read_enable,
    output wire [DATA_WIDTH-1:0] data_out,
    output wire                  full,
    output wire                  empty,
    output reg  [COUNT_WIDTH-1:0] count
);
    reg [DATA_WIDTH-1:0] storage [0:FIFO_DEPTH-1];
    reg [ADDR_WIDTH-1:0] read_pointer;
    reg [ADDR_WIDTH-1:0] write_pointer;
    wire read_accepted = read_enable && !empty;
    wire write_accepted = write_enable && (!full || read_accepted);

    assign empty = count == 0;
    assign full = count == FIFO_DEPTH;
    assign data_out = empty ? {DATA_WIDTH{1'b0}} : storage[read_pointer];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_pointer <= 0;
            write_pointer <= 0;
            count <= 0;
        end else begin
            if (write_accepted) begin
                storage[write_pointer] <= data_in;
                if (write_pointer == FIFO_DEPTH - 1)
                    write_pointer <= 0;
                else
                    write_pointer <= write_pointer + 1'b1;
            end

            if (read_accepted) begin
                if (read_pointer == FIFO_DEPTH - 1)
                    read_pointer <= 0;
                else
                    read_pointer <= read_pointer + 1'b1;
            end

            case ({write_accepted, read_accepted})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end
endmodule