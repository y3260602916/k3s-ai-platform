#!/bin/bash
#Docker安装脚本
#用途：在Ubuntu上安装Docker

set -e #遇到错误立即退出

echo "====更新软件包索引===="
apt update

echo "====安装依赖===="
apt install -y ca-certificates curl gnupg

echo "====添加Docker GPG密钥"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "====添加Docker软件源===="
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "====安装Docker===="
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "====启动Docker===="
systemctl enable docker
systemctl start docker

echo "====验证安装===="
docker --version
docker ps

echo ""
echo "====Docker安装完成===="
