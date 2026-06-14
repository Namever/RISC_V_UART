`timescale 1ns/100ps

`define ALUOP_ADD      4'h0
`define ALUOP_SUB      4'h1
`define ALUOP_AND      4'h2
`define ALUOP_OR       4'h3
`define ALUOP_XOR      4'h4
`define ALUOP_A        4'h5
`define ALUOP_A_ADD_4  4'h6
`define ALUOP_LTU      4'h7
`define ALUOP_LT       4'h8
`define ALUOP_SLL      4'h9
`define ALUOP_SRL      4'hA
`define ALUOP_SRA      4'hB
`define ALUOP_B        4'hC
`define Opcode_I       7'b0010011
`define Opcode_B       7'b1100011
`define F_ADDI       3'b000
`define F_SLTI       3'b010
`define F_SLTIU      3'b011
`define F_XORI       3'b100
`define F_ORI        3'b110
`define F_ANDI       3'b111
`define F_SLLI       3'b001
`define F_SRLI_SRAI  3'b101
`define F7_SRLI      7'b0000000
`define F7_SRAI      7'b0100000
`define Opcode_R 	 7'b0110011	
`define Opcode_JAL 	 7'b1101111
`define Opcode_JALR  7'b1100111		
`define Opcode_LUI 	 7'b0110111
`define Opcode_AUIPC 7'b0010111	
`define Opcode_L 	 7'b0000011
`define Opcode_S 	 7'b0100011
`define F_LB 	     3'b000
`define F_LH 	     3'b001
`define F_LW 	     3'b010
`define F_LBU 	     3'b100
`define F_LHU 	     3'b101
`define F_SB 	     3'b000
`define F_SH 	     3'b001						
`define F_SW 	     3'b010

`define F_BEQ   3'b000
`define F_BNE   3'b001
`define F_BLT   3'b100
`define F_BGE   3'b101
`define F_BLTU  3'b110
`define F_BGEU  3'b111

`define F7_M     7'b0000001
`define Opcode_R_M 7'b0110011  

`define F_MUL    3'b000
`define F_MULH   3'b001
`define F_MULHSU 3'b010
`define F_MULHU  3'b011
`define F_DIV    3'b100
`define F_DIVU   3'b101
`define F_REM    3'b110
`define F_REMU   3'b111

//======================
// Program Counter 模組
//======================
module Program_Counter(
    input  logic clk,
    input  logic rst,
    input  logic rst_pc,
	input  logic sel_pc_r,
	input  logic [31:0] jump_addr_,
    output logic [31:0] pc
);
    logic [31:0] pc_next;
	logic [31:0] pc4;
    assign pc4 = pc + 4;
	
	always_comb begin		
		unique case (sel_pc_r)
			1'b0 : pc_next = pc4;
			1'b1 : pc_next = jump_addr_;
		endcase
	end

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            pc <= 32'd0;
		  else if (rst_pc) 
				pc <= 32'b0;
        else
            pc <= pc_next;
    end
endmodule

//======================
// IF/ID 模組
//======================
module IF_ID(
    input  logic        clk,
    input  logic        rst,
    input  logic        flush_IFID_r,
    input  logic [31:0] inst,
    input  logic [31:0] pc,
    output logic [31:0] inst_r,
    output logic [31:0] pc_r
);
    logic rst_or_flush_IFID;
    assign rst_or_flush_IFID = rst | flush_IFID_r;

    always_ff @(posedge clk) begin
        if (rst_or_flush_IFID) begin
            inst_r <= 32'h13;
            pc_r   <= 32'd0;
        end else begin
            inst_r <= inst;
            pc_r   <= pc;
        end
    end
endmodule


//======================
// Instruction Decoder
//======================
module INST_DEC(
    input  logic [31:0] inst_r,
    output logic [6:0]  opcode_,
    output logic [2:0]  funct3_,
    output logic [6:0]  funct7_,
    output logic [4:0]  addr_rd_,
    output logic [4:0]  addr_rs1_,
    output logic [4:0]  addr_rs2_,
    output logic [31:0] imm_
);
	logic [31:0] IMM_I;
	logic [31:0] IMM_B;
	logic [31:0] IMM_JAL;
	logic [31:0] IMM_LUI_AUIPC;
	logic [31:0] IMM_S;
	 
    assign opcode_   = inst_r[6:0];
	assign funct3_   = inst_r[14:12];
    assign addr_rd_  = inst_r[11:7];
    assign addr_rs1_ = inst_r[19:15];
    assign addr_rs2_ = inst_r[24:20];
    assign funct7_   = inst_r[31:25];
	 
	assign IMM_I 		 = {{20{inst_r[31]}}, inst_r[31:20]};
    assign IMM_B 		 = {{20{inst_r[31]}}, inst_r[7], inst_r[30:25], inst_r[11:8], 1'b0};
	assign IMM_JAL		 = {{12{inst_r[31]}}, inst_r[19:12], inst_r[20], inst_r[30:21], 1'b0}; 
	assign IMM_LUI_AUIPC = {inst_r[31:12], 12'b0};
	assign IMM_S         = {{20{inst_r[31]}}, inst_r[31:25], inst_r[11:7]};

	 always_comb begin
		 unique case (opcode_)
		 	 `Opcode_I    :imm_ = IMM_I;
			 `Opcode_B    :imm_ = IMM_B;
			 `Opcode_JAL  :imm_ = IMM_JAL;
			 `Opcode_JALR :imm_ = IMM_I;
			 `Opcode_LUI  :imm_ = IMM_LUI_AUIPC;
			 `Opcode_AUIPC:imm_ = IMM_LUI_AUIPC;
			 `Opcode_L    :imm_ = IMM_I;
			 `Opcode_S    :imm_ = IMM_S;
		 endcase
	 end
endmodule


//======================
// Controller (FSM)
//======================
module CONTROLLER(
    input  logic clk,
    input  logic rst,
    input  logic [6:0] opcode_,
    input  logic [2:0] funct3_,
    input  logic [6:0] funct7_,
	input  logic [31:0] rs1_value_,
    input  logic [31:0] rs2_value_,
    output logic flush_IFID_,
    output logic flush_IDEX_,
	output logic write_read_,
	output logic sel_pc_,
    output logic rst_pc_,
	output logic [1:0] sel_rd_value_,
    output logic write_regf_en,
	output logic [1:0] sel_alu_b_,
	output logic sel_jump_,
	output logic sel_alu_a_,
    output logic [3:0] op
);

	logic BEQ_FLAG;
	logic BNE_FLAG;
	logic BLT_FLAG;
	logic BGE_FLAG;
	logic BLTU_FLAG;
	logic BGEU_FLAG;

	assign BEQ_FLAG  = (rs1_value_ ==  rs2_value_);
	assign BNE_FLAG  = (rs1_value_ !=  rs2_value_);
	assign BLT_FLAG  = ($signed(rs1_value_) <   $signed(rs2_value_));
	assign BGE_FLAG  = ($signed(rs1_value_) >=  $signed(rs2_value_));
	assign BLTU_FLAG = (rs1_value_ <   rs2_value_);
	assign BGEU_FLAG = (rs1_value_ >=  rs2_value_);

    typedef enum logic [1:0] {S0, S1, S2} FSM_STATE;
    FSM_STATE ps, ns;

    always_ff @(posedge clk or posedge rst)
        if (rst) ps <= S0;
        else     ps <= ns;

    always_comb begin
		sel_alu_a_ = 0;
		sel_jump_ = 0;
        rst_pc_ = 0;
        flush_IFID_ = 0;
        flush_IDEX_ = 0;
		sel_pc_ = 0;
        write_regf_en = 0;
		sel_alu_b_ = 0;
		sel_rd_value_ = 0;
		write_read_ = 0;
        ns = ps;
        op = `ALUOP_A;

        unique case (ps)
            S0: begin
                flush_IFID_ = 1;
                flush_IDEX_ = 1;
                rst_pc_ = 1;
				sel_pc_ = 1;
                ns = S1;
            end
            S1: begin
                flush_IFID_ = 1;
                flush_IDEX_ = 1;
                rst_pc_ = 1;
				sel_pc_ = 1;
                ns = S2;
            end
            S2: begin
                unique case (opcode_ )
					`Opcode_I : 
					begin
						write_regf_en = 1;
						unique case (funct3_)
							`F_ADDI  : op = `ALUOP_ADD;
							`F_SLTI  : op = `ALUOP_LT;
							`F_SLTIU : op = `ALUOP_LTU;
							`F_ANDI  : op = `ALUOP_AND;
							`F_ORI   : op = `ALUOP_OR;
							`F_XORI  : op = `ALUOP_XOR;
							`F_SLLI  : op = `ALUOP_SLL;
							`F_SRLI_SRAI: begin
									unique case(funct7_)
										`F7_SRLI : op = `ALUOP_SRL;
										`F7_SRAI : op = `ALUOP_SRA;
									endcase
                            end
                            default : op = `ALUOP_A;
						endcase
					end
					`Opcode_R :
					begin
						write_regf_en = 1;
						sel_alu_b_ = 1;
						unique case (funct7_)
							7'b0000000 : begin
								unique case(funct3_)
									3'b000 : op = `ALUOP_ADD;
									3'b001 : op = `ALUOP_SLL;
									3'b010 : op = `ALUOP_LT;
									3'b011 : op = `ALUOP_LTU;
									3'b100 : op = `ALUOP_XOR;
									3'b101 : op = `ALUOP_SRL;
									3'b110 : op = `ALUOP_OR;
									3'b111 : op = `ALUOP_AND;
								endcase
							end
									
							7'b0100000 : begin
								unique case(funct3_)
									3'b000 : op = `ALUOP_SUB;
									3'b101 : op = `ALUOP_SRA;
								endcase
							end
						
							`F7_M: begin
								unique case(funct3_)
								`F_MUL:begin
									write_regf_en = 1;
									sel_rd_value_ = 2;
								end
								`F_MULHU:begin
									write_regf_en = 1;
									sel_rd_value_ = 2;
								end
								`F_MULHSU:begin
									write_regf_en = 1;
									sel_rd_value_ = 2;
								end
								`F_MULH:begin
									write_regf_en = 1;
									sel_rd_value_ = 2;
								end
								`F_DIV:begin
									write_regf_en = 1;
									sel_rd_value_ = 3;
								end
								`F_DIVU:begin
									write_regf_en = 1;
									sel_rd_value_ = 3;
								end
								`F_REM:begin
									write_regf_en = 1;
									sel_rd_value_ = 3;
								end
								`F_REMU:begin
									write_regf_en = 1;
									sel_rd_value_ = 3;
								end
								endcase
							end
						endcase
					end
					`Opcode_B: 
					begin
						sel_jump_  =  1;
						unique case (funct3_)
							`F_BEQ: begin
								if (BEQ_FLAG) begin  
									sel_pc_     = 1;
									flush_IFID_ = 1;
									flush_IDEX_ = 1;
									
								end
							end
							`F_BNE: begin
								if (BNE_FLAG) begin  
									sel_pc_     = 1;
									flush_IFID_ = 1;
									flush_IDEX_ = 1;
								end
							end
							`F_BLT: begin
								if (BLT_FLAG) begin   
									sel_pc_     = 1;
									flush_IFID_ = 1;
									flush_IDEX_ = 1;
								end
							end
							`F_BGE: begin
								if (BGE_FLAG) begin   
									sel_pc_     = 1;
									flush_IFID_ = 1;	
									flush_IDEX_ = 1;
								end
							end
							`F_BLTU: begin
								if (BLTU_FLAG) begin  
									sel_pc_     = 1;
									flush_IFID_ = 1;
									flush_IDEX_ = 1;
								end
							end
							`F_BGEU: begin
								if (BGEU_FLAG) begin   
									sel_pc_     = 1;
									flush_IFID_ = 1;
									flush_IDEX_ = 1;
								end
							end
						endcase
					end
					`Opcode_JAL: 
					begin
						sel_pc_       = 1;
						flush_IFID_   = 1;
						flush_IDEX_   = 1;
						sel_alu_a_    = 1;
						sel_alu_b_    = 2'b10;
						sel_jump_     = 1;
						write_regf_en = 1;
						op = `ALUOP_ADD;
					end
					`Opcode_JALR: 
					begin
						sel_pc_       = 1;
						flush_IFID_   = 1;
						flush_IDEX_   = 1;
						sel_alu_a_    = 1;
						sel_alu_b_    = 2'b10;
						sel_jump_     = 0;
						write_regf_en = 1;
						op = `ALUOP_ADD;
					end
					`Opcode_LUI: 
					begin
						sel_alu_b_    = 0;
						write_regf_en = 1;
						op = `ALUOP_B;
					end
					`Opcode_AUIPC: 
					begin
						sel_alu_a_    = 1;
						sel_alu_b_    = 0;
						write_regf_en = 1;
						op = `ALUOP_ADD;
					end
					`Opcode_L: begin
						op = `ALUOP_ADD;
						sel_rd_value_ = 1;
						write_regf_en = 1;
					end
					`Opcode_S: begin
						op = `ALUOP_ADD;
						write_read_ = 1;
					end
					default: begin
                        sel_pc_ = 1'b1;
                        rst_pc_ = 1'b1;
                        flush_IFID_ = 1'b1;
                        flush_IDEX_ = 1'b1;
               end
				endcase
			end
		endcase
	end
endmodule



//======================
// ID/EX pipeline register
//======================
module ID_EX(
    input  logic        clk,
    input  logic        rst,
	input  logic [2:0]  funct3_,
    input  logic        flush_IDEX_,
	input  logic        flush_IFID_,
	input  logic        sel_pc_,
    input  logic        write_regf_en,
	input  logic		sel_jump_,
	input  logic        sel_alu_a_,
	input  logic [1:0]  sel_rd_value_,
	input  logic        write_read_,
	input  logic [1:0]  sel_alu_b_,
	input  logic [31:0] pc_r,
    input  logic [31:0] imm,
    input  logic [31:0] rs1_value_,
    input  logic [31:0] rs2_value_,
    input  logic [4:0]  addr_rd,
	input  logic [3:0]  op,
	output logic [3:0]  op_r,
	output logic [31:0] pc_rr,
    output logic [31:0] imm_r,
    output logic [31:0] rs1_value_r,
    output logic [31:0] rs2_value_r,
	output logic [2:0]  funct3_r,
    output logic [4:0]  addr_rd_r,
    output logic        write_regf_en_r,
	output logic [1:0]  sel_rd_value_r,
	output logic		sel_alu_a_r,
	output logic		write_read_r,
	output logic [1:0]  sel_alu_b_r,
	output logic 		sel_jump_r,
	output logic        flush_IDEX_r,
	output logic        flush_IFID_r,
	output logic        sel_pc_r,
	output logic [31:0] jump_addr_
);
    logic rst_or_flush_IDEX;
	logic [31:0] base_addr_;
	logic [31:0] j_addr_;
    assign rst_or_flush_IDEX = rst | flush_IDEX_r;
	
	//---------------------------------------------------------------
	always_comb begin
		unique case (sel_jump_r)
			1'b0 : base_addr_ = rs1_value_r;
			1'b1 : base_addr_ = pc_rr;
		endcase
	end
	
	assign j_addr_ = base_addr_ + imm_r;
	assign jump_addr_ = {j_addr_[31:1],(j_addr_[0] & sel_jump_r)};
	
	//---------------------------------------------------------------

    always_ff @(posedge clk) begin
        if (rst_or_flush_IDEX) begin
            imm_r           <= 32'd0;
            rs1_value_r     <= 32'd0;
            rs2_value_r     <= 32'd0;
            addr_rd_r       <= 5'd0;
            write_regf_en_r <= 1'b0;
			op_r            <= 4'b0;
			sel_jump_r		<= 1'b0;
			sel_alu_a_r     <= 1'b0;
			sel_alu_b_r     <= 2'b0;
			flush_IDEX_r    <= 1'b0;
			flush_IFID_r    <= 1'b0;
			sel_pc_r        <= 1'b0;
			pc_rr           <= 32'd0;
			funct3_r        <= 3'b0;
			sel_rd_value_r  <= 2'b00;
			write_read_r    <= 1'b0;
			
			
        end else begin
            imm_r           <= imm;
            rs1_value_r     <= rs1_value_;
            rs2_value_r     <= rs2_value_;
            addr_rd_r       <= addr_rd;
            write_regf_en_r <= write_regf_en;
			op_r            <= op;
			sel_jump_r		<= sel_jump_;
			sel_alu_a_r		<= sel_alu_a_;
			sel_alu_b_r     <= sel_alu_b_;
			flush_IDEX_r    <= flush_IDEX_;
			flush_IFID_r    <= flush_IFID_;
			sel_pc_r        <= sel_pc_;  
			pc_rr           <= pc_r;
			funct3_r        <= funct3_;
			sel_rd_value_r  <= sel_rd_value_;
			write_read_r    <= write_read_;	
        end
    end
endmodule


module ALU(
	input  logic [3:0]  op_r,      // ALU 操作碼
	input  logic [31:0] imm_r,
	input  logic [31:0] pc_rr,
	input  logic [31:0] rs1_value_r,
	input  logic [31:0] rs2_value_r,
	input  logic        sel_alu_a_r,
	input  logic [1:0]  sel_alu_b_r,
    output logic [31:0] alu_out  // 計算結果
);
	logic [31:0] alu_a;
	logic [31:0] alu_b;
	
	always_comb begin
		unique case (sel_alu_b_r)
			2'b0 : alu_b = imm_r;
			2'b1 : alu_b = rs2_value_r;
			2'b10: alu_b = 4;
		endcase
	end
	
	always_comb begin
		unique case (sel_alu_a_r)
			1'b0 : alu_a = rs1_value_r;
			1'b1 : alu_a = pc_rr;
		endcase
	end

	always_comb begin
        unique case (op_r)
            `ALUOP_ADD    : alu_out = alu_a + alu_b;                         // 加法
            `ALUOP_SUB    : alu_out = $signed(alu_a) - $signed(alu_b);       // 減法（有號）
            `ALUOP_AND    : alu_out = alu_a & alu_b;
            `ALUOP_OR     : alu_out = alu_a | alu_b;
            `ALUOP_XOR    : alu_out = alu_a ^ alu_b;
            `ALUOP_A      : alu_out = alu_a;
            `ALUOP_A_ADD_4: alu_out = alu_a + 4;
            `ALUOP_LTU    : alu_out = alu_a < alu_b;                         // 無號比較
            `ALUOP_LT     : alu_out = $signed(alu_a) < $signed(alu_b);       // 有號比較
            `ALUOP_SLL    : alu_out = alu_a << alu_b[4:0];                   // 邏輯左移
            `ALUOP_SRL    : alu_out = alu_a >> alu_b[4:0];                   // 邏輯右移
            `ALUOP_SRA    : alu_out = $signed(alu_a) >>> alu_b[4:0];         // 算術右移
            `ALUOP_B      : alu_out = alu_b;
            default       : alu_out = alu_a;                                 // 預設傳遞 A
        endcase
    end
endmodule

//======================
// RAM 模組
//======================
module RAM(
    input  logic        clk,
    input  logic        write_read,
    input  logic [7:0]  rs2_value_r,
	//input  logic [29:0] ram_addr,
    input  logic [6:0] ram_addr,
    output logic [7:0] read_data
);
    logic [7:0] ram[0:127];
	
	assign read_data = ram[ram_addr];
	
	always_ff @(posedge clk)begin
		if (write_read)begin
			ram[ram_addr] <= #1 rs2_value_r;
		end
	end
endmodule


//======================
// LSU 模組 (MUL/DIV)
//======================
module LSU(
    input  logic        clk,
	input  logic [31:0] alu_out,
	input  logic [2:0]  funct3_r,
	input  logic        write_read_r,
	input  logic [31:0] rs1_value_r,
    input  logic [31:0] rs2_value_r,
	input  logic [1:0]	sel_rd_value_r,
    output logic [31:0] rd_value_
);
    
	//ADDR_MUX
	logic [31:0] ram_addr;
	logic [31:0] ram_addr_p1;
	logic [31:0] ram_addr_p2;
	logic [31:0] ram_addr_p3;
	logic [31:0] ram_addr_0;
	logic [31:0] ram_addr_1;
	logic [31:0] ram_addr_2;
	logic [31:0] ram_addr_3;

    assign ram_addr = alu_out;
	
	assign ram_addr_p1 = ram_addr + 1;
	assign ram_addr_p2 = ram_addr + 2;
	assign ram_addr_p3 = ram_addr + 3;
	
	always_comb begin
		unique case (ram_addr[1:0])
			2'b00: begin
				ram_addr_0 = ram_addr[31:2];
				ram_addr_1 = ram_addr_p1[31:2];
				ram_addr_2 = ram_addr_p2[31:2];
				ram_addr_3 = ram_addr_p3[31:2];
			end
			2'b01: begin
				ram_addr_0 = ram_addr_p3[31:2];
				ram_addr_1 = ram_addr[31:2];
				ram_addr_2 = ram_addr_p1[31:2];
				ram_addr_3 = ram_addr_p2[31:2];
			end
			2'b10: begin
				ram_addr_0 = ram_addr_p2[31:2];
				ram_addr_1 = ram_addr_p3[31:2];
				ram_addr_2 = ram_addr[31:2];
				ram_addr_3 = ram_addr_p1[31:2];
			end
			2'b11: begin
				ram_addr_0 = ram_addr_p1[31:2];
				ram_addr_1 = ram_addr_p2[31:2];
				ram_addr_2 = ram_addr_p3[31:2];
				ram_addr_3 = ram_addr[31:2];
			end
		endcase
	end
	
	//WRITE_MUX
	logic write_0;  //en_bank_0
	logic write_1;
	logic write_2;
	logic write_3;
	always_comb begin
		write_0 = 0;
		write_1 = 0;
		write_2 = 0;
		write_3 = 0;
		unique case (funct3_r)
			`F_SB: begin
				unique case (ram_addr[1:0])
					2'b00 : write_0 = 1;
					2'b01 : write_1 = 1;
					2'b10 : write_2 = 1;
					2'b11 : write_3 = 1;
				endcase
			end
			`F_SH: begin
				unique case (ram_addr[1:0])
					2'b00 : begin
						write_0 = 1;
						write_1 = 1;
					end
					2'b01 : begin 
						write_1 = 1;
						write_2 = 1;
					end
					2'b10 : begin
						write_2 = 1;
						write_3 = 1;
					end
					2'b11 : begin
						write_3 = 1;
						write_0 = 1;
					end
				endcase
			end
			`F_SW: begin
				write_0 = 1;
				write_1 = 1;
				write_2 = 1;
				write_3 = 1;
			end
		endcase
	end
	
	logic write_ram_0;
	logic write_ram_1;
	logic write_ram_2;
	logic write_ram_3;
	assign write_ram_0 = write_0 & write_read_r;
	assign write_ram_1 = write_1 & write_read_r;
	assign write_ram_2 = write_2 & write_read_r;
	assign write_ram_3 = write_3 & write_read_r;
	
	//WDATA_MUX
	logic [7:0] write_data_0;
	logic [7:0] write_data_1;
	logic [7:0] write_data_2;
	logic [7:0] write_data_3;
	
	always_comb begin
		unique case (ram_addr[1:0])
			2'b00: begin
				write_data_0 = rs2_value_r[7:0];
				write_data_1 = rs2_value_r[15:8];
				write_data_2 = rs2_value_r[23:16];
				write_data_3 = rs2_value_r[31:24];
			end
			2'b01: begin
				write_data_0 = rs2_value_r[31:24];
				write_data_1 = rs2_value_r[7:0];
				write_data_2 = rs2_value_r[15:8];
				write_data_3 = rs2_value_r[23:16];
			end
			2'b10: begin
				write_data_0 = rs2_value_r[23:16];
				write_data_1 = rs2_value_r[31:24];
				write_data_2 = rs2_value_r[7:0];
				write_data_3 = rs2_value_r[15:8];
			end
			2'b11: begin
				write_data_0 = rs2_value_r[15:8];
				write_data_1 = rs2_value_r[23:16];
				write_data_2 = rs2_value_r[31:24];
				write_data_3 = rs2_value_r[7:0];
			end
		endcase
	end
	
	//RAM
	logic [7:0] read_data_0;
	logic [7:0] read_data_1;
	logic [7:0] read_data_2;
	logic [7:0] read_data_3;
	
	RAM ram_0(
			.clk        (clk),
			.write_read (write_ram_0),
			.rs2_value_r (write_data_0),
			.ram_addr	(ram_addr_0),
			.read_data  (read_data_0)
	);
	 
	RAM ram_1(
			.clk        (clk),
			.write_read (write_ram_1),
			.rs2_value_r (write_data_1),
			.ram_addr	(ram_addr_1),
			.read_data  (read_data_1)
	);
	 
	RAM ram_2(
			.clk        (clk),
			.write_read (write_ram_2),
			.rs2_value_r (write_data_2),
			.ram_addr	(ram_addr_2),
			.read_data  (read_data_2)
	);
	 
	RAM ram_3(
			.clk        (clk),
			.write_read (write_ram_3),
			.rs2_value_r (write_data_3),
			.ram_addr	(ram_addr_3),
			.read_data  (read_data_3)
	);
	
	//RDATA_MUX
	logic [31:0] read_data;
	
	always_comb begin
		unique case (funct3_r)
			`F_LB: begin
				unique case(ram_addr[1:0])
					2'b00: read_data = {{24{read_data_0[7]}}, read_data_0};
					2'b01: read_data = {{24{read_data_1[7]}}, read_data_1};
					2'b10: read_data = {{24{read_data_2[7]}}, read_data_2};
					2'b11: read_data = {{24{read_data_3[7]}}, read_data_3};
				endcase
			end
			`F_LH: begin
				unique case(ram_addr[1:0])
					2'b00: read_data = {{16{read_data_1[7]}}, read_data_1, read_data_0};
					2'b01: read_data = {{16{read_data_2[7]}}, read_data_2, read_data_1};
					2'b10: read_data = {{16{read_data_3[7]}}, read_data_3, read_data_2};
					2'b11: read_data = {{16{read_data_0[7]}}, read_data_0, read_data_3};
				endcase
			end
			`F_LW: begin
				unique case(ram_addr[1:0])
					2'b00: read_data = {read_data_3, read_data_2, read_data_1, read_data_0};
					2'b01: read_data = {read_data_0, read_data_3, read_data_2, read_data_1};
					2'b10: read_data = {read_data_1, read_data_0, read_data_3, read_data_2};
					2'b11: read_data = {read_data_2, read_data_1, read_data_0, read_data_3};
				endcase
			end
			`F_LBU: begin
				unique case(ram_addr[1:0])
					2'b00: read_data = {24'h0, read_data_0};
					2'b01: read_data = {24'h0, read_data_1};
					2'b10: read_data = {24'h0, read_data_2};
					2'b11: read_data = {24'h0, read_data_3};
				endcase
			end
			`F_LHU: begin
				unique case(ram_addr[1:0])
					2'b00: read_data = {16'h0, read_data_1, read_data_0};
					2'b01: read_data = {16'h0, read_data_2, read_data_1};
					2'b10: read_data = {16'h0, read_data_3, read_data_2};
					2'b11: read_data = {16'h0, read_data_0, read_data_3};
				endcase
			end
		endcase	
	end
	
	//MUL
	logic [31:0] rs1_value_twos_comp;
	logic [31:0] rs2_value_twos_comp;
	logic [31:0] abs_rs1_value;
	logic [31:0] abs_rs2_value;
	logic [63:0] product;
	logic [63:0] product_twos_comp;
	logic sel_abs_rs1_value;
	logic sel_abs_rs2_value;
	logic sign;
	logic [31:0] mul_out;
	
	assign sign = rs1_value_r[31] ^ rs2_value_r[31];
	assign rs1_value_twos_comp = ~rs1_value_r + 1;
	assign rs2_value_twos_comp = ~rs2_value_r + 1;
		
	assign abs_rs1_value = sel_abs_rs1_value ? rs1_value_twos_comp : rs1_value_r;
	assign abs_rs2_value = sel_abs_rs2_value ? rs2_value_twos_comp : rs2_value_r;
	
	assign product = abs_rs1_value * abs_rs2_value;
	
	assign product_twos_comp = ~product + 1;
	
	always_comb begin
		unique case(funct3_r)
			`F_MUL:begin
				sel_abs_rs1_value = rs1_value_r[31];
				sel_abs_rs2_value = rs2_value_r[31];
				
				mul_out = sign ? product_twos_comp[31:0] : product[31:0];
			end
			`F_MULH:begin
				sel_abs_rs1_value = rs1_value_r[31];
				sel_abs_rs2_value = rs2_value_r[31];
				
				mul_out = sign ? product_twos_comp[63:32] : product[63:32];
			end
			`F_MULHSU:begin
				sel_abs_rs1_value = rs1_value_r[31];
				sel_abs_rs2_value = 0;
				
				mul_out = rs1_value_r[31] ? product_twos_comp[63:32] : product[63:32];
			end
			`F_MULHU:begin
				sel_abs_rs1_value = 0;
				sel_abs_rs2_value = 0;
				
				mul_out = product[63:32];
			end
		endcase
	end

	//DIV
	logic [31:0] div_out;
	always_comb begin
		unique case(funct3_r)
			`F_DIV  :  div_out = $signed(rs1_value_r) / $signed(rs2_value_r);
			`F_DIVU :  div_out = rs1_value_r / rs2_value_r;
			`F_REM  :  div_out = $signed(rs1_value_r) % $signed(rs2_value_r);
			`F_REMU :  div_out = rs1_value_r % rs2_value_r;
		endcase
	end
	
	always_comb begin
		unique case (sel_rd_value_r)
			2'b00 : rd_value_ = alu_out;
			2'b01 : rd_value_ = read_data;
			2'b10 : rd_value_ = mul_out;
			2'b11 : rd_value_ = div_out;
		endcase
	end
	
endmodule
