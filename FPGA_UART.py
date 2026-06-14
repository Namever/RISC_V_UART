import serial
import time
import struct

# 將你的 ROM 指令寫在這裡 (對應你原本的 Program_Rom)

instructions = [
    0xFE010113,    # addi x2 x2 -32
    0x00112E23,    # sw x1 28(x2)
    0x00812C23,    # sw x8 24(x2)
    0x02010413,    # addi x8 x2 32
    0x00100793,    # addi x15 x0 1
    0xFEF42623,    # sw x15 -20(x8)
    0x00100793,    # addi x15 x0 1
    0xFEF42423,    # sw x15 -24(x8)
    0x00100793,    # addi x15 x0 1
    0xFEF42623,    # sw x15 -20(x8)
    0x0440006F,    # jal x0 68
    0x00100793,    # addi x15 x0 1
    0xFEF42423,    # sw x15 -24(x8)
    0x0200006F,    # jal x0 32
    0xFEC42703,    # lw x14 -20(x8)
    0xFE842783,    # lw x15 -24(x8)
    0x02F707B3,    # mul x15 x14 x15
    0x00078F93,    # addi x31 x15 0
    0xFE842783,    # lw x15 -24(x8)
    0x00178793,    # addi x15 x15 1
    0xFEF42423,    # sw x15 -24(x8)
    0xFE842703,    # lw x14 -24(x8)
    0x00A00793,    # addi x15 x0 10
    0xFCE7DEE3,    # bge x15 x14 -36
    0xFEC42783,    # lw x15 -20(x8)
    0x00178793,    # addi x15 x15 1
    0xFEF42623,    # sw x15 -20(x8)
    0xFEC42703,    # lw x14 -20(x8)
    0x00A00793,    # addi x15 x0 10
    0xFAE7DCE3,    # bge x15 x14 -72
    0xF99FF06F,    # jal x0 -104
]

# 請將 'COM3' 換成你 DE2-115 接上電腦後顯示的 COM Port
# Baud rate 必須跟 Verilog 設定的 115200 一致
try:
    ser = serial.Serial('COM4', 115200, timeout=1)
    print("成功連線到 COM Port")
    
    # 提醒：發送前請確保 DE2-115 上的指撥開關已經切換到「燒錄模式」
    time.sleep(1) 
    
    for instr in instructions:
        # 轉換成 4 個 bytes (小端序 '<I')
        byte_data = struct.pack('<I', instr) 
        ser.write(byte_data)
        print(f"Sent: 0x{instr:08X} -> {byte_data.hex()}")
        time.sleep(0.01) # 給 FPGA 一點緩衝時間
        
    print("全部指令發送完畢！")
    ser.close()

except Exception as e:
    print(f"發生錯誤: {e}")