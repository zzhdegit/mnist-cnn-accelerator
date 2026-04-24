import torch
import torchvision.transforms as transforms
import torchvision.datasets as datasets
from main import Net
import numpy as np
import os

def to_q8_8(x):
    v = np.round(x * 256.0).astype(np.int32)
    return np.clip(v, -32768, 32767)

def main():
    # 1. 加载模型
    model = Net()
    model.load_state_dict(torch.load("mnist_cnn.pt", map_location="cpu", weights_only=True))
    model.eval()

    # 2. 准备数据集 (测试集)
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])
    test_dataset = datasets.MNIST('../data', train=False, transform=transform)
    
    # 3. 提取并量化所有权重 (与 RTL 逻辑完全一致)
    w1 = to_q8_8(model.conv1.weight.detach().numpy())
    b1 = to_q8_8(model.conv1.bias.detach().numpy())
    w2 = to_q8_8(model.conv2.weight.detach().numpy())
    b2 = to_q8_8(model.conv2.bias.detach().numpy())
    w_fc1 = to_q8_8(model.fc1.weight.detach().numpy())
    b_fc1 = to_q8_8(model.fc1.bias.detach().numpy())
    w_fc2 = to_q8_8(model.fc2.weight.detach().numpy())
    b_fc2 = to_q8_8(model.fc2.bias.detach().numpy())

    # 预重排权重以匹配硬件 NHWC 顺序 (H, W, C)
    w_fc1_hw = np.zeros((128, 9216), dtype=np.int32)
    for oc in range(128):
        w_fc1_hw[oc] = w_fc1[oc].reshape(64, 12, 12).transpose(1, 2, 0).flatten()

    correct = 0
    total_to_test = 1000
    
    print(f"正在启动比特对齐(Bit-accurate)仿真测试，样本数: {total_to_test}...")

    for i in range(total_to_test):
        img, label = test_dataset[i]
        img_q = to_q8_8(img[0].numpy())

        # --- 硬件等效推理开始 ---
        # Conv1
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

        # Conv2
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

        # Maxpool
        mp_out = np.zeros((64, 12, 12), dtype=np.int32)
        for oc in range(64):
            for r in range(12):
                for c in range(12):
                    mp_out[oc, r, c] = np.max(c2_relu[oc, r*2:r*2+2, c*2:c*2+2])
        
        # FC1 (NHWC stream)
        flat_input = mp_out.transpose(1, 2, 0).flatten()
        f1_out = np.zeros(128, dtype=np.int32)
        for oc in range(128):
            acc = int(b_fc1[oc]) << 8
            for ic in range(9216):
                acc += int(flat_input[ic]) * int(w_fc1_hw[oc, ic])
            f1_out[oc] = np.clip(acc >> 8, -32768, 32767)
        f1_relu = np.maximum(f1_out, 0)

        # FC2
        f2_out = np.zeros(10, dtype=np.int32)
        for oc in range(10):
            acc = int(b_fc2[oc]) << 8
            for ic in range(128):
                acc += int(f1_relu[ic]) * int(w_fc2[oc, ic])
            f2_out[oc] = np.clip(acc >> 8, -32768, 32767)
        
        # 结果判定
        pred = np.argmax(f2_out)
        if pred == label:
            correct += 1
        
        if (i+1) % 100 == 0:
            print(f"进度: {i+1}/{total_to_test}, 当前准确率: {(correct/(i+1))*100:.2f}%")

    final_acc = (correct / total_to_test) * 100
    print("\n" + "="*40)
    print(f"测试完成!")
    print(f"总样本数: {total_to_test}")
    print(f"硬件模型识别正确数: {correct}")
    print(f"最终准确率 (Accuracy): {final_acc:.2f}%")
    print("="*40)

if __name__ == '__main__':
    main()
