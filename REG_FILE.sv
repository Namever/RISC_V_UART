//======================
// Register File
//======================
module REG_FILE(
    input  logic        clk,
    input  logic        rst,
    input  logic        write_regf_en_r,
    input  logic [4:0]  addr_rd_r,
    input  logic [4:0]  addr_rs1,
    input  logic [4:0]  addr_rs2,
    input  logic [31:0] rd_value_,
    output logic [31:0] rs1_value_,
    output logic [31:0] rs2_value_,
	output logic [31:0] regs_31
);
    logic [31:0] regs[0:31];
    logic addr_rd_not_0;
	logic [31:0] rs1_value;
	logic [31:0] rs2_value;
	logic sel_rs1_value_,sel_rs2_value_;
    integer i;

    assign addr_rd_not_0 = |addr_rd_r;
    assign rs1_value = regs[addr_rs1];
    assign rs2_value = regs[addr_rs2];
	assign regs_31 = regs[31];
	
	//forwarding unit
	assign sel_rs1_value_ = write_regf_en_r & (addr_rd_r == addr_rs1);
	assign sel_rs2_value_ = write_regf_en_r & (addr_rd_r == addr_rs2);
	assign rs1_value_ = sel_rs1_value_ ? rd_value_ : rs1_value;
	assign rs2_value_ = sel_rs2_value_ ? rd_value_ : rs2_value;
	
    always_ff @(posedge clk) begin
        if (rst)
            for (i = 0; i < 32; i++) regs[i] <= 0;
        else if (write_regf_en_r && addr_rd_not_0)
            regs[addr_rd_r] <= rd_value_;
    end
endmodule
