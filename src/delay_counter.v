/*
Counts instruction delay cycles and gates instruction execution.
*/
module delay_counter #(
    parameter integer DELAY_WIDTH = 4
) (
    input wire                     clk,
    input wire                     rst_n,
    input wire                     start,
    input wire [DELAY_WIDTH-1:0]   delay_value,
    output wire                    execute_enable /* controls PC execution */
);
    reg [DELAY_WIDTH-1:0] delay_count;

    assign execute_enable = start && (delay_count == {DELAY_WIDTH{1'b0}});

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_count <= {DELAY_WIDTH{1'b0}};
        end else if (execute_enable && (delay_value != {DELAY_WIDTH{1'b0}})) begin
            delay_count <= delay_value;
        end else if (delay_count != {DELAY_WIDTH{1'b0}}) begin
            delay_count <= delay_count - 1'b1;
        end
    end
endmodule
