//======================
// Top Module (已加入個人化安全鎖機制)
//======================
module Top(
	 input logic clk,
	 input logic clk_50M,
	 input logic rst,
	 input logic [17:0] SW,
	 input logic        UART_RXD,
	 output logic [31:0] regs_31,
	 output logic [31:0] pc
);
    logic rst_pc_;
    logic flush_IFID_, flush_IDEX_,sel_pc_,sel_pc_r,flush_IDEX_r,flush_IFID_r;

    logic [31:0] inst, inst_r, pc_r,pc_rr;
    logic [6:0]  opcode_, funct7_;
    logic [2:0]  funct3_,funct3_r;
    logic [4:0]  addr_rd_, addr_rs1_, addr_rs2_, addr_rd_r;
    logic [31:0] imm_, imm_r,alu_a,alu_b,alu_out,jump_addr_;
    logic [31:0] rs1_value_, rs2_value_, rd_value_, rs1_value_r, rs2_value_r;
    logic        write_regf_en, write_regf_en_r,sel_jump_,sel_jump_r,sel_alu_a_,sel_alu_a_r;
	logic [1:0]  sel_alu_b_,sel_alu_b_r,sel_rd_value_,sel_rd_value_r;
	logic [3:0]  op,op_r;
	logic        write_read_,write_read_r;
	logic [31:0] ram_addr;
	
	logic prog_mode;
    assign prog_mode = SW[17]; // 用 SW[17] 決定目前是燒錄還是執行

    // 系統 Reset 邏輯：按下重置鈕，或者處於「燒錄模式」時，CPU 都要被 Reset
    logic cpu_rst;
    
    // 💡 【核心改動 1/2】：宣告安全鎖暫存器
    logic rx_has_data;
    always_ff @(posedge clk_50M or posedge rst) begin
        if (rst) begin
            rx_has_data <= 1'b0;
        end else if (prog_mode) begin
            if (boot_we) begin
                rx_has_data <= 1'b1; // 只要 Bootloader 成功寫入過任何 1 byte，就永久解鎖
            end
        end
    end

    // 💡 【核心改動 2/2】：重新定義 CPU Reset 條件
    // 只有當「不在燒錄模式 (prog_mode=0)」且「確定有收到資料 (rx_has_data=1)」時，CPU 才會動！
    assign cpu_rst = rst | prog_mode | ~rx_has_data; 

    // UART RX 內部訊號
    logic       rx_ready;
    logic [7:0] rx_data;

    // Bootloader 內部訊號
    logic        boot_we;
    logic [31:0] boot_addr;
    logic [31:0] boot_wdata;
	 
	 UART_RX u_uart_rx (
        .clk      (clk_50M),
        .rst      (rst),
        .rx       (UART_RXD),
        .rx_data  (rx_data),
        .rx_ready (rx_ready)
    );

    // 實體化 Bootloader
    UART_Bootloader u_bootloader (
        .clk       (clk_50M),
        .rst       (rst | ~prog_mode), // 離開燒錄模式時，Bootloader 位址歸零
        .rx_ready  (rx_ready),
        .rx_data   (rx_data),
        .ram_we    (boot_we),
        .ram_addr  (boot_addr),
        .ram_wdata (boot_wdata)
    );

    // 實體化 Instruction RAM
    Instruction_RAM u_iram (
        .clk    (clk_50M),
        .we_a   (boot_we & prog_mode), 
        .addr_a (boot_addr),
        .din_a  (boot_wdata),
        .addr_b (pc),
        .dout_b (inst)
    );

    Program_Counter u_pc (
        .clk    	(clk),
        .rst   	(cpu_rst),
        .rst_pc 	(rst_pc_),
        .pc     	(pc),
		.jump_addr_ (jump_addr_),
		.sel_pc_r   (sel_pc_r)
    );
	 
    IF_ID u_ifid (
        .clk        (clk),
        .rst        (cpu_rst),
        .flush_IFID_r(flush_IFID_r),
        .inst       (inst),
        .pc         (pc),
        .inst_r     (inst_r),
        .pc_r       (pc_r)
    );

    INST_DEC u_dec (
        .inst_r     (inst_r),
        .opcode_    (opcode_),
        .funct3_    (funct3_),
        .funct7_    (funct7_),
        .addr_rd_   (addr_rd_),
        .addr_rs1_  (addr_rs1_),
        .addr_rs2_  (addr_rs2_),
        .imm_       (imm_)
    );

    CONTROLLER u_ctrl (
        .clk            (clk),
        .rst            (cpu_rst),
        .opcode_        (opcode_),
        .flush_IFID_    (flush_IFID_),
        .flush_IDEX_    (flush_IDEX_),
        .rst_pc_        (rst_pc_),
        .write_regf_en  (write_regf_en),
		.funct3_    	(funct3_),
        .funct7_   	    (funct7_),
		.rs1_value_     (rs1_value_),
        .rs2_value_     (rs2_value_),
		.op             (op),
		.sel_jump_      (sel_jump_),
		.sel_alu_a_     (sel_alu_a_),
		.sel_alu_b_     (sel_alu_b_),
		.sel_pc_        (sel_pc_),
		.sel_rd_value_  (sel_rd_value_),
		.write_read_    (write_read_)
    );

    REG_FILE u_reg (
        .clk            (clk),
        .rst            (cpu_rst),
		.write_regf_en_r(write_regf_en_r),
        .addr_rd_r      (addr_rd_r),
        .addr_rs1       (addr_rs1_),
        .addr_rs2       (addr_rs2_),
        .rd_value_      (rd_value_),
        .rs1_value_     (rs1_value_),
        .rs2_value_     (rs2_value_),
		.regs_31        (regs_31) 
    );

    ID_EX u_idex (
        .clk            (clk),
        .rst            (cpu_rst),
        .flush_IDEX_    (flush_IDEX_),
		.flush_IFID_    (flush_IFID_),
		.flush_IDEX_r	(flush_IDEX_r),
		.flush_IFID_r	(flush_IFID_r),
		.sel_pc_		(sel_pc_),
		.sel_pc_r		(sel_pc_r),
        .write_regf_en  (write_regf_en),
        .imm            (imm_),
        .rs1_value_     (rs1_value_),
        .rs2_value_     (rs2_value_),
        .addr_rd        (addr_rd_),
        .imm_r          (imm_r),
        .rs1_value_r    (rs1_value_r),
        .rs2_value_r    (rs2_value_r),
        .addr_rd_r      (addr_rd_r),
        .write_regf_en_r(write_regf_en_r),
		.op             (op),
		.op_r           (op_r),
		.sel_jump_		(sel_jump_),
		.sel_jump_r		(sel_jump_r),
		.sel_alu_a_		(sel_alu_a_),
		.sel_alu_a_r	(sel_alu_a_r),
		.sel_alu_b_     (sel_alu_b_),
	    .sel_alu_b_r    (sel_alu_b_r),
		.pc_r           (pc_r),
		.pc_rr          (pc_rr),
		.jump_addr_     (jump_addr_),
		.funct3_        (funct3_),
		.funct3_r		(funct3_r),
		.sel_rd_value_  (sel_rd_value_),
		.sel_rd_value_r (sel_rd_value_r),
		.write_read_    (write_read_),
		.write_read_r   (write_read_r)
    );

    ALU u_alu (
			.rs1_value_r    (rs1_value_r),
			.rs2_value_r    (rs2_value_r),
			.imm_r          (imm_r),
			.alu_out		(alu_out),
			.op_r           (op_r),
			.sel_alu_a_r	(sel_alu_a_r),
			.sel_alu_b_r    (sel_alu_b_r),
			.pc_rr			(pc_rr)
	 );

    LSU u_lsu (
			.clk            (clk),
			.funct3_r       (funct3_r),
			.rs1_value_r    (rs1_value_r),
			.rs2_value_r    (rs2_value_r), 
			.write_read_r   (write_read_r),
			.alu_out	    (alu_out),
			.sel_rd_value_r (sel_rd_value_r),
			.rd_value_      (rd_value_)
	);
endmodule