import numpy as np

def main():
    # Load golden
    with open('../fpga/data/conv2_out_golden.hex', 'r') as f:
        golden_lines = f.readlines()
        
    golden_out = []
    for line in golden_lines:
        val = int(line.strip(), 16)
        if val >= 32768:
            val -= 65536
        golden_out.append(val)
        
    print(f"Total golden values: {len(golden_out)}")

if __name__ == '__main__':
    main()
