#!/bin/bash
# K3s 镜像源配置脚本
# 用途：配置 K3s 的镜像加速和 Harbor 认证

set -e

HARBOR_IP="47.113.189.149"
HARBOR_PORT="8081"
REGISTRIES_FILE="/etc/rancher/k3s/registries.yaml"

echo "===== 备份原配置 ====="
if [ -f ${REGISTRIES_FILE} ]; then
  cp ${REGISTRIES_FILE} ${REGISTRIES_FILE}.bak.$(date +%Y%m%d%H%M%S)
  echo "已备份到 ${REGISTRIES_FILE}.bak.*"
fi

echo "===== 写入 registries.yaml ====="
cat > ${REGISTRIES_FILE} << EOF
mirrors:
  docker.io:
    endpoint:
      - "https://docker.m.daocloud.io"
      - "https://dockerproxy.com"
      - "https://docker.nju.edu.cn"
  registry.k8s.io:
    endpoint:
      - "https://k8s.m.daocloud.io"
  quay.io:
    endpoint:
      - "https://quay.m.daocloud.io"
      - "https://quay.mirrors.ustc.edu.cn"
  "${HARBOR_IP}:${HARBOR_PORT}":
    endpoint:
      - "http://${HARBOR_IP}:${HARBOR_PORT}"
configs:
  "${HARBOR_IP}:${HARBOR_PORT}":
    tls:
      insecure_skip_verify: true
    auth:
      username: admin
      password: Harbor12345
EOF

echo "===== 验证 YAML 格式 ====="
python3 -c "import yaml; yaml.safe_load(open('${REGISTRIES_FILE}'))" && echo "格式正确"

echo "===== 重启 K3s ====="
systemctl restart k3s
sleep 60
kubectl get nodes

echo ""
echo "===== K3s 镜像源配置完成 ====="
