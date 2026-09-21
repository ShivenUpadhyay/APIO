/*
 * GPIO Module
 * Supports bidirectional GPIO functionality with output enable control.
 */
module aio_gpio #(
    parameter integer GPIO_WIDTH = 8
) (
    input  wire       clk,

    input  wire [GPIO_WIDTH-1:0] gpio_out,
    input  wire [GPIO_WIDTH-1:0] gpio_oe,
    output wire [GPIO_WIDTH-1:0] gpio_in,

    inout  wire [GPIO_WIDTH-1:0] gpio
);

genvar i;

generate
    for (i = 0; i < GPIO_WIDTH; i = i + 1) begin
        assign gpio[i] = gpio_oe[i] ? gpio_out[i] : 1'bz;
        assign gpio_in[i] = gpio[i];
    end
endgenerate

endmodule
