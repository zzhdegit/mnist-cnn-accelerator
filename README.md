# MNIST CNN Hardware Accelerator (FPGA)

![FPGA](https://img.shields.io/badge/Platform-Vivado-orange.svg) 
![Language](https://img.shields.io/badge/Language-SystemVerilog-blue.svg)
![Accuracy](https://img.shields.io/badge/Accuracy-98.30%25-green.svg)

这是一个基于 FPGA 实现的高性能卷积神经网络（CNN）加速器，专门针对 MNIST 手写数字识别任务设计。该项目实现了从 PyTorch 模型训练、定点化量化到 SystemVerilog RTL 部署的全流程。

## 🚀 项目亮点

- **流式架构**: 采用基于 Shift-Register 的 Line Buffer，实现像素流实时处理，极大地降低了对片上内存的依赖。
- **高并行度**: 第二层卷积支持 32 通道同时累加，充分利用 FPGA 的并行计算能力。
- **比特对齐 (Bit-accurate)**: 硬件输出与 Python 定点化仿真模型 100% 吻合，确保了算法到硬件的无损迁移。
- **高精度**: 经过 Q8.8 定点化量化后，在 1000 张测试集图片上依然保持 **98.30%** 的识别准确率。

## 📂 目录结构

```text
├── fpga/
│   ├── src/        # 加速器核心 RTL 源码 (SystemVerilog)
│   ├── sim/        # 端到端测试激励 (Testbench)
│   ├── data/       # 导出的十六进制权重和测试图片数据
│   └── scripts/    # Vivado 一键仿真 TCL 脚本
├── py/
│   ├── main.py     # PyTorch 模型训练
│   ├── export_fpga_data.py # 权重导出与 RTL 等效验证
│   └── test_accuracy_1000.py # 批量精度测试脚本
├── docs/
│   └── CNN_Accelerator_Report.md # 详细项目报告
└── README.md
```

## 🛠️ 快速开始

### 1. 软件端 (Python)
安装依赖并生成量化数据：
```bash
pip install -r py/requirements.txt
python py/main.py --save-model        # 训练模型
python py/export_fpga_data.py         # 导出硬件参数
```

### 2. 硬件端 (Vivado)
使用 Vivado 运行仿真：
1. 打开 Vivado Tcl Console。
2. 切换到脚本目录并运行：
```tcl
cd [get_property DIRECTORY [current_project]]/fpga/scripts
source sim.tcl
```

## 📊 性能指标

| 指标 | 数值 |
| :--- | :--- |
| **目标频率** | 100 MHz (在 Zynq-7020 上验证通过) |
| **识别准确率** | 98.30% (1000 样本) |
| **数据位宽** | 16-bit 有符号定点 (Q8.8) |
| **核心算法** | 2层卷积 + 2x2 MaxPool + 2层全连接 |

## ⚖️ 开源协议
本项目采用 MIT 协议开源。
