#!/bin/sh
# --- HPCC 哨兵：监控云端信号 ---
source /etc/hpcc/env.conf

TICK_FILE="/etc/hpcc/last_tick"
DOWNLOAD_SCRIPT="/etc/hpcc/bin/hp_download.sh"

log() { echo -e "\033[36m[哨兵]\033[0m $1"; }

# 1. 获取云端 Tick (适配你的变量名)
REMOTE_TICK=$(curl -skL --connect-timeout 5 "https://$CF_DOMAIN/tg-sync?token=$CF_TOKEN")

# 2. 基础检查
if [ -z "$REMOTE_TICK" ] || [ "$REMOTE_TICK" = "Unauthorized" ]; then
    exit 1
fi

# 3. 比对本地记录
LAST_TICK=$(cat "$TICK_FILE" 2>/dev/null || echo "0")

if [ "$REMOTE_TICK" != "$LAST_TICK" ]; then
    log "🚀 发现新指令 (Tick: $REMOTE_TICK)，通知搬运工..."
    echo "$REMOTE_TICK" > "$TICK_FILE"
    # 执行下载与更新
    sh "$DOWNLOAD_SCRIPT"
fi
