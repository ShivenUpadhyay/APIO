/*
 * GPIO Module
 * Supports bidirectional GPIO functionality with output enable control.
 */
module gpio #(
    parameter integer GPIO_WIDTH = 8
) (
    input  wire       clk,
    input  wire       rst_n,

    input  wire [GPIO_WIDTH-1:0] gpio_out, //output data
    input  wire [GPIO_WIDTH-1:0] gpio_oe, //legacy immediate output enable
    input  wire                  oe_program_write,
    input  wire [GPIO_WIDTH-1:0] oe_program_mask,
    input  wire [GPIO_WIDTH-1:0] oe_program_value,
    output wire [GPIO_WIDTH-1:0] oe_state,
    output wire [GPIO_WIDTH-1:0] gpio_in, //gpio data read from the pin

    inout  wire [GPIO_WIDTH-1:0] gpio  //physical pin
);

genvar i;
reg [GPIO_WIDTH-1:0] gpio_oe_reg;

assign oe_state = gpio_oe_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        gpio_oe_reg <= {GPIO_WIDTH{1'b0}};
    else if (oe_program_write)
        gpio_oe_reg <= (gpio_oe_reg & ~oe_program_mask) |
                       (oe_program_value & oe_program_mask);
end

generate
    for (i = 0; i < GPIO_WIDTH; i = i + 1) begin
        assign gpio[i] = (gpio_oe[i] | gpio_oe_reg[i]) ? gpio_out[i] : 1'bz;
        assign gpio_in[i] = gpio[i];            //in always has some value, even if output is enabled
    end
endgenerate

endmodule
