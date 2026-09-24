#!/bin/bash
# GPU 成本估算脚本
# 用途：根据 GPU 利用率和运行时长估算成本

set -e

# 配置
GPU_PRICE_PER_HOUR=10    # 假设 GPU 每小时 10 元
POD_NAME="hpa-demo"

echo "===== 获取 GPU 利用率（模拟）====="
# 真实场景用 nvidia-smi 或 DCGM 指标
# 这里用 CPU 利用率模拟
CPU_USAGE=$(kubectl top pod -l app=${POD_NAME} --no-headers | awk '{print $2}' | sed 's/m//')

echo "当前 CPU 使用：${CPU_USAGE}m"

echo "===== 计算成本 ====="
# 假设 1000m = 1 核，1 核约等于 10% GPU 利用率
GPU_UTIL=$(echo "scale=2; ${CPU_USAGE} / 10" | bc)
HOURLY_COST=$(echo "scale=2; ${GPU_PRICE_PER_HOUR} * ${GPU_UTIL} / 100" | bc)

echo "GPU 利用率：${GPU_UTIL}%"
echo "每小时成本：${HOURLY_COST} 元"
echo "每天成本：$(echo "scale=2; ${HOURLY_COST} * 24" | bc) 元"
echo "每月成本：$(echo "scale=2; ${HOURLY_COST} * 24 * 30" | bc) 元"

echo ""
echo "===== 优化建议 ====="
if [ $(echo "${GPU_UTIL} < 10" | bc) -eq 1 ]; then
  echo "GPU 利用率低于 10%，建议缩容到 0 或分时调度"
fi

echo ""
echo "===== 成本估算完成 ====="
