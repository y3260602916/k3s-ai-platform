#!/bin/bash
# Ansible 安装脚本
set -e

echo "===== 更新软件源 ====="
apt update

echo "===== 安装 Ansible ====="
apt install -y ansible

echo "===== 验证 ====="
ansible --version

echo ""
echo "===== Ansible 安装完成 ====="
