/*
 * GPIO Module
 * Supports bidirectional GPIO functionality with output enable control.
 */
module aio_gpio (
    input  wire       clk,

    input  wire [7:0] gpio_out,
    input  wire [7:0] gpio_oe,
    output wire [7:0] gpio_in,

    inout  wire [7:0] gpio
);

genvar i;

generate
    for (i = 0; i < 8; i = i + 1) begin
        assign gpio[i] = gpio_oe[i] ? gpio_out[i] : 1'bz;
        assign gpio_in[i] = gpio[i];
    end
endgenerate

endmodule
