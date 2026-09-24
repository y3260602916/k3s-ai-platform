#!/bin/bash
# 监控安装脚本
# 用途：用 Helm 安装 kube-prometheus-stack

set -e

CHART_VERSION="55.5.0"
CHART_DIR="/root/projects/helm-charts"
CHART_FILE="kube-prometheus-stack-${CHART_VERSION}.tgz"

echo "===== 创建目录 ====="
mkdir -p ${CHART_DIR}
cd ${CHART_DIR}

echo "===== 下载 Chart 包 ====="
if [ ! -f ${CHART_FILE} ]; then
  wget https://ghproxy.net/https://github.com/prometheus-community/helm-charts/releases/download/kube-prometheus-stack-${CHART_VERSION}/${CHART_FILE}
fi

echo "===== 创建 monitoring 命名空间 ====="
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

echo "===== 检查 Release 是否已存在 ====="
if helm list -n monitoring | grep -q "^monitoring"; then
  echo "Release monitoring 已存在，跳过安装"
else
  echo "===== 安装 kube-prometheus-stack ====="
  helm install monitoring ./${CHART_FILE} -n monitoring
fi

echo "===== 等待 Pod 启动 ====="
sleep 60
kubectl get pods -n monitoring

echo ""
echo "===== 监控安装完成 ====="
