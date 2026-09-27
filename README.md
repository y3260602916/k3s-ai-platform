# K3s AI 推理平台

基于 K3s 的云原生 AI 推理平台，集成 Harbor 私有镜像仓库、Prometheus 监控、Ingress-Nginx 灰度发布、HPA/KEDA 自动扩缩容、RBAC/NetworkPolicy 安全加固、AIOps 智能诊断，并通过 Ansible 实现多机一键部署。

## 项目背景

本项目是一个学习性质的云原生 AI 推理平台部署实践。

AI 推理服务是 AI 公司的核心产品——用户通过 API 调用模型，返回推理结果。运维的职责是保证它稳定、高效、低成本地运行。为了模拟这个场景，我在云服务器上从零搭建了一套 K3s 集群，覆盖镜像管理、监控告警、灰度发布、自动扩缩容、安全加固等模块。

本项目还集成了 AIOps 智能诊断模块：当 Prometheus 告警触发时，Alertmanager 自动将告警转发到 AIOps 服务，服务拉取相关 Pod 日志，调用 LLM 分析根因并输出排查建议，实现从"告警通知"到"智能诊断"的闭环。

**这不是真实生产环境**：单节点部署，没有真实流量，没有 7×24 值班。但我尽量模拟了生产中的关键问题，并记录了 17 个真实排错案例。如果进入生产环境，还需要学习多集群管理、灾备、SLA 管理等。

## 已实现

- 从零搭建 K3s 集群，配置镜像加速和私有仓库
- 用 Harbor 管理私有镜像，实现镜像推送与拉取
- 用 Prometheus + Grafana 监控集群和应用指标
- 用 Ingress-Nginx Canary 实现灰度发布和秒级回滚
- 用 HPA 和 KEDA 实现基于 CPU 和队列长度的自动扩缩容
- 用 RBAC 和 NetworkPolicy 做权限隔离和网络策略
- 用 Ansible 实现多机一键部署
- 用 LLM 实现 AIOps 智能诊断，告警自动触发分析并输出根因

## 待实现

- 在 GPU 服务器上部署，实现 GPU 调度和显存监控
- 真实推理模型部署
- GPU 成本优化（缩容到 0、模型量化、分时调度）
- CI/CD 流水线

## 架构

用户请求
    ↓
Ingress-Nginx（入口，灰度发布）
    ↓
Service（服务发现）
    ↓
Pod（推理服务）
    ↓
GPU / CPU（计算资源）
    ↑
KEDA / HPA（自动扩缩容）
    ↑
Prometheus + Grafana（监控告警）
    ↑
Alertmanager → AIOps 服务 → LLM（智能诊断）
    ↑
Harbor（私有镜像仓库）

## 技术栈

| 类别 | 技术 |
|------|------|
| 容器运行时 | Docker |
| 容器编排 | K3s（轻量级 Kubernetes） |
| 镜像仓库 | Harbor |
| 监控 | Prometheus + Grafana + Alertmanager |
| 入口网关 | Ingress-Nginx |
| 自动扩缩容 | HPA + KEDA |
| 安全 | RBAC + NetworkPolicy + Trivy |
| AIOps | LLM API（智谱 GLM）、Alertmanager Webhook、K8s Python Client |
| 自动化 | Ansible |
| 脚本 | Shell、Python |

## 模块清单

| 模块 | 说明 |
|------|------|
| 环境搭建 | WSL2 + 云服务器，Docker + K3s 安装 |
| 私有镜像仓库 | Harbor 部署、镜像推送与拉取 |
| 监控体系 | kube-prometheus-stack，集群 + 应用指标 |
| 灰度发布 | Ingress-Nginx Canary，按权重切流量，秒级回滚 |
| 自动扩缩容 | HPA 基于 CPU，KEDA 基于队列长度 |
| 安全加固 | RBAC 权限隔离、NetworkPolicy、Trivy 镜像扫描、告警规则 |
| AIOps 智能诊断 | Alertmanager → AIOps 服务 → LLM 分析 → 诊断报告 |
| Ansible 自动化 | 8 个 Playbook，一键部署全部组件 |
| GPU 成本优化 | 缩容到 0、显存监控、成本估算（待实现） |

## 项目结构

.
├── README.md
├── docs/
│   └── troubleshooting.md          # 17 个真实排错记录
├── ansible/                         # Ansible 自动化
│   ├── inventory/
│   │   └── hosts                   # 被控机清单
│   └── playbooks/
│       ├── site.yml                # 主入口，一键部署
│       ├── 01-system-check.yml
│       ├── 02-install-docker.yml
│       ├── 03-install-k3s.yml
│       ├── 04-install-harbor.yml
│       ├── 05-install-helm.yml
│       ├── 06-install-monitoring.yml
│       ├── 07-install-ingress-nginx.yml
│       └── 08-install-keda.yml
├── scripts/                         # Shell 脚本
│   ├── 00-setup-github.sh
│   ├── 01-system-check.sh
│   ├── ...
│   └── 13-gpu-cost-estimate.sh
└── projects/                        # K8s 部署文件
    ├── aiops-agent/                 # AIOps 智能诊断服务
    │   ├── app.py
    │   ├── Dockerfile
    │   ├── requirements.txt
    │   └── deploy.yaml
    ├── grayscale/                   # 灰度发布示例
    ├── hpa-test/                    # HPA + KEDA 扩缩容示例
    ├── test-nginx/                  # nginx 测试
    └── nginx-harbor-test/           # Harbor 拉取镜像测试

## 快速开始

### 前置条件

- Ubuntu 22.04 / 24.04 服务器
- 4 核 8G 以上配置
- 已安装 Ansible

### 一键部署

```bash
# 1. 克隆仓库
git clone git@github.com:y3260602916/k3s-ai-platform.git
cd k3s-ai-platform

# 2. 修改 inventory/hosts 里的 IP（如果多机部署）
vi ansible/inventory/hosts

# 3. 一键部署
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/site.yml
