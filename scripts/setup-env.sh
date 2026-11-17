#!/bin/bash
# LLM 环境变量配置脚本（支持多家 OpenAI 兼容厂商）
# 写入内容：LLM_API_KEY / LLM_BASE_URL / LLM_MODEL
#
# 用法：
#   bash scripts/setup-env.sh                    # 交互式选择厂商
#   bash scripts/setup-env.sh deepseek           # 直接指定：zhipu|deepseek|qwen|openai|custom
#   bash scripts/setup-env.sh zhipu --key sk-xxx --yes
#   bash scripts/setup-env.sh custom --base-url https://xxx/v1 --model xxx --key sk-xxx
#
# 参数：
#   --key <key>        非交互传入 API Key
#   --base-url <url>   覆盖接口地址
#   --model <name>     覆盖模型名称
#   --yes              已存在配置时直接覆盖
#   --force            允许写入含非 ASCII 字符的 Key（不推荐）
#   --file <path>      写入的配置文件（默认 ~/.bashrc）

set -uo pipefail

RC_FILE="$HOME/.bashrc"
PROVIDER=""
API_KEY=""
BASE_URL=""
MODEL=""
ASSUME_YES=0
FORCE=0

die() { echo "错误：$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --key)      [ $# -ge 2 ] || die "--key 缺少参数";      API_KEY="$2";  shift 2 ;;
    --base-url) [ $# -ge 2 ] || die "--base-url 缺少参数"; BASE_URL="$2"; shift 2 ;;
    --model)    [ $# -ge 2 ] || die "--model 缺少参数";    MODEL="$2";    shift 2 ;;
    --file)     [ $# -ge 2 ] || die "--file 缺少参数";     RC_FILE="$2";  shift 2 ;;
    --yes|-y)   ASSUME_YES=1; shift ;;
    --force)    FORCE=1; shift ;;
    -h|--help)  sed -n '2,18p' "$0"; exit 0 ;;
    -*)         die "未知参数 $1" ;;
    *)          PROVIDER="$1"; shift ;;
  esac
done

# 各厂商预设（均为 OpenAI 兼容接口，app.py 用 openai SDK 可直接切换）
load_preset() {
  case "$1" in
    zhipu)
      P_NAME="智谱 GLM"; P_BASE="https://open.bigmodel.cn/api/paas/v4"
      P_MODEL="glm-4-flash"; P_HINT="https://open.bigmodel.cn/usercenter/apikeys" ;;
    deepseek)
      P_NAME="DeepSeek"; P_BASE="https://api.deepseek.com/v1"
      P_MODEL="deepseek-chat"; P_HINT="https://platform.deepseek.com/api_keys" ;;
    qwen)
      P_NAME="通义千问"; P_BASE="https://dashscope.aliyuncs.com/compatible-mode/v1"
      P_MODEL="qwen-plus"; P_HINT="https://bailian.console.aliyun.com/" ;;
    openai)
      P_NAME="OpenAI"; P_BASE="https://api.openai.com/v1"
      P_MODEL="gpt-4o-mini"; P_HINT="https://platform.openai.com/api-keys" ;;
    custom)
      P_NAME="自定义"; P_BASE=""; P_MODEL=""; P_HINT="" ;;
    *)
      return 1 ;;
  esac
}

echo "===== LLM 环境变量配置 ====="
echo ""

if [ -z "$PROVIDER" ]; then
  [ -t 0 ] || die "非交互模式请指定厂商，例如：bash $0 zhipu --key sk-xxx"
  echo "请选择 LLM 厂商："
  echo "  1) 智谱 GLM    (glm-4-flash)"
  echo "  2) DeepSeek    (deepseek-chat)"
  echo "  3) 通义千问    (qwen-plus)"
  echo "  4) OpenAI      (gpt-4o-mini)"
  echo "  5) 自定义（手动输入接口地址与模型）"
  echo ""
  read -r -p "输入编号 [1]: " choice
  case "${choice:-1}" in
    1) PROVIDER=zhipu ;;
    2) PROVIDER=deepseek ;;
    3) PROVIDER=qwen ;;
    4) PROVIDER=openai ;;
    5) PROVIDER=custom ;;
    *) die "无效编号：$choice" ;;
  esac
  echo ""
fi

load_preset "$PROVIDER" || die "不支持的厂商：$PROVIDER（可选 zhipu|deepseek|qwen|openai|custom）"

[ -n "$BASE_URL" ] || BASE_URL="$P_BASE"
[ -n "$MODEL" ] || MODEL="$P_MODEL"

if [ -z "$BASE_URL" ]; then
  [ -t 0 ] || die "custom 模式必须提供 --base-url"
  read -r -p "接口地址（如 https://api.example.com/v1）：" BASE_URL
fi
if [ -z "$MODEL" ]; then
  [ -t 0 ] || die "custom 模式必须提供 --model"
  read -r -p "模型名称：" MODEL
fi

case "$BASE_URL" in
  http://*|https://*) ;;
  *) die "接口地址必须以 http:// 或 https:// 开头：$BASE_URL" ;;
esac

if [ -z "$API_KEY" ] && [ -n "${LLM_API_KEY:-}" ] && [ -t 0 ]; then
  read -r -p "检测到环境变量 LLM_API_KEY，直接复用？(Y/n): " reuse
  case "${reuse:-y}" in y|Y) API_KEY="$LLM_API_KEY" ;; esac
fi
if [ -z "$API_KEY" ]; then
  [ -t 0 ] || die "非交互模式请用 --key 传入 API Key"
  [ -n "$P_HINT" ] && echo "获取 Key：$P_HINT"
  read -r -s -p "请输入 $P_NAME API Key（输入不显示）：" API_KEY
  echo ""
fi

# 去掉粘贴时可能带入的空白字符
CLEANED="$(printf '%s' "$API_KEY" | tr -d '[:space:]')"
[ "$CLEANED" = "$API_KEY" ] || echo "提示：已去除 Key 中的空白字符"
API_KEY="$CLEANED"
[ -n "$API_KEY" ] || die "API Key 不能为空"

# HTTP 头只允许 ASCII，避免把中文占位符写进配置
if printf '%s' "$API_KEY" | LC_ALL=C grep -q '[^!-~]'; then
  [ "$FORCE" -eq 1 ] || die "Key 含非 ASCII 字符（常见于误填中文占位符），请重新输入；确需写入加 --force"
  echo "警告：Key 含非 ASCII 字符，已按 --force 继续写入"
fi

mask_key() {
  local k="$1"
  if [ ${#k} -le 8 ]; then printf '****'; else printf '%s****%s' "${k:0:4}" "${k: -4}"; fi
}

# 已有配置：按标记块整体替换，保证重复执行幂等
if [ -f "$RC_FILE" ] && grep -q '^# >>> llm-env' "$RC_FILE"; then
  echo "$RC_FILE 中已有 llm-env 配置"
  if [ "$ASSUME_YES" -ne 1 ]; then
    [ -t 0 ] || die "已存在配置，非交互模式请加 --yes 覆盖"
    read -r -p "是否覆盖？(y/N): " overwrite
    case "$overwrite" in y|Y) ;; *) echo "跳过"; exit 0 ;; esac
  fi
  TMP="$(mktemp)"
  awk '/^# >>> llm-env/{skip=1} !skip; /^# <<< llm-env/{skip=0}' "$RC_FILE" > "$TMP"
  mv "$TMP" "$RC_FILE"
fi

mkdir -p "$(dirname "$RC_FILE")"
[ -f "$RC_FILE" ] || touch "$RC_FILE"
BACKUP="${RC_FILE}.bak.$(date +%Y%m%d%H%M%S)"
cp "$RC_FILE" "$BACKUP"

{
  echo "# >>> llm-env (managed by scripts/setup-env.sh) >>>"
  printf 'export LLM_API_KEY=%q\n' "$API_KEY"
  printf 'export LLM_BASE_URL=%q\n' "$BASE_URL"
  printf 'export LLM_MODEL=%q\n' "$MODEL"
  echo "# <<< llm-env (managed by scripts/setup-env.sh) <<<"
} >> "$RC_FILE"

case "${SHELL:-}" in
  *zsh*) [ "$RC_FILE" = "$HOME/.bashrc" ] && echo "提示：当前默认 shell 是 zsh，建议改用 --file ~/.zshrc" ;;
esac

echo ""
echo "===== 配置完成 ====="
echo "文件：$RC_FILE"
echo "厂商：$P_NAME"
echo "地址：$BASE_URL"
echo "模型：$MODEL"
echo "Key ：$(mask_key "$API_KEY")"
echo "备份：$BACKUP"
echo ""
echo "生效方式（脚本无法修改父 shell，需手动 source）："
echo "  source $RC_FILE"
echo ""
echo "验证："
echo "  echo \$LLM_API_KEY \$LLM_BASE_URL \$LLM_MODEL"
