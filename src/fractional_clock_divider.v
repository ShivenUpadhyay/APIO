module fractional_clock_divider #(
    parameter integer CLOCK_FREQUENCY_HZ = 100_000_000
) (
    input  wire clk,
    input  wire rst_n,
    input  wire enable,
    input  wire sync,
    input  wire [31:0] output_frequency_hz,
    output reg  divided_clk
);
    localparam [63:0] SOURCE_RATE = CLOCK_FREQUENCY_HZ;
    reg [63:0] phase_accumulator;
    wire [63:0] phase_step = {31'b0, output_frequency_hz, 1'b0};
    wire [64:0] phase_sum = {1'b0, phase_accumulator} + {1'b0, phase_step};

    initial begin
        if (CLOCK_FREQUENCY_HZ <= 0)
            $error("fractional_clock_divider requires a positive source clock rate");
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_accumulator <= 0;
            divided_clk <= 1'b0;
        end else if (sync) begin
            phase_accumulator <= 0;
            divided_clk <= 1'b1;
        end else if (!enable) begin
            phase_accumulator <= 0;
            divided_clk <= 1'b0;
        end else if (output_frequency_hz == 0 ||
                     (2 * {32'b0, output_frequency_hz}) > SOURCE_RATE) begin
            phase_accumulator <= 0;
            divided_clk <= 1'b0;
        end else if (phase_sum >= SOURCE_RATE) begin
            phase_accumulator <= phase_sum - SOURCE_RATE;
            divided_clk <= ~divided_clk;
        end else begin
            phase_accumulator <= phase_sum[63:0];
        end
    end
endmodule
