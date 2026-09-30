#!/bin/bash
# 环境变量配置脚本
# 用途：在新机器上配置 API Key 等敏感环境变量
# 用法：bash scripts/setup-env.sh

set -e

echo "===== 环境变量配置 ====="
echo ""

# 检查 ZHIPU_API_KEY
if grep -q "ZHIPU_API_KEY" ~/.bashrc 2>/dev/null; then
  echo "ZHIPU_API_KEY 已存在于 ~/.bashrc"
  read -p "是否覆盖？(y/N): " overwrite
  if [ "$overwrite" != "y" ]; then
    echo "跳过"
    exit 0
  fi
  # 删除旧配置
  sed -i '/ZHIPU_API_KEY/d' ~/.bashrc
fi

echo "请输入智谱 API Key（输入后回车）："
read -r api_key

if [ -z "$api_key" ]; then
  echo "错误：API Key 不能为空"
  exit 1
fi

# 写入 ~/.bashrc
echo "" >> ~/.bashrc
echo "# Zhipu API Key (added by setup-env.sh)" >> ~/.bashrc
echo "export ZHIPU_API_KEY=\"$api_key\"" >> ~/.bashrc

# 立即生效
export ZHIPU_API_KEY="$api_key"

echo ""
echo "===== 配置完成 ====="
echo "已写入 ~/.bashrc"
echo "当前终端已生效"
echo ""
echo "验证："
echo "  echo \$ZHIPU_API_KEY"
