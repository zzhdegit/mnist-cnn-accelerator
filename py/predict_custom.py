import torch
import torchvision.transforms as transforms
from PIL import Image, ImageOps
import argparse
from main import Net
import os
import numpy as np

def preprocess_image(image_path):
    # 1. 读取图片并转换为灰度图
    img = Image.open(image_path).convert('L')
    
    # 2. 颜色反转：MNIST是黑底白字。如果图片背景偏白，需要反转。
    # 我们通过检查图像边缘的平均像素值来猜测背景色，如果是亮色，则反转。
    edges = np.concatenate([
        np.array(img)[0, :], np.array(img)[-1, :],
        np.array(img)[:, 0], np.array(img)[:, -1]
    ])
    if np.mean(edges) > 127:
        img = ImageOps.invert(img)

    # 3. 寻找数字的边界框 (Bounding Box)，裁剪掉多余的黑色空白部分
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)

    # 4. 将裁剪后的数字缩放到 20x20 像素 (保持 MNIST 风格的比例)
    # 保持长宽比，最大边缩放为 20
    max_size = 20
    ratio = max_size / max(img.size)
    new_size = (int(img.size[0] * ratio), int(img.size[1] * ratio))
    img = img.resize(new_size, Image.Resampling.LANCZOS)

    # 5. 将 20x20 或更小的图片粘贴到 28x28 的全黑背景中心 (这就是压缩且不丢失特征的关键)
    new_img = Image.new('L', (28, 28), color=0) # 黑色背景
    # 计算居中粘贴的坐标
    paste_x = (28 - new_size[0]) // 2
    paste_y = (28 - new_size[1]) // 2
    new_img.paste(img, (paste_x, paste_y))

    return new_img

def predict_custom_image(image_path="my_number.png", model_path="mnist_cnn.pt"):
    if not os.path.exists(image_path):
        print(f"找不到图片: {image_path}")
        return

    # 1. 准备设备和加载模型
    device = torch.device("cpu")
    model = Net().to(device)
    try:
        model.load_state_dict(torch.load(model_path, map_location=device, weights_only=True))
    except FileNotFoundError:
        print(f"找不到模型文件: {model_path}，请确保已经运行过训练脚本。")
        return
    model.eval()

    # 2. 图像预处理 (高级预处理，专门针对MNIST优化)
    try:
        img = preprocess_image(image_path)
    except Exception as e:
        print(f"处理图片时发生错误: {e}")
        return

    # 3. 转换为 Tensor 并进行和训练时一样的标准化
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.1307,), (0.3081,))
    ])
    img_tensor = transform(img)

    # 4. 使用模型进行预测
    with torch.no_grad():
        output = model(img_tensor.unsqueeze(0).to(device))
        pred = output.argmax(dim=1, keepdim=True).item()
        probabilities = torch.nn.functional.softmax(output[0], dim=0)

    print(f"\n=====================================")
    print(f"正在识别图片: {image_path}")
    print(f"👉 模型预测的数字是: {pred}")
    print(f"=====================================\n")
    
    print("每个数字的置信度概率:")
    for i in range(10):
        print(f"数字 {i}: {probabilities[i].item() * 100:.5f}%")

if __name__ == '__main__':
    # 为了方便你直接在 PyCharm 运行，我修改了代码。
    # 默认读取 'my_number.png'，如果你没传参数，也不会报错。
    parser = argparse.ArgumentParser(description='测试自定义手写数字图片')
    parser.add_argument('image', type=str, nargs='?', default='my_number.png', help='你要测试的图片路径 (默认: my_number.png)')
    args = parser.parse_args()
    
    predict_custom_image(args.image)
