#!/bin/bash
# Helm 安装脚本
# 用途：在 Ubuntu 上安装 Helm

set -e

echo "===== 下载 Helm ====="
wget https://mirrors.huaweicloud.com/helm/v3.14.4/helm-v3.14.4-linux-amd64.tar.gz

echo "===== 解压 ====="
tar -zxvf helm-v3.14.4-linux-amd64.tar.gz

echo "===== 安装 ====="
sudo mv linux-amd64/helm /usr/local/bin/helm
chmod +x /usr/local/bin/helm
sudo ln -sf /usr/local/bin/helm /usr/bin/helm

echo "===== 验证 ====="
helm version

echo ""
echo "===== Helm 安装完成 ====="
