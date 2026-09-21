// Synchronous program counter with jump and programmable wrap support.
module program_counter #(
    parameter integer COUNTER_WIDTH = 32
) (
    input wire                         clk,
    input wire                         prog_enable,
    input wire                         rst_n,
    input wire                         start,
    output reg [COUNTER_WIDTH-1:0] pc_out,
    input  wire [COUNTER_WIDTH-1:0] wrap_pc,
    input wire                         jmp,
    input wire [COUNTER_WIDTH-1:0] jmp_addr
);
    // The counter returns to zero after reaching this terminal address.
    reg [COUNTER_WIDTH-1:0] wrap_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out <= 0;
            wrap_reg <= 0;
        end 
        // Programming must occur while stopped; it has priority over execution.
        else if (prog_enable)
         begin
            wrap_reg <= wrap_pc;
        end else if (start)
         begin
            // Jumps have priority over the normal increment/wrap sequence.
            if (jmp)
             begin
                pc_out <= jmp_addr;
            end 
            else if (pc_out == wrap_reg) begin
                pc_out <= 0;
            end else begin
                pc_out <= pc_out + 1'b1;
            end
        end
    end
endmodule
    