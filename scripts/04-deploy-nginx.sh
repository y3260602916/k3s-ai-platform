#!/bin/bash
# nginx 部署脚本
# 用途：一键部署 nginx 测试服务

set -e

YAML_DIR="/root/projects/test-nginx"

echo "===== 创建目录 ====="
mkdir -p ${YAML_DIR}
cd ${YAML_DIR}

echo "===== 生成 nginx.yaml ====="
cat > nginx.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-test
  template:
    metadata:
      labels:
        app: nginx-test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-test
spec:
  selector:
    app: nginx-test
  ports:
  - port: 80
    targetPort: 80
EOF

echo "===== 应用 YAML ====="
kubectl apply -f nginx.yaml

echo "===== 等待 Pod 就绪 ====="
sleep 10
kubectl get pods

echo ""
echo "===== nginx 部署完成 ====="
