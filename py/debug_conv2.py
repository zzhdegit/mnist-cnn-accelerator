import numpy as np

def main():
    # Load relu out
    with open('../fpga/data/conv1_relu_golden.hex', 'r') as f:
        relu_lines = f.readlines()
        
    relu_out = np.zeros((32, 26, 26), dtype=np.int32)
    idx = 0
    for row in range(26):
        for col in range(26):
            for oc in range(32):
                val = int(relu_lines[idx].strip(), 16)
                if val >= 32768:
                    val -= 65536
                relu_out[oc, row, col] = val
                idx += 1
                
    # Load weights
    with open('../fpga/data/conv2_w.hex', 'r') as f:
        w_lines = f.readlines()
        
    w_q2 = np.zeros((64, 32, 3, 3), dtype=np.int32)
    idx = 0
    for oc in range(64):
        for ic in range(32):
            for r in range(3):
                for c in range(3):
                    val = int(w_lines[idx].strip(), 16)
                    if val >= 32768:
                        val -= 65536
                    w_q2[oc, ic, r, c] = val
                    idx += 1
                    
    # Load bias
    with open('../fpga/data/conv2_b.hex', 'r') as f:
        b_lines = f.readlines()
    b_q2 = np.zeros((64,), dtype=np.int32)
    for oc in range(64):
        val = int(b_lines[oc].strip(), 16)
        if val >= 32768:
            val -= 65536
        b_q2[oc] = val

    # Test pixel 73: row=3, col=1, oc=0
    row = 3
    col = 1
    oc = 0
    
    acc = 0
    for ic in range(32):
        for r in range(3):
            for c in range(3):
                acc += int(relu_out[ic, row+r, col+c]) * int(w_q2[oc, ic, r, c])
                
    acc += int(b_q2[oc]) * 256
    out_val = acc >> 8
    
    print(f"Python Debug:")
    print(f"acc = {acc}")
    print(f"out_val = {out_val}")
    print(f"Hex out_val = {out_val & 0xFFFF:04X}")

if __name__ == '__main__':
    main()
