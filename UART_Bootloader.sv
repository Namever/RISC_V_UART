module UART_Bootloader (
    input  logic        clk,
    input  logic        rst,
    
    // 與 UART RX 模組的介面
    input  logic        rx_ready,  
    input  logic [7:0]  rx_data,   
    
    // 與 Instruction RAM 的介面
    output logic        ram_we,
    output logic [31:0] ram_addr,
    output logic [31:0] ram_wdata
);
    logic [1:0] byte_cnt;
    logic [31:0] buffer;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            byte_cnt <= 2'd0;
            ram_addr <= 32'd0;
            ram_we   <= 1'b0;
            buffer   <= 32'd0;
            ram_wdata<= 32'd0;
        end else begin
            ram_we <= 1'b0; // 預設不寫入
            
            // ✅ 修正：當前一個 cycle 觸發了寫入，這個 cycle 再把位址加 4
            if (ram_we) begin
                ram_addr <= ram_addr + 4;
            end
            
            if (rx_ready) begin
                // Little-Endian 拼裝法：新來的 byte 放高位，舊的往右推
                buffer <= {rx_data, buffer[31:8]};
                byte_cnt <= byte_cnt + 1'b1;
                
                // 收滿 4 個 bytes 了
                if (byte_cnt == 2'd3) begin
                    ram_wdata <= {rx_data, buffer[31:8]};
                    ram_we    <= 1'b1;        // 觸發寫入
                    // (移除原本這裡的 ram_addr <= ram_addr + 4)
                end
            end
        end
    end
endmodule