import torch
import torchvision.transforms as transforms
import torchvision.datasets as datasets
from main import Net
import os
import numpy as np

def to_q8_8(x):
    # Quantize float to 16-bit signed Q8.8
    v = np.round(x * 256.0).astype(np.int32)
    return np.clip(v, -32768, 32767)

def hex_16(v):
    return f"{int(v) & 0xFFFF:04X}\n"

def main():
    model = Net()
    model.load_state_dict(torch.load("mnist_cnn.pt", map_location="cpu", weights_only=True))
    model.eval()

    # Load 5 test images
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])
    dataset = datasets.MNIST('../data', train=False, transform=transform)
    
    data_dir = '../fpga/data'
    os.makedirs(data_dir, exist_ok=True)

    # 1. Export Weights
    w1 = to_q8_8(model.conv1.weight.detach().numpy())
    b1 = to_q8_8(model.conv1.bias.detach().numpy())
    with open(os.path.join(data_dir, 'conv1_w.hex'), 'w') as f:
        for oc in range(32):
            for r in range(3):
                for c in range(3):
                    f.write(hex_16(w1[oc, 0, r, c]))
    with open(os.path.join(data_dir, 'conv1_b.hex'), 'w') as f:
        for oc in range(32): f.write(hex_16(b1[oc]))

    w2 = to_q8_8(model.conv2.weight.detach().numpy())
    b2 = to_q8_8(model.conv2.bias.detach().numpy())
    with open(os.path.join(data_dir, 'conv2_w.hex'), 'w') as f:
        for oc in range(64):
            for ic in range(32):
                for r in range(3):
                    for c in range(3):
                        f.write(hex_16(w2[oc, ic, r, c]))
    with open(os.path.join(data_dir, 'conv2_b.hex'), 'w') as f:
        for oc in range(64): f.write(hex_16(b2[oc]))

    # FC1 - 1024 inputs (64 channels * 4 * 4)
    w_fc1 = to_q8_8(model.fc1.weight.detach().numpy()) # (128, 1024)
    b_fc1 = to_q8_8(model.fc1.bias.detach().numpy())
    with open(os.path.join(data_dir, 'fc1_w.hex'), 'w') as f:
        for oc in range(128):
            # Model weight for 128 nodes, each having 1024 inputs.
            # 1024 inputs represent 64 channels, 4x4 spatial.
            # PyTorch flatten is C, H, W.
            # Reorder to H, W, C for hardware stream.
            w_reshaped = w_fc1[oc].reshape(64, 4, 4)
            w_hw = w_reshaped.transpose(1, 2, 0).flatten()
            for val in w_hw:
                f.write(hex_16(val))
    with open(os.path.join(data_dir, 'fc1_b.hex'), 'w') as f:
        for oc in range(128): f.write(hex_16(b_fc1[oc]))

    # FC2
    w_fc2 = to_q8_8(model.fc2.weight.detach().numpy())
    b_fc2 = to_q8_8(model.fc2.bias.detach().numpy())
    with open(os.path.join(data_dir, 'fc2_w.hex'), 'w') as f:
        for oc in range(10):
            for ic in range(128):
                f.write(hex_16(w_fc2[oc, ic]))
    with open(os.path.join(data_dir, 'fc2_b.hex'), 'w') as f:
        for oc in range(10): f.write(hex_16(b_fc2[oc]))

    # 2. Export 5 Test Images and their Golden Results
    print("Exporting multi-image test data (99% version)...")
    for img_idx in range(5):
        img, label = dataset[img_idx]
        img_q = to_q8_8(img[0].numpy())
        
        with open(os.path.join(data_dir, f'image_{img_idx}.hex'), 'w') as f:
            for r in range(28):
                for c in range(28):
                    f.write(hex_16(img_q[r, c]))
        
        # RTL-Equivalent Inference
        # C1
        c1_out = np.zeros((32, 26, 26), dtype=np.int32)
        for oc in range(32):
            for r in range(26):
                for c in range(26):
                    acc = int(b1[oc]) << 8
                    for kr in range(3):
                        for kc in range(3):
                            acc += int(img_q[r+kr, c+kc]) * int(w1[oc, 0, kr, kc])
                    c1_out[oc, r, c] = np.clip(acc >> 8, -32768, 32767)
        c1_relu = np.maximum(c1_out, 0)

        # C2
        c2_out = np.zeros((64, 24, 24), dtype=np.int32)
        for oc in range(64):
            for r in range(24):
                for c in range(24):
                    acc = int(b2[oc]) << 8
                    for ic in range(32):
                        for kr in range(3):
                            for kc in range(3):
                                acc += int(c1_relu[ic, r+kr, c+kc]) * int(w2[oc, ic, kr, kc])
                    c2_out[oc, r, c] = np.clip(acc >> 8, -32768, 32767)
        c2_relu = np.maximum(c2_out, 0)

        # Maxpool (2x2 -> 12x12)
        mp_out = np.zeros((64, 12, 12), dtype=np.int32)
        for oc in range(64):
            for r in range(12):
                for c in range(12):
                    mp_out[oc, r, c] = np.max(c2_relu[oc, r*2:r*2+2, c*2:c*2+2])
        
        # New: 3x3 Avg Pool (12x12 -> 4x4)
        gap_out = np.zeros((64, 4, 4), dtype=np.int32)
        for oc in range(64):
            for r in range(4):
                for c in range(4):
                    s = np.sum(mp_out[oc, r*3:r*3+3, c*3:c*3+3])
                    gap_out[oc, r, c] = s // 9

        # FC1 (NHWC stream: 4x4x64 = 1024 inputs)
        flat_input = gap_out.transpose(1, 2, 0).flatten() 
        f1_out = np.zeros(128, dtype=np.int32)
        for oc in range(128):
            w_fc1_hw = w_fc1[oc].reshape(64, 4, 4).transpose(1, 2, 0).flatten()
            acc = int(b_fc1[oc]) << 8
            for ic in range(1024):
                acc += int(flat_input[ic]) * int(w_fc1_hw[ic])
            f1_out[oc] = np.clip(acc >> 8, -32768, 32767)
        f1_relu = np.maximum(f1_out, 0)

        # FC2
        f2_out = np.zeros(10, dtype=np.int32)
        for oc in range(10):
            acc = int(b_fc2[oc]) << 8
            for ic in range(128):
                acc += int(f1_relu[ic]) * int(w_fc2[oc, ic])
            f2_out[oc] = np.clip(acc >> 8, -32768, 32767)
        
        with open(os.path.join(data_dir, f'golden_{img_idx}.hex'), 'w') as f:
            for v in f2_out: f.write(hex_16(v))
        
        print(f"Img {img_idx} (Label {label}): Predicted {np.argmax(f2_out)}")

    print("99% Accuracy data exported successfully!")

if __name__ == '__main__':
    main()
