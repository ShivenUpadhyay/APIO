module osr #(
    parameter integer OSR_WIDTH = 32,
    parameter integer COUNT_WIDTH = $clog2((2 * OSR_WIDTH) + 1)
) (
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire [OSR_WIDTH-1:0]    parallel_data_in,
    input  wire                    parallel_load,
    input  wire                    shift_enable,
    input  wire [COUNT_WIDTH-1:0]  shift_count,
    input  wire                    pull,
    input  wire                    autopull_enable,
    input  wire [OSR_WIDTH-1:0]    tx_data,
    input  wire                    tx_empty,
    output wire                    tx_read_enable,
    output reg  [(2 * OSR_WIDTH)-1:0] parallel_data_out,
    output reg  [COUNT_WIDTH-1:0]  valid_count
);
    wire [COUNT_WIDTH-1:0] fifo_word_valid_bits = OSR_WIDTH;
    wire osr_has_room = valid_count <= OSR_WIDTH;
    wire pull_requested = (pull || (autopull_enable && valid_count == 0)) &&
                          !tx_empty && osr_has_room;
    wire pull_accepted = pull_requested && !parallel_load;
    wire [((2 * OSR_WIDTH) - 1):0] tx_word_extended =
        {{OSR_WIDTH{1'b0}}, tx_data};
    wire [((2 * OSR_WIDTH) - 1):0] shifted_tx_word = tx_word_extended << valid_count;

    assign tx_read_enable = pull_accepted;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            parallel_data_out <= {(2 * OSR_WIDTH){1'b0}};
            valid_count <= 0;
        end else begin
            if (pull_accepted) begin
                parallel_data_out <= parallel_data_out | shifted_tx_word;
                valid_count <= valid_count + fifo_word_valid_bits;
            end else if (parallel_load) begin
                parallel_data_out <= {{OSR_WIDTH{1'b0}}, parallel_data_in};
                valid_count <= OSR_WIDTH;
            end else if (shift_enable && shift_count != 0) begin
                if (valid_count <= shift_count) begin
                    parallel_data_out <= {(2 * OSR_WIDTH){1'b0}};
                    valid_count <= 0;
                end else begin
                    parallel_data_out <= parallel_data_out >> shift_count;
                    valid_count <= valid_count - shift_count;
                end
            end
        end
    end
endmodule