// Decodes the initial four-instruction control set.
// Format: [31:28] opcode, [27:0] operand.
module decoder #(
	parameter integer INSTRUCTION_WIDTH = 32,
	parameter integer GPIO_WIDTH = 8
) (
	input wire [INSTRUCTION_WIDTH-1:0] instruction,
	output reg                         jump,
	output reg [INSTRUCTION_WIDTH-1:0] jump_addr,
	output reg [GPIO_WIDTH-1:0]        gpio_set,
	output reg [GPIO_WIDTH-1:0]        gpio_clear,
	output reg                         delay
);

	localparam integer OPCODE_WIDTH = 4;
	localparam [OPCODE_WIDTH-1:0] OP_JUMP       = 4'b0001;
	localparam [OPCODE_WIDTH-1:0] OP_SET_GPIO   = 4'b0010;
	localparam [OPCODE_WIDTH-1:0] OP_CLEAR_GPIO = 4'b0011;
	localparam [OPCODE_WIDTH-1:0] OP_DELAY     = 4'b0100;

	wire [OPCODE_WIDTH-1:0] opcode = instruction[INSTRUCTION_WIDTH-1 -: OPCODE_WIDTH];
	wire [GPIO_WIDTH-1:0] gpio_operand = instruction[GPIO_WIDTH-1:0];

	always @* begin
		// Defaults keep delay and unsupported instructions side-effect free.
		jump = 1'b0;
		jump_addr = {INSTRUCTION_WIDTH{1'b0}};
		gpio_set = {GPIO_WIDTH{1'b0}};
		gpio_clear = {GPIO_WIDTH{1'b0}};
		delay = 1'b0;

		case (opcode)
			OP_JUMP: begin
				jump = 1'b1;
				// The opcode is not part of the jump target.
				jump_addr = {{OPCODE_WIDTH{1'b0}}, instruction[INSTRUCTION_WIDTH-OPCODE_WIDTH-1:0]};
			end
			OP_SET_GPIO: begin
				gpio_set = gpio_operand;
			end
			OP_CLEAR_GPIO: begin
				gpio_clear = gpio_operand;
			end
			OP_DELAY: begin
				delay = 1'b1;
			end
			default: begin
				// Reserved opcodes intentionally decode to no operation.
			end
		endcase
	end
endmodule