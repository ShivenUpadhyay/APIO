// Default-parameter integration of the instruction stream, decoder, PC, and GPIO.
module top_v1 (
	input  wire        clk,
	input  wire        rst_n,
	input  wire        start,
	input  wire        prog_enable,
	input  wire [31:0] wrap_pc,
	input  wire [31:0] instruction_in,
	input  wire        write_enable,
	output wire [31:0] pc_out,
	output wire [31:0] instruction_out,
	output wire        fifo_empty,
	output wire [7:0]  gpio_in,
	inout  wire [7:0]  gpio
);

	wire        jump;
	wire [31:0] jump_addr;
	wire [7:0]  gpio_set;
	wire [7:0]  gpio_clear;
	wire        delay;
	wire [3:0]  instruction_addr;
	reg  [7:0]  gpio_out_reg;
	reg  [7:0]  gpio_oe_reg;

	assign instruction_addr = pc_out[3:0];

	instruction_memory instruction_memory_i (
		.clk            (clk),
		.rst_n          (rst_n),
		.instruction_in(instruction_in),
		.write_enable   (write_enable),
		.read_addr      (instruction_addr),
		.instruction_out(instruction_out),
		.fifo_empty     (fifo_empty)
	);

	decoder decoder_i (
		.instruction(instruction_out),
		.jump       (jump),
		.jump_addr  (jump_addr),
		.gpio_set   (gpio_set),
		.gpio_clear (gpio_clear),
		.delay      (delay)
	);

	program_counter program_counter_i (
		.clk        (clk),
		.prog_enable(prog_enable),
		.rst_n      (rst_n),
		.start      (start),
		.pc_out     (pc_out),
		.wrap_pc    (wrap_pc),
		.jmp        (jump),
		.jmp_addr   (jump_addr),
		.delay      (delay)
	);

	// Set and clear instructions update persistent GPIO output state.
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			gpio_out_reg <= 8'b0;
			gpio_oe_reg <= 8'b0;
		end else begin
			gpio_out_reg <= (gpio_out_reg | gpio_set) & ~gpio_clear;
			gpio_oe_reg <= gpio_oe_reg | gpio_set | gpio_clear;
		end
	end

	aio_gpio gpio_i (
		.clk    (clk),
		.gpio_out(gpio_out_reg),
		.gpio_oe (gpio_oe_reg),
		.gpio_in (gpio_in),
		.gpio    (gpio)
	);

endmodule
