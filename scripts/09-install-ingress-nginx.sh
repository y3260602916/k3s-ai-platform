#!/bin/bash
# Ingress-Nginx 安装脚本
set -e

echo "===== 安装 Ingress-Nginx ====="
kubectl apply -f https://ghproxy.net/https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.0/deploy/static/provider/cloud/deploy.yaml

echo "===== 等待 Pod 启动 ====="
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/component=controller -n ingress-nginx --timeout=120s

echo "===== 验证 ====="
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
