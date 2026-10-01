// Default-parameter integration of the instruction stream and GPIO peripherals.
module top_v1 #(
	parameter integer GPIO_WIDTH = 8,
	parameter integer TX_FIFO_WIDTH = 32,
	parameter integer TX_FIFO_DEPTH = 4,
	parameter integer OSR_WIDTH = 32,
	parameter integer ISR_WIDTH = 32,
	parameter integer RX_FIFO_DEPTH = 4,
	parameter integer INSTRUCTION_MEM_DEPTH = 16,
	parameter integer INSTRUCTION_ADDR_WIDTH = (INSTRUCTION_MEM_DEPTH <= 1) ? 1 : $clog2(INSTRUCTION_MEM_DEPTH),
	parameter integer OSR_COUNT_WIDTH = $clog2((2 * OSR_WIDTH) + 1),
	parameter integer ISR_COUNT_WIDTH = $clog2(ISR_WIDTH + 1),
	parameter integer AUTOPUSH_EXP_WIDTH = (ISR_COUNT_WIDTH <= 1) ? 1 : $clog2(ISR_COUNT_WIDTH),
	parameter integer GPIO_INDEX_WIDTH = (GPIO_WIDTH <= 1) ? 1 : $clog2(GPIO_WIDTH),
	parameter integer GPIO_COUNT_WIDTH = $clog2(GPIO_WIDTH + 1),
	parameter integer TX_FIFO_COUNT_WIDTH = $clog2(TX_FIFO_DEPTH + 1),
	parameter integer RX_FIFO_COUNT_WIDTH = $clog2(RX_FIFO_DEPTH + 1)
) (
	input  wire        clk,
	input  wire        rst_n,
	input  wire        start,
	input  wire        prog_enable,
	input  wire [31:0] wrap_target,
	input  wire [31:0] wrap_address,
	input  wire [31:0] instruction_in,
	input  wire        write_enable,
	input  wire [TX_FIFO_WIDTH-1:0] tx_fifo_data_in,
	input  wire        tx_fifo_write,
	output wire        tx_fifo_full,
	output wire        tx_fifo_empty,
	output wire [TX_FIFO_COUNT_WIDTH-1:0] tx_fifo_count,
	input  wire [OSR_WIDTH-1:0] osr_parallel_data_in,
	input  wire        osr_parallel_load,
	output wire [(2 * OSR_WIDTH)-1:0] osr_parallel_data_out,
	output wire [OSR_COUNT_WIDTH-1:0] osr_valid_count,
	input  wire        autopull_write,
	input  wire        autopull_enable_in,
	output wire        autopull_enabled,
	input  wire        autopush_write,
	input  wire        autopush_enable_in,
	input  wire [AUTOPUSH_EXP_WIDTH-1:0] autopush_threshold_log2_in,
	output wire        autopush_enabled,
	output wire [AUTOPUSH_EXP_WIDTH-1:0] autopush_threshold_log2,
	input  wire        isr_clear,
	output wire [ISR_WIDTH-1:0] isr_parallel_data_out,
	output wire [ISR_COUNT_WIDTH-1:0] isr_valid_count,
	input  wire        rx_fifo_read,
	output wire [ISR_WIDTH-1:0] rx_fifo_data_out,
	output wire        rx_fifo_full,
	output wire        rx_fifo_empty,
	output wire [RX_FIFO_COUNT_WIDTH-1:0] rx_fifo_count,
	output wire [31:0] pc_out,
	output wire [31:0] instruction_out,
	output wire        fifo_empty,
	output wire [GPIO_WIDTH-1:0] gpio_in,
	inout  wire [GPIO_WIDTH-1:0] gpio
);

	wire        jump;
	wire [31:0] jump_addr;
	wire [GPIO_WIDTH-1:0] gpio_set;
	wire [GPIO_WIDTH-1:0] gpio_clear;
	wire [3:0]  delay_count;
	wire decoder_input_shift;
	wire decoder_output_shift;
	wire decoder_pull;
	wire decoder_push;
	wire decoder_set_direction;
	wire decoder_gpio_output_enable;
	wire [3:0] decoder_gpio_base;
	wire [3:0] decoder_gpio_count;
	wire [3:0] decoder_io_cycles;
	wire decoder_io_paced;
	wire decoder_input_lsb_first;
	wire decoder_wait_pin;
	wire decoder_wait_pin_value;
	wire [3:0] decoder_wait_pin_index;
	wire        execute_enable;
	wire pc_execute_enable;
	wire wait_pin_satisfied;
	wire [INSTRUCTION_ADDR_WIDTH-1:0] instruction_addr;
	reg  [GPIO_WIDTH-1:0] gpio_out_reg;
	reg autopull_enable_reg;
	reg autopush_enable_reg;
	reg [AUTOPUSH_EXP_WIDTH-1:0] autopush_threshold_log2_reg;
	reg io_active;
	reg io_instruction_started;
	reg [31:0] io_instruction_pc;
	reg io_is_input;
	reg io_is_paced;
	reg io_input_lsb_first;
	reg io_repeat;
	reg [3:0] io_cycles_remaining;
	reg [GPIO_INDEX_WIDTH-1:0] io_gpio_base;
	reg [GPIO_COUNT_WIDTH-1:0] io_gpio_count;
	wire [TX_FIFO_WIDTH-1:0] tx_fifo_data_out;
	wire [OSR_WIDTH-1:0] osr_tx_data;
	wire tx_fifo_read;
	wire [GPIO_WIDTH-1:0] gpio_out_mux;
	reg [GPIO_WIDTH-1:0] osr_gpio_hold_mask;
	reg [GPIO_WIDTH-1:0] osr_gpio_hold_data;
	wire [GPIO_WIDTH-1:0] gpio_oe_program_mask;
	wire [GPIO_WIDTH-1:0] gpio_oe_program_value;
	wire [GPIO_WIDTH-1:0] gpio_oe_state;
	wire [GPIO_INDEX_WIDTH-1:0] active_gpio_base =
		(execute_enable && (decoder_input_shift || decoder_output_shift)) ? decoder_gpio_base[GPIO_INDEX_WIDTH-1:0] : io_gpio_base;
	wire [GPIO_COUNT_WIDTH-1:0] active_gpio_count =
		(execute_enable && (decoder_input_shift || decoder_output_shift)) ? decoder_gpio_count[GPIO_COUNT_WIDTH-1:0] : io_gpio_count;
	wire [OSR_COUNT_WIDTH-1:0] osr_shift_count = active_gpio_count;
	wire decoder_io_start = execute_enable && (decoder_input_shift || decoder_output_shift) &&
		!io_instruction_started;
	wire osr_instruction_shift = start &&
		((decoder_io_start && decoder_output_shift) || (io_active && !io_is_input && io_repeat));
	wire osr_gpio_live = (decoder_io_start && decoder_output_shift) ||
		(io_active && !io_is_input && io_repeat);
	wire isr_instruction_shift = start &&
		((decoder_io_start && decoder_input_shift) || (io_active && io_is_input && io_repeat));
	wire active_input_lsb_first = decoder_io_start ? decoder_input_lsb_first : io_input_lsb_first;
	wire pull_instruction = execute_enable && decoder_pull;
	wire push_instruction = execute_enable && decoder_push;
	wire rx_fifo_write;
	wire [ISR_WIDTH-1:0] isr_rx_data;
	assign osr_tx_data = tx_fifo_data_out;

	assign instruction_addr = pc_out[INSTRUCTION_ADDR_WIDTH-1:0];
	assign wait_pin_satisfied = gpio_in[decoder_wait_pin_index] == decoder_wait_pin_value;
	assign pc_execute_enable = execute_enable && (!decoder_wait_pin || wait_pin_satisfied);

	inst_mem #(.MEM_DEPTH(INSTRUCTION_MEM_DEPTH), .ADDR_WIDTH(INSTRUCTION_ADDR_WIDTH)) instruction_memory_i (
		.clk            (clk),
		.rst_n          (rst_n),
		.instruction_in(instruction_in),
		.write_enable   (write_enable),
		.read_addr      (instruction_addr),
		.instruction_out(instruction_out),
		.fifo_empty     (fifo_empty)
	);

	decoder_v1 #(.GPIO_WIDTH(GPIO_WIDTH)) decoder_i (
		.instruction(instruction_out),
		.jump       (jump),
		.jump_addr  (jump_addr),
		.gpio_set   (gpio_set),
		.gpio_clear (gpio_clear),
		.delay_count(delay_count),
		.input_shift(decoder_input_shift),
		.output_shift(decoder_output_shift),
		.pull(decoder_pull),
		.push(decoder_push),
		.set_gpio_direction(decoder_set_direction),
		.gpio_output_enable(decoder_gpio_output_enable),
		.gpio_base(decoder_gpio_base),
		.gpio_count(decoder_gpio_count),
		.io_cycles(decoder_io_cycles),
		.io_paced(decoder_io_paced),
		.input_lsb_first(decoder_input_lsb_first),
		.wait_pin(decoder_wait_pin),
		.wait_pin_value(decoder_wait_pin_value),
		.wait_pin_index(decoder_wait_pin_index)
	);

	tx_fifo #(
		.DATA_WIDTH(TX_FIFO_WIDTH),
		.FIFO_DEPTH(TX_FIFO_DEPTH),
		.COUNT_WIDTH(TX_FIFO_COUNT_WIDTH)
	) tx_fifo_i (
		.clk(clk),
		.rst_n(rst_n),
		.data_in(tx_fifo_data_in),
		.write_enable(tx_fifo_write),
		.read_enable(tx_fifo_read),
		.data_out(tx_fifo_data_out),
		.full(tx_fifo_full),
		.empty(tx_fifo_empty),
		.count(tx_fifo_count)
	);

	osr #(
		.OSR_WIDTH(OSR_WIDTH),
		.COUNT_WIDTH(OSR_COUNT_WIDTH)
	) osr_i (
		.clk(clk),
		.rst_n(rst_n),
		.parallel_data_in(osr_parallel_data_in),
		.parallel_load(osr_parallel_load),
		.shift_enable(osr_instruction_shift),
		.shift_count(osr_shift_count),
		.pull(pull_instruction),
		.autopull_enable(autopull_enable_reg),
		.tx_data(osr_tx_data),
		.tx_empty(tx_fifo_empty),
		.tx_read_enable(tx_fifo_read),
		.parallel_data_out(osr_parallel_data_out),
		.valid_count(osr_valid_count)
	);

	isr #(
		.ISR_WIDTH(ISR_WIDTH),
		.GPIO_WIDTH(GPIO_WIDTH),
		.COUNT_WIDTH(ISR_COUNT_WIDTH),
		.AUTOPUSH_EXP_WIDTH(AUTOPUSH_EXP_WIDTH),
		.GPIO_INDEX_WIDTH(GPIO_INDEX_WIDTH),
		.GPIO_COUNT_WIDTH(GPIO_COUNT_WIDTH)
	) isr_i (
		.clk(clk),
		.rst_n(rst_n),
		.clear(isr_clear),
		.shift_enable(isr_instruction_shift),
		.lsb_first(active_input_lsb_first),
		.push(push_instruction),
		.autopush_enable(autopush_enable_reg),
		.autopush_threshold_log2(autopush_threshold_log2_reg),
		.rx_fifo_full(rx_fifo_full),
		.gpio_in(gpio_in),
		.gpio_base(active_gpio_base),
		.gpio_count(active_gpio_count),
		.parallel_data_out(isr_parallel_data_out),
		.valid_count(isr_valid_count),
		.rx_data_out(isr_rx_data),
		.rx_write_enable(rx_fifo_write)
	);

	assign autopull_enabled = autopull_enable_reg;
	assign autopush_enabled = autopush_enable_reg;
	assign autopush_threshold_log2 = autopush_threshold_log2_reg;

	tx_fifo #(
		.DATA_WIDTH(ISR_WIDTH),
		.FIFO_DEPTH(RX_FIFO_DEPTH),
		.COUNT_WIDTH(RX_FIFO_COUNT_WIDTH)
	) rx_fifo_i (
		.clk(clk),
		.rst_n(rst_n),
		.data_in(isr_rx_data),
		.write_enable(rx_fifo_write),
		.read_enable(rx_fifo_read),
		.data_out(rx_fifo_data_out),
		.full(rx_fifo_full),
		.empty(rx_fifo_empty),
		.count(rx_fifo_count)
	);

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			autopull_enable_reg <= 1'b0;
			autopush_enable_reg <= 1'b0;
			autopush_threshold_log2_reg <= 1;
		end else begin
			if (autopull_write)
				autopull_enable_reg <= autopull_enable_in;
			if (autopush_write) begin
				autopush_enable_reg <= autopush_enable_in;
				if (autopush_threshold_log2_in < ISR_COUNT_WIDTH)
					autopush_threshold_log2_reg <= autopush_threshold_log2_in;
				else
					autopush_threshold_log2_reg <= ISR_COUNT_WIDTH - 1;
			end
		end
	end

	integer pin_index;
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			io_active <= 1'b0;
			io_instruction_started <= 1'b0;
			io_instruction_pc <= 0;
			io_is_input <= 1'b0;
			io_is_paced <= 1'b0;
			io_input_lsb_first <= 1'b0;
			io_repeat <= 1'b0;
			io_cycles_remaining <= 0;
			io_gpio_base <= 0;
			io_gpio_count <= 0;
			osr_gpio_hold_mask <= {GPIO_WIDTH{1'b0}};
			osr_gpio_hold_data <= {GPIO_WIDTH{1'b0}};
		end else begin
			if (io_instruction_started && pc_out != io_instruction_pc)
				io_instruction_started <= 1'b0;

			if (decoder_io_start) begin
				io_instruction_started <= 1'b1;
				io_instruction_pc <= pc_out;
				io_gpio_base <= decoder_gpio_base;
				io_gpio_count <= decoder_gpio_count;
				io_is_input <= decoder_input_shift;
				io_is_paced <= decoder_io_paced;
				io_input_lsb_first <= decoder_input_lsb_first;
				io_repeat <= !decoder_io_paced;
				io_cycles_remaining <= decoder_io_paced ? delay_count : decoder_io_cycles - 1'b1;
				io_active <= decoder_io_paced ? (delay_count != 0) : (decoder_io_cycles > 1);
				if (decoder_output_shift) begin
					for (pin_index = 0; pin_index < GPIO_WIDTH; pin_index = pin_index + 1) begin
						osr_gpio_hold_mask[pin_index] <=
							(pin_index >= decoder_gpio_base) &&
							(pin_index < (decoder_gpio_base + decoder_gpio_count));
						if ((pin_index >= decoder_gpio_base) &&
							(pin_index < (decoder_gpio_base + decoder_gpio_count)))
							osr_gpio_hold_data[pin_index] <=
								osr_parallel_data_out[pin_index - decoder_gpio_base];
					end
				end
			end else if (io_active && start) begin
				if (io_cycles_remaining <= 1) begin
					io_cycles_remaining <= 0;
					io_active <= 1'b0;
				end else begin
					io_cycles_remaining <= io_cycles_remaining - 1'b1;
				end
			end

		end
	end

	genvar gpio_index;
	generate
		for (gpio_index = 0; gpio_index < GPIO_WIDTH; gpio_index = gpio_index + 1) begin : gpio_output_mux
			wire osr_selected = osr_instruction_shift &&
				(gpio_index >= active_gpio_base) &&
				(gpio_index < (active_gpio_base + active_gpio_count));
			wire set_selected = (gpio_index >= decoder_gpio_base) &&
				(gpio_index < (decoder_gpio_base + decoder_gpio_count));
			assign gpio_out_mux[gpio_index] = (osr_gpio_live &&
				(gpio_index >= active_gpio_base) &&
				(gpio_index < (active_gpio_base + active_gpio_count))) ?
				osr_parallel_data_out[gpio_index - active_gpio_base] :
				(osr_gpio_hold_mask[gpio_index] ? osr_gpio_hold_data[gpio_index] : gpio_out_reg[gpio_index]);
			assign gpio_oe_program_mask[gpio_index] = execute_enable &&
				((set_selected && decoder_set_direction) || gpio_set[gpio_index] || gpio_clear[gpio_index]);
			assign gpio_oe_program_value[gpio_index] = decoder_set_direction ?
				decoder_gpio_output_enable : 1'b1;
		end
	endgenerate

	delay_counter delay_counter_i (
		.clk            (clk),
		.rst_n          (rst_n),
		.start          (start),
		.delay_value    (delay_count),
		.execute_enable (execute_enable)
	);

	prog_counter program_counter_i (
		.clk        (clk),
		.prog_enable(prog_enable),
		.rst_n      (rst_n),
		.start      (pc_execute_enable),
		.pc_out     (pc_out),
		.wrap_target(wrap_target),
		.wrap_address(wrap_address),
		.jmp        (jump),
		.jmp_addr   (jump_addr)
	);

	// Legacy GPIO instructions update output data; GPIO owns persistent direction state.
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			gpio_out_reg <= {GPIO_WIDTH{1'b0}};
		end else if (execute_enable) begin
			gpio_out_reg <= (gpio_out_reg | gpio_set) & ~gpio_clear;
		end
	end

	gpio #(.GPIO_WIDTH(GPIO_WIDTH)) gpio_i (
		.clk    (clk),
		.rst_n  (rst_n),
		.gpio_out(gpio_out_mux),
		.gpio_oe ({GPIO_WIDTH{1'b0}}),
		.oe_program_write(execute_enable &&
			(decoder_set_direction || (|gpio_set) || (|gpio_clear))),
		.oe_program_mask(gpio_oe_program_mask),
		.oe_program_value(gpio_oe_program_value),
		.oe_state(gpio_oe_state),
		.gpio_in (gpio_in),
		.gpio    (gpio)
	);

endmodule
