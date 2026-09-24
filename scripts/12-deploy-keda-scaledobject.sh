#!/bin/bash
set -e

cd ~/projects/hpa-test

echo "===== 创建 ServiceMonitor ====="
kubectl apply -f servicemonitor.yaml

echo "===== 删除旧 HPA ====="
kubectl delete hpa hpa-demo --ignore-not-found

echo "===== 创建 ScaledObject ====="
kubectl apply -f scaledobject.yaml

echo "===== 验证 ====="
kubectl get scaledobject
kubectl get hpa
