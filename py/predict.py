import torch
import torchvision.transforms as transforms
import torchvision.datasets as datasets
from main import Net
import random

def main():
    # 1. 准备设备和加载模型
    device = torch.device("cpu")
    model = Net().to(device)
    model.load_state_dict(torch.load("mnist_cnn.pt", map_location=device, weights_only=True))
    model.eval()

    # 2. 加载测试数据集 (如果之前下载过，它会直接读取)
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])
    dataset = datasets.MNIST('../data', train=False, transform=transform)

    # 3. 随机抽取一张测试图片
    idx = random.randint(0, len(dataset) - 1)
    image, label = dataset[idx]

    # 4. 使用模型进行预测
    with torch.no_grad():
        # image 的形状是 [1, 28, 28]，模型需要 [batch_size, 1, 28, 28]，所以用 unsqueeze 加一个维度
        output = model(image.unsqueeze(0).to(device))
        pred = output.argmax(dim=1, keepdim=True).item()

    print(f"=====================================")
    print(f"随机抽取的图片索引: {idx}")
    print(f"真实标签 (真实数字): {label}")
    print(f"模型预测的数字: {pred}")
    print(f"=====================================\n")
    print("图片的 ASCII 字符画展示 (##代表深色笔迹，::代表浅色笔迹)：")

    # 5. 为了在终端显示，把归一化后的数据还原
    img_unnorm = image[0] * 0.3081 + 0.1307

    # 打印成 ASCII 字符画
    for row in img_unnorm:
        line = ""
        for pixel in row:
            if pixel > 0.5:
                line += "##"  # 颜色深的像素点
            elif pixel > 0.2:
                line += "::"  # 颜色浅的像素点
            else:
                line += "  "  # 空白
        print(line)

if __name__ == '__main__':
    main()
