#!/bin/bash
# HPA 部署脚本
# 用途：部署带资源限制的应用并配置 HPA

set -e

APP_DIR="/root/projects/hpa-test"

echo "===== 创建目录 ====="
mkdir -p ${APP_DIR}
cd ${APP_DIR}

echo "===== 应用 Deployment 和 Service ====="
kubectl apply -f app.yaml

echo "===== 应用 HPA ====="
kubectl apply -f hpa.yaml

echo "===== 等待 Pod 就绪 ====="
kubectl wait --for=condition=Ready pod -l app=hpa-demo --timeout=60s

echo "===== 当前状态 ====="
kubectl get pods
kubectl get hpa

echo ""
echo "===== HPA 部署完成 ====="
