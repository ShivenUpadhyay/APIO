/* Decodes instructions with an embedded delay field.
Format: [31:28] opcode, [27:24] delay cycles, [23:0] operand.
*/
module decoder_v1 #(
	parameter integer INSTRUCTION_WIDTH = 32,
	parameter integer GPIO_WIDTH = 8
) (
	input wire [INSTRUCTION_WIDTH-1:0] instruction,
	output reg                         jump,
	output reg [INSTRUCTION_WIDTH-1:0] jump_addr,
	output reg [GPIO_WIDTH-1:0]        gpio_set,
	output reg [GPIO_WIDTH-1:0]        gpio_clear,
	output reg [3:0]                   delay_count,
	output reg                         input_shift,
	output reg                         output_shift,
	output reg                         pull,
	output reg                         push,
	output reg                         set_gpio_direction,
	output reg                         gpio_output_enable,
	output reg [3:0]                   gpio_base,
	output reg [3:0]                   gpio_count,
	output reg [3:0]                   io_cycles,
	output reg                         io_paced,
	output reg                         input_lsb_first,
	output reg                         wait_pin,
	output reg                         wait_pin_value,
	output reg [3:0]                   wait_pin_index
);

	localparam integer OPCODE_WIDTH = 4;
	localparam [OPCODE_WIDTH-1:0] OP_JUMP       = 4'b0001;
	localparam [OPCODE_WIDTH-1:0] OP_SET_GPIO   = 4'b0010;
	localparam [OPCODE_WIDTH-1:0] OP_CLEAR_GPIO = 4'b0011;
	localparam [OPCODE_WIDTH-1:0] OP_IN         = 4'b0100;
	localparam [OPCODE_WIDTH-1:0] OP_OUT        = 4'b0101;
	localparam [OPCODE_WIDTH-1:0] OP_PULL       = 4'b0110;
	localparam [OPCODE_WIDTH-1:0] OP_PUSH       = 4'b0111;
	localparam [OPCODE_WIDTH-1:0] OP_SET        = 4'b1000;
	localparam [OPCODE_WIDTH-1:0] OP_WAIT       = 4'b1001;
	localparam [OPCODE_WIDTH-1:0] OP_WAIT_PIN   = 4'b1010;

	wire [OPCODE_WIDTH-1:0] opcode = instruction[INSTRUCTION_WIDTH-1 -: OPCODE_WIDTH];
	wire [GPIO_WIDTH-1:0] gpio_operand = instruction[GPIO_WIDTH-1:0];
	wire [3:0] instruction_delay = instruction[27:24];

	always @* begin
		// Unsupported instructions remain side-effect free.
		jump = 1'b0;
		jump_addr = {INSTRUCTION_WIDTH{1'b0}};
		gpio_set = {GPIO_WIDTH{1'b0}};
		gpio_clear = {GPIO_WIDTH{1'b0}};
		delay_count = 4'd0;
		input_shift = 1'b0;
		output_shift = 1'b0;
		pull = 1'b0;
		push = 1'b0;
		set_gpio_direction = 1'b0;
		gpio_output_enable = 1'b0;
		gpio_base = instruction[23:20];
		gpio_count = instruction[19:16] + 1'b1;
		io_cycles = (instruction_delay == 0) ? 4'd1 : instruction_delay;
		io_paced = instruction[15];
		input_lsb_first = 1'b0;
		wait_pin = 1'b0;
		wait_pin_value = 1'b0;
		wait_pin_index = instruction[23:20];

		case (opcode)
			OP_JUMP: begin
				jump = 1'b1;
				// The opcode is not part of the jump target.
				jump_addr = {{8{1'b0}}, instruction[23:0]};
			end
			OP_SET_GPIO: begin
				gpio_set = gpio_operand;
				delay_count = instruction_delay;
			end
			OP_CLEAR_GPIO: begin
				gpio_clear = gpio_operand;
				delay_count = instruction_delay;
			end
			OP_IN: begin
				input_shift = 1'b1;
				input_lsb_first = io_paced;
				if (io_paced) begin
					io_cycles = 4'd1;
					delay_count = instruction_delay;
				end else begin
					delay_count = io_cycles - 1'b1;
				end
			end
			OP_OUT: begin
				output_shift = 1'b1;
				if (io_paced) begin
					io_cycles = 4'd1;
					delay_count = instruction_delay;
				end else begin
					delay_count = io_cycles - 1'b1;
				end
			end
			OP_PULL: begin
				pull = 1'b1;
			end
			OP_PUSH: begin
				push = 1'b1;
			end
			OP_SET: begin
				set_gpio_direction = 1'b1;
				gpio_output_enable = instruction[15];
			end
			OP_WAIT: begin
				delay_count = instruction_delay;
			end
			OP_WAIT_PIN: begin
				wait_pin = 1'b1;
				wait_pin_value = instruction[15];
			end
			default: begin
				// Reserved opcodes intentionally decode to no operation.
			end
		endcase
	end
endmodule