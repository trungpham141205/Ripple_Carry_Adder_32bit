import serial, time

PORT = "COM7"        # đổi sang cổng của bạn (/dev/ttyUSB0 trên Linux)
BAUD = 115200

with serial.Serial(PORT, BAUD, timeout=1) as ser:
    time.sleep(0.1)  # chờ ổn định
    for b in [0x82, 0x55, 0xA5, 0xFF, 0x65, 0x43, 0xf8, 0xc4]:
        ser.reset_input_buffer()
        ser.write(bytes([b]))
        rx = ser.read(1)
        print(f"TX 0x{b:02X}  ->  RX {rx.hex() if rx else 'timeout'}")