import serial
import time
import struct
from pathlib import Path


def load_instructions(filename="assembly.txt"):
    asm_path = Path(__file__).resolve().with_name(filename)

    instructions = []

    with open(asm_path, "r", encoding="utf-8") as f:
        for line_no, line in enumerate(f, start=1):
            line = line.strip()

            if not line or line.startswith("#") or line.startswith("//"):
                continue

            parts = line.split()

            if len(parts) < 2:
                continue

            try:
                instr = int(parts[1], 16)
            except ValueError:
                raise ValueError(f"第 {line_no} 行格式錯誤，無法讀取機器碼：{line}")

            instructions.append(instr)

    return instructions


# 從同一個資料夾的 assembly.txt 讀取指令
instructions = load_instructions("assembly.txt")

try:
    ser = serial.Serial('COM4', 115200, timeout=1)
    print("成功連線到 COM Port")

    time.sleep(1)

    for instr in instructions:
        # 小端序送出，符合你目前 UART Bootloader 的格式
        byte_data = struct.pack('<I', instr)
        ser.write(byte_data)
        print(f"Sent: 0x{instr:08X} -> {byte_data.hex()}")
        time.sleep(0.01)

    print(f"全部指令發送完畢，共 {len(instructions)} 筆！")
    ser.close()

except Exception as e:
    print(f"發生錯誤: {e}")