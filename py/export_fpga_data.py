import os
import argparse
import numpy as np
import torch
import torchvision.transforms as transforms
import torchvision.datasets as datasets
from main import Net


def to_q8_8(x):
    v = np.round(x * 256.0).astype(np.int32)
    return np.clip(v, -32768, 32767)


def hex_16(v):
    return f"{int(v) & 0xFFFF:04X}\n"


def main():
    parser = argparse.ArgumentParser(description="Export quantized FPGA MNIST data and golden outputs.")
    parser.add_argument("--num-images", type=int, default=30, help="number of test images to export")
    parser.add_argument("--model", default="../mnist_cnn.pt", help="path to trained PyTorch state_dict")
    parser.add_argument("--data-dir", default=None, help="output directory for FPGA hex files")
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    model_path = args.model
    if not os.path.isabs(model_path):
        model_path = os.path.join(script_dir, model_path)

    model = Net()
    model.load_state_dict(torch.load(model_path, map_location="cpu", weights_only=True))
    model.eval()

    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])
    dataset = datasets.MNIST('data', train=False, transform=transform)

    data_dir = args.data_dir
    if data_dir is None:
        data_dir = os.path.join(script_dir, '../fpga/data')
    if not os.path.isabs(data_dir):
        data_dir = os.path.join(script_dir, data_dir)
    os.makedirs(data_dir, exist_ok=True)

    w1 = to_q8_8(model.conv1.weight.detach().numpy())
    b1 = to_q8_8(model.conv1.bias.detach().numpy())
    w2 = to_q8_8(model.conv2.weight.detach().numpy())
    b2 = to_q8_8(model.conv2.bias.detach().numpy())
    w_fc1 = to_q8_8(model.fc1.weight.detach().numpy())
    b_fc1 = to_q8_8(model.fc1.bias.detach().numpy())
    w_fc2 = to_q8_8(model.fc2.weight.detach().numpy())
    b_fc2 = to_q8_8(model.fc2.bias.detach().numpy())

    with open(os.path.join(data_dir, 'conv1_w.hex'), 'w') as f:
        for oc in range(32):
            for r in range(3):
                for c in range(3):
                    f.write(hex_16(w1[oc, 0, r, c]))
    with open(os.path.join(data_dir, 'conv1_b.hex'), 'w') as f:
        for oc in range(32):
            f.write(hex_16(b1[oc]))

    with open(os.path.join(data_dir, 'conv2_w.hex'), 'w') as f:
        for oc in range(64):
            for ic in range(32):
                for r in range(3):
                    for c in range(3):
                        f.write(hex_16(w2[oc, ic, r, c]))
    # Conv2 RTL stores output-channel banks independently so Vivado can infer
    # initialized ROMs instead of synthesizing an unsupported memory copy.
    for bank in range(32):
        with open(os.path.join(data_dir, f'conv2_w_bank{bank}.hex'), 'w') as f:
            for group in range(2):
                oc = group * 32 + bank
                for ic in range(32):
                    for r in range(3):
                        for c in range(3):
                            f.write(hex_16(w2[oc, ic, r, c]))
    with open(os.path.join(data_dir, 'conv2_b.hex'), 'w') as f:
        for oc in range(64):
            f.write(hex_16(b2[oc]))

    # FC1 hardware stream order is H, W, C for 2x2x64 features.
    with open(os.path.join(data_dir, 'fc1_w.hex'), 'w') as f:
        for oc in range(128):
            w_hw = w_fc1[oc].reshape(64, 2, 2).transpose(1, 2, 0).flatten()
            for val in w_hw:
                f.write(hex_16(val))
    with open(os.path.join(data_dir, 'fc1_b.hex'), 'w') as f:
        for oc in range(128):
            f.write(hex_16(b_fc1[oc]))

    with open(os.path.join(data_dir, 'fc2_w.hex'), 'w') as f:
        for oc in range(10):
            for ic in range(128):
                f.write(hex_16(w_fc2[oc, ic]))
    with open(os.path.join(data_dir, 'fc2_b.hex'), 'w') as f:
        for oc in range(10):
            f.write(hex_16(b_fc2[oc]))

    labels = []
    correct = 0
    print(f"Exporting {args.num_images} test images and 2x2 MaxPool golden vectors...")
    for img_idx in range(args.num_images):
        img, label = dataset[img_idx]
        labels.append(label)
        img_q = to_q8_8(img[0].numpy())

        with open(os.path.join(data_dir, f'image_{img_idx}.hex'), 'w') as f:
            for r in range(28):
                for c in range(28):
                    f.write(hex_16(img_q[r, c]))

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

        mp_out = np.zeros((64, 12, 12), dtype=np.int32)
        for oc in range(64):
            for r in range(12):
                for c in range(12):
                    mp_out[oc, r, c] = np.max(c2_relu[oc, r*2:r*2+2, c*2:c*2+2])

        pool2 = np.zeros((64, 2, 2), dtype=np.int32)
        for oc in range(64):
            for r in range(2):
                for c in range(2):
                    pool2[oc, r, c] = np.max(mp_out[oc, r*6:r*6+6, c*6:c*6+6])

        flat_input = pool2.transpose(1, 2, 0).flatten()
        f1_out = np.zeros(128, dtype=np.int32)
        for oc in range(128):
            w_hw = w_fc1[oc].reshape(64, 2, 2).transpose(1, 2, 0).flatten()
            acc = int(b_fc1[oc]) << 8
            for ic in range(256):
                acc += int(flat_input[ic]) * int(w_hw[ic])
            f1_out[oc] = np.clip(acc >> 8, 0, 32767)

        f2_out = np.zeros(10, dtype=np.int32)
        for oc in range(10):
            acc = int(b_fc2[oc]) << 8
            for ic in range(128):
                acc += int(f1_out[ic]) * int(w_fc2[oc, ic])
            f2_out[oc] = np.clip(acc >> 8, -32768, 32767)

        pred = int(np.argmax(f2_out))
        correct += pred == label
        with open(os.path.join(data_dir, f'golden_{img_idx}.hex'), 'w') as f:
            for v in f2_out:
                f.write(hex_16(v))
        print(f"Img {img_idx} label={label} pred={pred}")

    label_name = f'labels_{args.num_images}.hex'
    with open(os.path.join(data_dir, label_name), 'w') as f:
        for label in labels:
            f.write(f"{label:X}\n")

    print(f"Export complete: {correct}/{args.num_images} correct ({correct / args.num_images * 100:.2f}%).")


if __name__ == '__main__':
    main()
