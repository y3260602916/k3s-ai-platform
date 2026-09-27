# 排错记录

本项目在开发过程中遇到了 13 个真实故障，以下是排查摘要。

---

## 1. GPU 插件部署失败（WSL2）

**现象：** Pod 卡在 `ContainerCreating`，后变为 `Error`，反复重启。
**根因：** 两个连环问题：
- pause 镜像从 Docker Hub 拉取超时
- 容器内缺少 NVML 库，NVIDIA Device Plugin 无法启动
**解决：**
- 配置 K3s 镜像源，解决 pause 镜像拉取
- 安装 NVIDIA Container Toolkit，让容器能访问 GPU
**关键词：** pause 容器、镜像加速、NVML、Device Plugin

---

## 2. K3s 反复重启

**现象：** `systemctl status k3s` 显示 `activating (auto-restart)`，服务起不来。
**根因：** `config.yaml` 里配置了已废弃的 feature gate：

```
kubelet-arg:

- "feature-gates=DevicePlugins=true"
```

DevicePlugins 在 K8s 1.10 已 GA，新版本 kubelet 不再接受这个参数。
**解决：** 清空 `config.yaml`。
**关键词：** feature gate、GA、kubelet 参数

---

## 3. Harbor 访问 404

**现象：** Harbor 容器全部 `healthy`，但 `curl` 返回 `404 page not found`。
**根因：** K3s 内置的 ServiceLB 通过 iptables 规则占用了节点 80 端口，Docker 的 `8080->80` 映射被截获。
**解决：** 把 Harbor 的 HTTP 端口从 80 改为 8081。
**关键词：** ServiceLB、iptables DNAT、端口冲突

---

## 4. Docker 容器无法访问 Harbor

**现象：** `docker login` 报 `connection refused`，但宿主机 `curl` 能通。
**根因：** 容器有独立网络命名空间，`127.0.0.1` 指向容器自身，不是宿主机。
**解决：** 用 Docker 网络网关 IP（`172.18.0.1`）配置 `insecure-registries`。
**关键词：** 网络命名空间、Docker 网关、insecure-registries

---

## 5. Docker 推送被拒绝

**现象：** `docker push` 报 `server gave HTTP response to HTTPS client`。
**根因：** Docker 默认只信任 HTTPS 仓库，Harbor 配的是 HTTP。
**解决：** 在 `daemon.json` 里把 Harbor 加入 `insecure-registries`。
**关键词：** insecure-registries、HTTP vs HTTPS

---

## 6. kube-state-metrics 镜像拉取超时

**现象：** Pod 处于 `ImagePullBackOff`。
**根因：** 镜像来自 `registry.k8s.io`，国内无法直连。K3s 用 containerd，需要单独配镜像源。
**解决：** 在 `registries.yaml` 里为 `registry.k8s.io` 和 `quay.io` 配镜像源。
**关键词：** containerd、registries.yaml、mirror

---

## 7. node-exporter 挂载失败（WSL2）

**现象：** Pod 处于 `CreateContainerError`，报 `path "/" is not a shared or slave mount`。
**根因：** node-exporter 需要 `HostToContainer` 挂载主机根目录，WSL2 的挂载传播模式不支持。
**解决：** 用 Helm 禁用 `hostRootFsMount`。
**关键词：** 挂载传播、HostToContainer、WSL2 限制

---

## 8. Deployment selector 不可变

**现象：** 修改 Deployment 的 `selector` 报 `field is immutable`。
**根因：** K8s 硬性限制，selector 决定 Deployment 管理哪些 Pod，不能改。
**解决：** 删除旧 Deployment，重新创建。
**关键词：** 不可变字段、selector

---

## 9. Traefik 占用 80 端口

**现象：** 安装 Ingress-Nginx 后 EXTERNAL-IP 一直 `<pending>`。
**根因：** K3s 默认装 Traefik，占用 80/443，和 Ingress-Nginx 冲突。
**解决：** 在 `/etc/rancher/k3s/config.yaml` 中禁用 Traefik。
**关键词：** Ingress Controller、端口冲突

---

## 10. HPA 显示 `<unknown>`

**现象：** 刚创建的 HPA，TARGETS 显示 `<unknown>`，REPLICAS 是 0。
**根因：** metrics-server 采集有延迟，或 HPA 刚创建还没同步。
**解决：** 等 30 秒。如果一直 unknown，检查 Pod 是否配了 `resources.requests`。
**关键词：** metrics-server、采集周期、resources

---

## 11. HPA 压测不触发扩容

**现象：** 压测 nginx，CPU 只有 7%，HPA 不扩容。
**根因：** nginx 返回静态页面，几乎不消耗 CPU。
**解决：** 换成计算密集型应用（哈希计算模拟推理），CPU 升到 500%，触发扩容。
**关键词：** 压测匹配、计算密集型、AI 推理场景

---

## 12. KEDA Chart 版本不匹配

**现象：** KEDA operator `CrashLoopBackOff`，报 `unknown flag: --service-account-token-mode`。
**根因：** Helm 安装时没指定 `--version`，默认拉最新 Chart，给旧镜像传了新参数。
**解决：** 用 `--version 2.20.2` 锁定 Chart 版本。
**关键词：** Chart 版本、镜像版本、Helm

---

## 13. Dockerfile 缺依赖

**现象：** Pod `CrashLoopBackOff`，报 `ModuleNotFoundError: No module named 'prometheus_client'`。
**根因：** 代码里加了新 `import`，但 Dockerfile 没同步加依赖。
**解决：** 更新 Dockerfile 的 `pip install`。
**关键词：** Dockerfile、依赖同步

---

## 14. AIOps 服务 API Key 编码错误

**现象：** AIOps 服务收到告警后返回 500，日志报 `UnicodeEncodeError: 'ascii' codec can't encode characters`。
**根因：** K8s Secret 里存的是占位符"你的API_Key"（中文），不是真实的 API Key。HTTP 请求头只能传 ASCII 字符，中文导致编码失败。
**解决：** 删除旧 Secret，用真实 Key 重建：

```
kubectl delete secret aiops-secret  
kubectl create secret generic aiops-secret --from-literal=api-key=<真实Key>  
kubectl delete pod -l app=aiops-agent
```

**验证：**

```
kubectl get secret aiops-secret -o jsonpath='{.data.api-key}' | base64 -d | xxd | head -3
```

应全是 ASCII 字符（十六进制 20-7e）。
**关键词：** K8s Secret、ASCII 编码、API Key 管理

---

## 15. Alertmanager 路由不匹配

**现象：** Prometheus 已触发告警，但 Alertmanager 没有转发到 AIOps 服务。
**根因：** Alertmanager 的路由规则用 `match` 只匹配了 `CPUThrottlingHigh`，而实际触发的告警是 `HighCPUUsage`，不匹配，走了默认的 null receiver。
**解决：** 改用 `match_re` 正则匹配多个告警名：

```
routes:
- receiver: aiops
  match_re:
    alertname: HighCPUUsage|CPUThrottlingHigh
  continue: true
```

用 Helm upgrade 更新：

```
helm upgrade monitoring ./kube-prometheus-stack-55.5.0.tgz -n monitoring -f aiops-values.yaml
kubectl delete pod -n monitoring alertmanager-monitoring-kube-prometheus-alertmanager-0
```

**验证：**

```
kubectl get secret -n monitoring alertmanager-monitoring-kube-prometheus-alertmanager-generated -o json | python3 -c "import sys, json, base64, gzip; d=json.load(sys.stdin); [print(gzip.decompress(base64.b64decode(v)).decode()) for k,v in d['data'].items()]"
```

应看到 `match_re` 配置。

**关键词：** Alertmanager、路由规则、match_re

---

## 16. kubectl exec 不支持 -l 参数

**现象：** `kubectl exec -l app=xxx -- command` 报 `unknown shorthand flag: 'l'`。

**根因：** `kubectl exec` 不支持标签选择器，只支持 Pod 名字。

**解决：** 先用 `kubectl get pods -l` 获取 Pod 名，再 exec：

```
POD=$(kubectl get pods -l app=aiops-agent -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- cat /app/app.py
```

**关键词：** kubectl exec、标签选择器、Pod 名

---

## 17. LLM API 额度耗尽

**现象：** AIOps 服务调用 LLM 返回 `403 - Free quota exhausted`。

**根因：** 通义千问免费额度用完。

**解决：** 切换 LLM 平台（如智谱 GLM），或充值后关闭"仅使用免费额度"模式。

**代码改动：**

```
client = OpenAI(
    api_key=os.getenv("ZHIPU_API_KEY"),
    base_url="https://open.bigmodel.cn/api/paas/v4",
)
```

**关键词：** LLM API、额度管理、多平台切换

---

## 总结

| 类别       | 数量  |
| -------- | --- |
| 镜像拉取问题   | 3   |
| 端口冲突     | 2   |
| 容器网络     | 2   |
| 版本不匹配    | 2   |
| 配置格式     | 1   |
| 应用依赖     | 1   |
| K8s 限制   | 2   |
| AIOps 部署 | 4   |


**排查通用思路：** 先看 Pod 状态 → `describe` 看 Events → `logs` 看容器日志 → 定位根因 → 修复 → 验证。

