`timescale 1ns/1ps

module tb_fractional_clock_divider;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg enable = 1'b0;
    reg sync = 1'b0;
    reg [31:0] output_frequency_hz = 0;
    wire divided_clk;
    integer clocks_to_toggle;

    always #5 clk = ~clk;

    fractional_clock_divider #(
        .CLOCK_FREQUENCY_HZ(100_000_000)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .sync(sync),
        .output_frequency_hz(output_frequency_hz),
        .divided_clk(divided_clk)
    );

    task synchronize_rising_edge;
        begin
            @(negedge clk);
            sync = 1'b1;
            @(posedge clk);
            #1;
            if (divided_clk !== 1'b1)
                $fatal(1, "sync did not establish a rising divided-clock edge");
            @(negedge clk);
            sync = 1'b0;
        end
    endtask

    task expect_next_toggle;
        input integer expected_clocks;
        begin
            clocks_to_toggle = 0;
            while (divided_clk === 1'b1 && clocks_to_toggle <= expected_clocks) begin
                @(posedge clk);
                #1;
                clocks_to_toggle = clocks_to_toggle + 1;
            end
            if (clocks_to_toggle != expected_clocks || divided_clk !== 1'b0)
                $fatal(1, "frequency %0d Hz toggled after %0d clocks, expected %0d",
                       output_frequency_hz, clocks_to_toggle, expected_clocks);
        end
    endtask

    initial begin
        #12;
        rst_n = 1'b1;
        enable = 1'b1;

        output_frequency_hz = 10_000_000;
        synchronize_rising_edge();
        expect_next_toggle(5);

        output_frequency_hz = 12_500_000;
        synchronize_rising_edge();
        expect_next_toggle(4);

        output_frequency_hz = 10_000_000;
        synchronize_rising_edge();
        expect_next_toggle(5);

        $display("PASS: fractional divider frequency is runtime programmable");
        $finish;
    end
endmodule
