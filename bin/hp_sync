#!/bin/sh
# --- 严格遵循原始逻辑：信号对比 ---
# 自动读取安装时生成的环境变量
source /etc/hpcc/env.conf

TICK_FILE="/etc/hpcc/last_tick"
DOWNLOAD_SCRIPT="/etc/hpcc/bin/hp_download.sh"

log() { echo -e "\033[36m[哨兵]\033[0m $1"; }

# 1. 获取云端 Tick (带 Token 鉴权)
REMOTE_TICK=$(curl -skL --connect-timeout 5 "$WORKER_URL/tg-sync?token=$AUTH_TOKEN")

# 2. 基础检查
if [ -z "$REMOTE_TICK" ] || [ "$REMOTE_TICK" = "Unauthorized" ]; then
    log "❌ 信号获取失败，请检查 Token 或 Worker 状态"
    exit 1
fi

# 3. 比对本地记录
LAST_TICK=$(cat "$TICK_FILE" 2>/dev/null || echo "0")

if [ "$REMOTE_TICK" != "$LAST_TICK" ]; then
    log "🚀 发现新指令 (Tick: $REMOTE_TICK)，通知搬运工..."
    # 保存新信号
    echo "$REMOTE_TICK" > "$TICK_FILE"
    # 触发下载脚本
    sh "$DOWNLOAD_SCRIPT"
else
    log "💤 信号未变动，继续待命"
fi
