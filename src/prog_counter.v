// Synchronous program counter with jump and programmable wrap support.
module prog_counter #(
    parameter integer COUNTER_WIDTH = 32
) (
    input wire                         clk,
    input wire                         prog_enable,  //assert when programming the wrap address; counter is stopped
    input wire                         rst_n,
    input wire                         start,      //enables execution of counter, delay module will deassert to stop the counter
    output reg [COUNTER_WIDTH-1:0] pc_out,
    input  wire [COUNTER_WIDTH-1:0] wrap_pc,  /*address from which the counter wraps to 0x0; inclusive terminal address, 
                                              behaves like a jmp bus does not consume an extra instruction */
    input wire                         jmp,  /*indicates a jmp instruction is being executed; 
                                            has priority over the normal increment/wrap sequence */
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
    