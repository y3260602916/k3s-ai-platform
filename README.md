# K3s AI 推理平台

基于 K3s 的云原生 AI 推理平台，集成 Harbor、Prometheus、Ingress-Nginx、HPA/KEDA、RBAC/NetworkPolicy、AIOps 智能诊断，通过 Ansible 实现一键部署。

## 项目背景

学习性质的云原生 AI 推理平台部署实践。模拟 AI 公司推理服务的运维场景：镜像管理、监控告警、灰度发布、自动扩缩容、安全加固、智能诊断。

**不是真实生产环境**，单节点部署，无真实流量。但尽量模拟了生产中的关键问题，记录了 17 个真实排错案例。

## 已实现

- K3s 集群搭建，配置镜像加速和私有仓库
- Harbor 私有镜像仓库，镜像推送与拉取
- Prometheus + Grafana 监控集群和应用指标
- Ingress-Nginx Canary 灰度发布，秒级回滚
- HPA + KEDA 自动扩缩容（CPU / 队列长度）
- RBAC + NetworkPolicy 安全加固
- AIOps 智能诊断：告警自动触发 LLM 分析并输出根因
- Ansible 多机一键部署

## 待实现

- GPU 调度和显存监控
- GPU 成本优化（缩容到 0、模型量化）
- CI/CD 流水线

## 架构

用户请求 → Ingress-Nginx → Service → Pod（推理服务）
                                    ↑
                    KEDA/HPA ← Prometheus ← 监控指标
                                    ↓
                    Alertmanager → AIOps → LLM 诊断
                                    ↑
                              Harbor（镜像仓库）

## 技术栈

K3s、Docker、Harbor、Prometheus、Grafana、Alertmanager、Ingress-Nginx、HPA、KEDA、RBAC、NetworkPolicy、Ansible、Python、Shell、智谱 GLM

## 项目结构

.
├── ansible/                          # Ansible 一键部署
│   ├── inventory/hosts               # 被控机清单
│   └── playbooks/                    # 8 个 Playbook + site.yml
├── scripts/                          # Shell 脚本（14 个）
├── projects/
│   ├── aiops-agent/                  # AIOps 智能诊断服务
│   ├── grayscale/                    # 灰度发布示例
│   └── hpa-test/                     # HPA + KEDA 扩缩容示例
└── docs/
    └── troubleshooting.md            # 17 个排错记录
    
## 快速开始

```bash
git clone git@github.com:y3260602916/k3s-ai-platform.git
cd k3s-ai-platform
vi ansible/inventory/hosts          # 改 IP
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/site.yml
排错记录
开发过程中遇到 17 个真实故障，涵盖镜像拉取、端口冲突、容器网络、版本不匹配、AIOps 部署等。详见 docs/troubleshooting.md。
