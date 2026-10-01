module isr #(
    parameter integer ISR_WIDTH = 32,
    parameter integer GPIO_WIDTH = 8,
    parameter integer COUNT_WIDTH = $clog2(ISR_WIDTH + 1),
    parameter integer AUTOPUSH_EXP_WIDTH = (COUNT_WIDTH <= 1) ? 1 : $clog2(COUNT_WIDTH),
    parameter integer GPIO_INDEX_WIDTH = (GPIO_WIDTH <= 1) ? 1 : $clog2(GPIO_WIDTH),
    parameter integer GPIO_COUNT_WIDTH = $clog2(GPIO_WIDTH + 1)
) (
    input  wire                              clk,
    input  wire                              rst_n,
    input  wire                              clear,
    input  wire                              shift_enable,
    input  wire                              lsb_first,
    input  wire                              push,
    input  wire                              autopush_enable,
    input  wire [AUTOPUSH_EXP_WIDTH-1:0]     autopush_threshold_log2,
    input  wire                              rx_fifo_full,
    input  wire [GPIO_WIDTH-1:0]             gpio_in,
    input  wire [GPIO_INDEX_WIDTH-1:0]       gpio_base,
    input  wire [GPIO_COUNT_WIDTH-1:0]       gpio_count,
    output reg  [ISR_WIDTH-1:0]              parallel_data_out,
    output reg  [COUNT_WIDTH-1:0]            valid_count,
    output wire [ISR_WIDTH-1:0]              rx_data_out,
    output wire                              rx_write_enable
);
    integer bit_index;
    reg [ISR_WIDTH-1:0] sampled_chunk;
    reg push_pending;
    wire [COUNT_WIDTH-1:0] sample_count = gpio_count;
    wire [COUNT_WIDTH-1:0] next_valid_count = valid_count + sample_count;
    wire [ISR_WIDTH-1:0] next_parallel_data = lsb_first ?
        ((parallel_data_out >> sample_count) |
         (sampled_chunk << (ISR_WIDTH - sample_count))) :
        ((parallel_data_out << sample_count) | sampled_chunk);
    wire [COUNT_WIDTH-1:0] autopush_bit_count =
        {{(COUNT_WIDTH-1){1'b0}}, 1'b1} << autopush_threshold_log2;
    wire shift_has_data = shift_enable && gpio_count != 0;
    wire [COUNT_WIDTH-1:0] push_valid_count = shift_has_data ? next_valid_count : valid_count;
    wire push_requested = push_pending || push ||
        (autopush_enable && push_valid_count >= autopush_bit_count);
    wire push_accepted = push_requested && !rx_fifo_full && push_valid_count != 0;

    assign rx_data_out = shift_has_data ? next_parallel_data : parallel_data_out;
    assign rx_write_enable = push_accepted;

    always @* begin
        sampled_chunk = {ISR_WIDTH{1'b0}};
        for (bit_index = 0; bit_index < ISR_WIDTH; bit_index = bit_index + 1) begin
            if (bit_index < gpio_count && (gpio_base + bit_index) < GPIO_WIDTH)
                sampled_chunk[bit_index] = gpio_in[gpio_base + bit_index];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            parallel_data_out <= {ISR_WIDTH{1'b0}};
            valid_count <= 0;
            push_pending <= 1'b0;
        end else if (clear) begin
            parallel_data_out <= {ISR_WIDTH{1'b0}};
            valid_count <= 0;
            push_pending <= 1'b0;
        end else if (push_accepted) begin
            parallel_data_out <= {ISR_WIDTH{1'b0}};
            valid_count <= 0;
            push_pending <= 1'b0;
        end else begin
            if (push || (autopush_enable && push_valid_count >= autopush_bit_count))
                push_pending <= 1'b1;
            if (shift_has_data) begin
            parallel_data_out <= next_parallel_data;
            if (next_valid_count > ISR_WIDTH)
                valid_count <= ISR_WIDTH;
            else
                valid_count <= next_valid_count;
            end
        end
    end
endmodule