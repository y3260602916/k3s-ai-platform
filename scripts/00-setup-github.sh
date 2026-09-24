#!/bin/bash
# GitHub 仓库配置脚本
# 用途：在新机器上配置 git、SSH 密钥，并克隆项目仓库
# 用法：手动创建此脚本，运行后按提示操作

set -e

GIT_USERNAME="y3260602916"
GIT_EMAIL="3260602916@qq.com"
REPO_SSH="git@github.com:${GIT_USERNAME}/k3s-ai-platform.git"
REPO_HTTPS="https://github.com/${GIT_USERNAME}/k3s-ai-platform.git"
CLONE_DIR="/root/k3s-ai-platform"

echo "===== 第 1 步：安装 git ====="
if ! command -v git &> /dev/null; then
  apt update
  apt install -y git
fi
git --version

echo ""
echo "===== 第 2 步：配置 git 身份 ====="
git config --global user.name "${GIT_USERNAME}"
git config --global user.email "${GIT_EMAIL}"
echo "已配置：${GIT_USERNAME} <${GIT_EMAIL}>"

echo ""
echo "===== 第 3 步：检查 SSH 密钥 ====="
if [ ! -f ~/.ssh/id_ed25519 ]; then
  echo "未找到 SSH 密钥，正在生成..."
  ssh-keygen -t ed25519 -C "${GIT_EMAIL}" -f ~/.ssh/id_ed25519 -N ""
  echo "SSH 密钥已生成"
else
  echo "SSH 密钥已存在，跳过生成"
fi

echo ""
echo "===== 第 4 步：显示公钥 ====="
echo "请把下面的公钥添加到 GitHub："
echo "https://github.com/settings/keys"
echo ""
cat ~/.ssh/id_ed25519.pub
echo ""
read -p "添加完成后按回车继续..."

echo ""
echo "===== 第 5 步：测试 SSH 连接 ====="
ssh -o StrictHostKeyChecking=no -T git@github.com || true

echo ""
echo "===== 第 6 步：克隆仓库 ====="
if [ ! -d "${CLONE_DIR}" ]; then
  git clone ${REPO_SSH} ${CLONE_DIR}
  echo "仓库已克隆到 ${CLONE_DIR}"
else
  echo "目录 ${CLONE_DIR} 已存在，跳过克隆"
  cd ${CLONE_DIR}
  git pull
fi

echo ""
echo "===== GitHub 配置完成 ====="
echo "仓库位置：${CLONE_DIR}"
echo "接下来可以运行 Ansible Playbook："
echo "  cd ${CLONE_DIR}/ansible"
echo "  ansible-playbook -i inventory/hosts playbooks/site.yml"
