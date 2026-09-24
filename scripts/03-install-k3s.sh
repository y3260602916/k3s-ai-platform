#!/bin/bash
# K3s 安装脚本
# 用途：在 Ubuntu 上安装 K3s

set -e

echo "===== 安装 K3s ====="
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | INSTALL_K3S_MIRROR=cn sh -

echo "===== 等待 K3s 启动 ====="
sleep 30

echo "===== 验证节点 ====="
kubectl get nodes

echo "===== 配置 kubectl 权限 ====="
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
chmod 600 ~/.kube/config

echo ""
echo "===== K3s 安装完成 ====="
