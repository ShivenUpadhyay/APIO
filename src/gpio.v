/*
 * GPIO Module
 * Supports bidirectional GPIO functionality with output enable control.
 */
module gpio #(
    parameter integer GPIO_WIDTH = 8
) (
    input  wire       clk,

    input  wire [GPIO_WIDTH-1:0] gpio_out, //output data
    input  wire [GPIO_WIDTH-1:0] gpio_oe, //output enable
    output wire [GPIO_WIDTH-1:0] gpio_in, //gpio data read from the pin

    inout  wire [GPIO_WIDTH-1:0] gpio  //physical pin
);

genvar i;

generate
    for (i = 0; i < GPIO_WIDTH; i = i + 1) begin
        assign gpio[i] = gpio_oe[i] ? gpio_out[i] : 1'bz;   //float if output enable is low
        assign gpio_in[i] = gpio[i];            //in always has some value, even if output is enabled
    end
endgenerate

endmodule
