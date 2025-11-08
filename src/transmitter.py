import argparse, serial, struct, time, random, os, csv

def read_exact(ser, n, timeout):
    """Đọc đúng n byte hoặc ném TimeoutError."""
    ser.timeout = timeout
    out = bytearray()
    while len(out) < n:
        chunk = ser.read(n - len(out))
        if not chunk:
            raise TimeoutError(f"Timeout: chỉ nhận {len(out)}/{n} byte")
        out.extend(chunk)
    return bytes(out)

def send_add(ser, a, b, read_cout=True, timeout=0.5, header=None):
    """
    Gửi 2 số 32-bit (little-endian). Nếu header != None, gửi thêm header (bytes) trước payload.
    Trả về (sum_fpga, cout_fpga_or_None, latency_seconds).
    """
    if header:
        ser.reset_input_buffer()
        ser.write(header)
    else:
        ser.reset_input_buffer()

    pkt = struct.pack("<II", a & 0xFFFFFFFF, b & 0xFFFFFFFF)

    t0 = time.perf_counter()
    ser.write(pkt)

    sum_raw = read_exact(ser, 4, timeout)
    cout_val = None
    if read_cout:
        try:
            extra = read_exact(ser, 1, timeout)
            cout_val = extra[0]
        except TimeoutError:
            # Không có cout (chỉ 4 byte sum) -> giữ None
            pass
    t1 = time.perf_counter()
    return int.from_bytes(sum_raw, "little"), cout_val, (t1 - t0)

def parse_directed(arg_tokens):
    """--directed a:b  (hex/dec đều được)"""
    pairs = []
    for tok in (arg_tokens or []):
        if ":" not in tok:
            raise argparse.ArgumentTypeError(f"Thiếu dấu ':' trong --directed token: {tok}")
        a_s, b_s = tok.split(":", 1)
        a = int(a_s, 0) & 0xFFFFFFFF
        b = int(b_s, 0) & 0xFFFFFFFF
        pairs.append((a, b))
    return pairs

def gen_unique(num, mode="pair"):
    """
    mode='pair'  : không trùng tổ hợp (a,b)
    mode='a'     : mỗi a duy nhất, b ngẫu nhiên
    mode='b'     : mỗi b duy nhất, a ngẫu nhiên
    """
    if mode == "pair":
        s = set()
        while len(s) < num:
            s.add((random.getrandbits(32), random.getrandbits(32)))
        return list(s)

    elif mode == "a":
        # sinh tập a không trùng, mỗi a ghép b ngẫu nhiên
        a_set = set()
        while len(a_set) < num:
            a_set.add(random.getrandbits(32))
        return [(a, random.getrandbits(32)) for a in a_set]

    elif mode == "b":
        b_set = set()
        while len(b_set) < num:
            b_set.add(random.getrandbits(32))
        return [(random.getrandbits(32), b) for b in b_set]

    else:
        raise ValueError("unique-mode phải là pair|a|b")

def main():
    ap = argparse.ArgumentParser(description="UART 32-bit adder tester (sum [+cout]) với random không trùng & ghi CSV.")
    ap.add_argument("--port", default="COM7", help="Cổng serial (COM7 / /dev/ttyUSB0)")
    ap.add_argument("--baud", type=int, default=115200, help="Baud rate (mặc định 115200)")
    ap.add_argument("-n", "--num", type=int, default=1000, help="Số lượng random test")
    ap.add_argument("--seed", type=int, default=None, help="Seed cho random (tái lập)")
    ap.add_argument("--out", default="results.csv", help="File CSV output")
    ap.add_argument("--append", action="store_true", help="Ghi nối tiếp (không xoá file cũ)")
    ap.add_argument("--timeout", type=float, default=0.5, help="Timeout đọc (giây)")
    ap.add_argument("--no-cout", action="store_true", help="Không cố đọc cout (chỉ 4 byte sum)")
    ap.add_argument("--directed", nargs="*", default=[], help="Danh sách cặp 'a:b' (hex/dec), vd: 0xFFFFFFFF:0x1")
    ap.add_argument("--unique-mode", choices=["pair","a","b"], default="pair",
                    help="Ràng buộc không trùng: theo cặp (mặc định), chỉ a, hoặc chỉ b")
    ap.add_argument("--header", default="", help="Header hex để gửi trước payload (vd: AA55). Để trống nếu FPGA KHÔNG hỗ trợ")
    args = ap.parse_args()

    if args.seed is not None:
        random.seed(args.seed)

    directed_pairs = parse_directed(args.directed)
    random_pairs   = gen_unique(args.num, mode=args.unique_mode)

    header_bytes = bytes.fromhex(args.header) if args.header else None
    read_cout = not args.no_cout

    mode = "a" if args.append and os.path.exists(args.out) else "w"
    header_row = ["test_type","a_hex","b_hex","sum_fpga_hex","cout_fpga",
                  "sum_gold_hex","cout_gold","pass","latency_ms","seed"]

    with serial.Serial(args.port, args.baud, timeout=args.timeout) as ser, \
         open(args.out, mode, newline="") as f:
        wr = csv.writer(f)
        if mode == "w":
            wr.writerow(header_row)

        time.sleep(0.1)

        # 1) Directed
        for (a,b) in directed_pairs:
            sum_fpga, cout_fpga, lat = send_add(ser, a, b, read_cout=read_cout, timeout=args.timeout, header=header_bytes)
            sum_gold = (a + b) & 0xFFFFFFFF
            cout_gold = 1 if (a + b) >> 32 else 0
            passed = (sum_fpga == sum_gold) and (cout_fpga in (None, cout_gold))
            wr.writerow(["DIR", f"0x{a:08X}", f"0x{b:08X}", f"0x{sum_fpga:08X}",
                         ("" if cout_fpga is None else cout_fpga),
                         f"0x{sum_gold:08X}", cout_gold, int(passed),
                         f"{lat*1000:.3f}", ("" if args.seed is None else args.seed)])
            print(f"[DIR] a=0x{a:08X} b=0x{b:08X} -> sum=0x{sum_fpga:08X} "
                  f"cout={cout_fpga if cout_fpga is not None else '(no cout)'} "
                  f"(gold=0x{sum_gold:08X}, cout_gold={cout_gold}) pass={passed} "
                  f"lat={lat*1000:.2f} ms")

        # 2) Random (unique theo mode)
        for (a,b) in random_pairs:
            sum_fpga, cout_fpga, lat = send_add(ser, a, b, read_cout=read_cout, timeout=args.timeout, header=header_bytes)
            sum_gold = (a + b) & 0xFFFFFFFF
            cout_gold = 1 if (a + b) >> 32 else 0
            passed = (sum_fpga == sum_gold) and (cout_fpga in (None, cout_gold))
            wr.writerow(["RND", f"0x{a:08X}", f"0x{b:08X}", f"0x{sum_fpga:08X}",
                         ("" if cout_fpga is None else cout_fpga),
                         f"0x{sum_gold:08X}", cout_gold, int(passed),
                         f"{lat*1000:.3f}", ("" if args.seed is None else args.seed)])
            print(f"[RND] a=0x{a:08X} b=0x{b:08X} -> sum=0x{sum_fpga:08X} "
                  f"cout={cout_fpga if cout_fpga is not None else '(no cout)'} "
                  f"(gold=0x{sum_gold:08X}, cout_gold={cout_gold}) pass={passed} "
                  f"lat={lat*1000:.2f} ms")

    print(f"\n✔ Ghi xong {len(directed_pairs)} DIR + {len(random_pairs)} RND vào {args.out}")

if __name__ == "__main__":
    main()
