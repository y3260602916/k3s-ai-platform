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

## 18. Harbor 离线包下载太慢

**现象：** Ansible 卡在 `下载 Harbor 安装包`，30 秒只下了 351KB，按这个速度要 14 小时。
**根因：** `ghproxy.net` 虽然能返回 302，但实际下载走的是 `release-assets.githubusercontent.com`，国内速度不稳定。
**解决：**
1. 本地用代理下载：

```
[https://github.com/goharbor/harbor/releases/download/v2.10.0/harbor-offline-installer-v2.10.0.tgz](https://github.com/goharbor/harbor/releases/download/v2.10.0/harbor-offline-installer-v2.10.0.tgz)
```

1. scp 上传到服务器 `/root/`
2. 改 Playbook，本地有包就用本地：

```
- name: 检查本地是否有 Harbor 包
  stat:
    path: /root/harbor-offline-installer-{{ harbor_version }}.tgz
  register: local_harbor
- name: 复制本地 Harbor 包
  copy:
    src: /root/harbor-offline-installer-{{ harbor_version }}.tgz
    dest: "{{ harbor_dir }}/harbor-offline-installer-{{ harbor_version }}.tgz"
  when: local_harbor.stat.exists and not harbor_installed.stat.exists
- name: 下载 Harbor 安装包
  get_url:
    url: "https://ghproxy.net/..."
    dest: "{{ harbor_dir }}/harbor-offline-installer-{{ harbor_version }}.tgz"
  when: not local_harbor.stat.exists and not harbor_installed.stat.exists
```

**关键词：** GitHub 代理、scp、Ansible 条件判断

---

## 19. Ansible register 语法错误

**现象：** Playbook 报语法错误，报错行是 `register: k3s_instgrep -A25 ...`。

**根因：** 编辑文件时，把另一个命令 `grep -A25 ...` 误粘贴进了 `register:` 后面。

**解决：** 改成 `register: k3s_install`。

**验证：**

```
ansible-playbook -i inventory/hosts playbooks/03-install-k3s.yml --syntax-check
```

**关键词：** YAML 语法、register、syntax-check

---

## 20. Ansible wait 执行太早

**现象：** `kubectl wait` 报 `no matching resources found`。

**根因：** 安装 Ingress-Nginx 的 YAML 后，Pod 需要几秒到几十秒才被创建。立刻 `kubectl wait` 时资源还不存在，直接报错。

**解决：** 先轮询等 Pod 出现，再 wait 就绪：

```
- name: 等待 Controller 就绪
  shell: |
    for i in $(seq 1 60); do
      if kubectl get pod -l app.kubernetes.io/component=controller -n ingress-nginx 2>/dev/null | grep -q Running; then
        if kubectl wait --for=condition=Ready pod -l app.kubernetes.io/component=controller -n ingress-nginx --timeout=10s 2>/dev/null; then
          echo "Controller 已就绪"
          exit 0
        fi
      fi
      sleep 5
    done
    echo "超时"
    exit 1
```

**关键词：** kubectl wait、轮询、幂等

---

## 21. Ansible push 镜像未登录 Harbor

**现象：** `docker push` 报 `push access denied, repository does not exist or may require authorization`。

**根因：** 推送前没执行 `docker login`。

**解决：** 在 push 之前加登录 task：

```
- name: 登录 Harbor
  shell: |
    docker login 127.0.0.1:8081 -u admin -p Harbor12345
  register: docker_login
  changed_when: false
```

**关键词：** docker login、Harbor 认证

---

## 22. docker build 少构建上下文

**现象：** `docker build -t aiops-agent:v3` 报 `requires 1 argument`。

**根因：** `docker build` 需要指定构建上下文路径，末尾的 `.` 表示当前目录。

**解决：**

```
docker build -t aiops-agent:v3 .
```

**关键词：** docker build、构建上下文

---

## 23. 根目录误创建文件

**现象：** 在 `~/k3s-ai-platform/` 根目录发现 `Dockerfile` 和 `requirements.txt`，内容是 AIOps 的，但和 `projects/aiops-agent/` 里的不一致（少 `.`、端口错、有拼写错误）。

**根因：** 在错误的目录执行了 `vi` 命令。

**解决：**

```
rm ~/k3s-ai-platform/Dockerfile ~/k3s-ai-platform/requirements.txt
```

**教训：** 创建文件前先 `pwd` 确认当前目录。

**关键词：** 工作目录、文件路径

---

## 24. GitHub Actions 不触发

**现象：** 添加 workflow 文件并 push 后，Actions 页面显示 `0 workflow runs`。

**根因：** workflow 里配置了 `paths` 过滤：

```
on:
  push:
    paths:
      - 'projects/aiops-agent/**'
```

这次 push 只改了 `.github/workflows/build-aiops.yml`，没有改 `projects/aiops-agent/` 下的文件，不满足触发条件。

**解决：**

方案 A：手动触发。打开 workflow 页面，点 `Run workflow`。

方案 B：把 workflow 文件本身也加到 paths：

```
    paths:
      - 'projects/aiops-agent/**'
      - '.github/workflows/build-aiops.yml'
```

**关键词：** GitHub Actions、paths 过滤、workflow_dispatch

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
| AIOps 部署 | 11   |


**排查通用思路：** 先看 Pod 状态 → `describe` 看 Events → `logs` 看容器日志 → 定位根因 → 修复 → 验证。

