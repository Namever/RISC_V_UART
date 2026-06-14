module DE2_115(
	input clk,
	input RESET_N,
	input  [17:0] SW,
	input  UART_RXD,
	output [6:0] HEX0,
	output [6:0] HEX1,
	output [6:0] HEX2,
	output [6:0] HEX3,
	output [6:0] HEX4,
	output [6:0] HEX5
);

logic [31:0] regs_31;
logic clk_div;
logic [31:0] pc;

clock_divider u_clock_divider(
    .clk    (clk),
    .rst    (~RESET_N),
    .DIVISOR(5000000),
    .clk_out(clk_div)
);

Top u_Core(
    .clk    (clk_div),
	 .clk_50M    (clk),
    .rst    (~RESET_N),
	 .UART_RXD   (UART_RXD),
    .regs_31(regs_31),
	.SW		(SW),
	.pc     (pc)
);


// Instance for 7-segment display for each HEX display
seven_segment_display u_seven_0(
	.digit (regs_31[3:0]),
	.seg (HEX0)
);

seven_segment_display u_seven_1(
	.digit (regs_31[7:4]),
	.seg (HEX1)
);

seven_segment_display u_seven_2(
	.digit (regs_31[11:8]),
	.seg (HEX2)
);

seven_segment_display u_seven_3(
	.digit (regs_31[15:12]),
	.seg (HEX3)
);

seven_segment_display u_seven_4(
	.digit (pc[3:0]),
	.seg (HEX4)
);

seven_segment_display u_seven_5(
	.digit (pc[7:4]),
	.seg (HEX5)
);

endmodule
