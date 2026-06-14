module Instruction_RAM (
    input  logic        clk,
    // Port A: UART Bootloader (寫入專用)
    input  logic        we_a,
    input  logic [31:0] addr_a,
    input  logic [31:0] din_a,
    
    // Port B: RISC-V PC (讀取專用)
    input  logic [31:0] addr_b,
    output logic [31:0] dout_b
);
    // 建立 1024 x 32-bit 的記憶體 (容量為 4KB，可依需求調整)
    logic [31:0] ram [0:1023];

    // Port A: 寫入邏輯 (同步)
    always_ff @(posedge clk) begin
        if (we_a) begin
            // 由於 RISC-V PC 通常是 +4，我們忽略位址的最低 2 bit (addr_a[11:2])
            ram[addr_a[11:2]] <= din_a;
        end
    end

    // Port B: 讀取邏輯 (非同步讀取，配合你原本的 Combinational ROM 架構)
    assign dout_b = ram[addr_b[11:2]];

endmodule