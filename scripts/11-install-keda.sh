#!/bin/bash
set -e

echo "===== 下载 KEDA 镜像 ====="
docker pull ghcr.nju.edu.cn/kedacore/keda:2.20.2
docker pull ghcr.nju.edu.cn/kedacore/keda-metrics-apiserver:2.20.2
docker pull ghcr.nju.edu.cn/kedacore/keda-admission-webhooks:2.20.2

echo "===== 推送到 Harbor ====="
docker tag ghcr.nju.edu.cn/kedacore/keda:2.20.2 127.0.0.1:8081/library/keda:2.20.2
docker tag ghcr.nju.edu.cn/kedacore/keda-metrics-apiserver:2.20.2 127.0.0.1:8081/library/keda-metrics-apiserver:2.20.2
docker tag ghcr.nju.edu.cn/kedacore/keda-admission-webhooks:2.20.2 127.0.0.1:8081/library/keda-admission-webhooks:2.20.2

docker push 127.0.0.1:8081/library/keda:2.20.2
docker push 127.0.0.1:8081/library/keda-metrics-apiserver:2.20.2
docker push 127.0.0.1:8081/library/keda-admission-webhooks:2.20.2

echo "===== Helm 安装 KEDA ====="
helm install keda kedacore/keda -n keda --create-namespace \
  --version 2.20.2 \
  --set image.keda.registry=127.0.0.1:8081 \
  --set image.keda.repository=library/keda \
  --set image.metricsApiServer.registry=127.0.0.1:8081 \
  --set image.metricsApiServer.repository=library/keda-metrics-apiserver \
  --set image.webhooks.registry=127.0.0.1:8081 \
  --set image.webhooks.repository=library/keda-admission-webhooks

echo "===== 等待 Pod 就绪 ====="
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=keda-operator -n keda --timeout=120s
kubectl get pods -n keda
