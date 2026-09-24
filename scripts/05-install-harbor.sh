#!/bin/bash
# Harbor 安装脚本
# 用途：在 Ubuntu 上安装 Harbor 私有镜像仓库

set -e

HARBOR_VERSION="v2.10.0"
HARBOR_DIR="/root/projects/harbor"
HARBOR_IP=$(curl -s ifconfig.me)

echo "===== 创建目录 ====="
mkdir -p ${HARBOR_DIR}
cd ${HARBOR_DIR}

echo "===== 下载 Harbor 离线安装包 ====="
if [ ! -f harbor-offline-installer-${HARBOR_VERSION}.tgz ]; then
  wget https://ghproxy.net/https://github.com/goharbor/harbor/releases/download/${HARBOR_VERSION}/harbor-offline-installer-${HARBOR_VERSION}.tgz
fi

echo "===== 解压 ====="
tar -xzvf harbor-offline-installer-${HARBOR_VERSION}.tgz
cd harbor

echo "===== 生成 HTTPS 证书 ====="
mkdir -p certs
openssl req -newkey rsa:4096 -nodes -sha256 \
  -keyout certs/harbor.key -x509 -days 365 \
  -out certs/harbor.crt -subj "/CN=harbor.local"

echo "===== 配置 Harbor ====="
cp harbor.yml.tmpl harbor.yml
sed -i "s/hostname: reg.mydomain.com/hostname: ${HARBOR_IP}/" harbor.yml
sed -i "0,/port: 80/s//port: 8081/" harbor.yml
sed -i 's/^https:/#https:/' harbor.yml
sed -i 's/^  port: 443/#  port: 443/' harbor.yml
sed -i 's/^  certificate:/#  certificate:/' harbor.yml
sed -i 's/^  private_key:/#  private_key:/' harbor.yml

echo "===== 安装 Harbor ====="
./install.sh

echo ""
echo "===== Harbor 安装完成 ====="
echo "访问地址：http://${HARBOR_IP}:8081"
echo "用户名：admin"
echo "密码：Harbor12345"
