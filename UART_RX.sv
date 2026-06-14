module UART_RX #(
    parameter CLK_FREQ  = 50_000_000, // DE2-115 預設時脈 50MHz
    parameter BAUD_RATE = 115200      // 傳輸速率
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,        // UART 接收腳位
    output logic [7:0] rx_data,   // 接收到的 8-bit 資料
    output logic       rx_ready   // 接收完成的一個 clock 週期脈衝
);

    // 計算一個 bit 需要多少個 clock cycle
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    // 狀態機定義
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        START = 2'b01,
        DATA  = 2'b10,
        STOP  = 2'b11
    } state_t;
    
    state_t state, next_state;
    
    logic [15:0] clk_cnt;
    logic [2:0]  bit_cnt;
    logic [7:0]  shift_reg;

    // 狀態切換 (Sequential Logic)
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= IDLE;
            clk_cnt  <= 16'd0;
            bit_cnt  <= 3'd0;
            rx_data  <= 8'd0;
            rx_ready <= 1'b0;
        end else begin
            state    <= next_state;
            rx_ready <= 1'b0; // 預設拉低，只有在 STOP 狀態結束時拉高 1 個 cycle
            
            case (state)
                IDLE: begin
                    clk_cnt <= 16'd0;
                    bit_cnt <= 3'd0;
                end
                
                START: begin
                    // 數到半個 bit 的時間，取樣確認 start bit (0) 是否穩定
                    if (clk_cnt == CLKS_PER_BIT/2 - 1) begin
                        clk_cnt <= 16'd0;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
                
                DATA: begin
                    // 每個 bit 週期取樣一次資料
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 16'd0;
                        shift_reg[bit_cnt] <= rx; // 依序將 bit 存入暫存器
                        bit_cnt <= bit_cnt + 1'b1;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
                
                STOP: begin
                    // 數滿一個 bit 的時間，準備結束
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt  <= 16'd0;
                        rx_data  <= shift_reg; // 將收集好的 8 bit 輸出
                        rx_ready <= 1'b1;      // 觸發 rx_ready
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
            endcase
        end
    end
    
    // 下一個狀態邏輯 (Combinational Logic)
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (rx == 1'b0) // 偵測到 Start Bit (拉低)
                    next_state = START;
            end
            START: begin
                if (clk_cnt == CLKS_PER_BIT/2 - 1) begin
                    if (rx == 1'b0) // 確認還是 0，進入資料接收
                        next_state = DATA;
                    else
                        next_state = IDLE; // 雜訊干擾，退回 IDLE
                end
            end
            DATA: begin
                if (clk_cnt == CLKS_PER_BIT - 1 && bit_cnt == 3'd7)
                    next_state = STOP; // 8 個 bit 都收完了
            end
            STOP: begin
                if (clk_cnt == CLKS_PER_BIT - 1)
                    next_state = IDLE; // 回到 IDLE 等待下一個 byte
            end
            default: next_state = IDLE;
        endcase
    end
endmodule