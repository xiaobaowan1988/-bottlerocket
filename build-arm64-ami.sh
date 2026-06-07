#!/bin/bash
set -e

echo "=== 1. 安装基础依赖 (假设已安装 Docker 并开启 BuildKit) ==="
# 安装 Rust 工具链 (如果尚未安装)
if ! command -v cargo &> /dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

# 安装 cargo-make (Twoliter 编排依赖)
cargo install cargo-make

echo "=== 2. 获取 Bottlerocket 源码 ==="
# 克隆仓库并进入目录
if [ ! -d "bottlerocket" ]; then
    git clone https://github.com/bottlerocket-os/bottlerocket.git
fi
cd bottlerocket

echo "=== 3. 执行交叉编译与镜像构建 ==="
# 构建 ARM64 架构、适配 K8s 1.34 的 AWS 变体镜像
# 首次编译耗时较长，请保持网络畅通并耐心等待
cargo make \
  -e BUILDSYS_ARCH=aarch64 \
  -e BUILDSYS_VARIANT=aws-k8s-1.34 \
  build

echo "=== 4. (可选) 注册并发布至 AWS AMI ==="
# 确保本地已配置好 AWS CLI 凭证 (~/.aws/credentials)
# 将产物推送到东京区 (ap-northeast-1) 并注册 AMI
cargo make \
  -e BUILDSYS_ARCH=aarch64 \
  -e BUILDSYS_VARIANT=aws-k8s-1.34 \
  -e PUBLISH_REGIONS=ap-northeast-1 \
  -e PUBLISH_AMI_NAME="bottlerocket-custom-aarch64-k8s-1.34" \
  ami

echo "=== 构建流程全部完成！ ==="
# 编译好的原始镜像文件将存放在类似如下的路径中：
# ./build/images/aarch64/aws-k8s-1.34/vX.Y.Z/
