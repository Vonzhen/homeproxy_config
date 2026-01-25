#!/bin/sh
# --- [ HPCC: 积木指挥官哨兵模块 - 稳健版 ] ---

# 1. 载入环境变量
if [ ! -f "/etc/hpcc/env.conf" ]; then
    exit 1
fi
source /etc/hpcc/env.conf

# 2. 路径定义
TICK_FILE="/etc/hpcc/last_tick"
LOCK_FILE="/tmp/hp_watchdog.lock"
DOWNLOAD_SCRIPT="/etc/hpcc/bin/hp_download.sh"
UPDATE_SCRIPT="/etc/hpcc/bin/hp_config_update.sh"

log() { echo -e "\033[36m[哨兵]\033[0m $1"; }

# 3. 防撞锁处理：防止多个哨兵进程同时运行导致系统崩溃
# 使用 fd 9 建立文件锁，若已锁定则直接退出
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    # log "⚠️ 同步任务正在运行中，跳过本次巡逻。"
    exit 1
fi

# 4. 获取云端信号 (归一化后的 10 位时间戳)
# 增加超时限制，防止网络卡死导致进程堆积
REMOTE_TICK=$(curl -skL --connect-timeout 10 "https://$CF_DOMAIN/tg-sync?token=$CF_TOKEN")

# 5. 基础检查
if [ -z "$REMOTE_TICK" ] || [ "$REMOTE_TICK" = "Unauthorized" ]; then
    # log "❌ 信号获取失败，请检查 Worker 域名或 Token"
    exit 1
fi

# 6. 比对本地记录 (数值比对模式)
LAST_TICK=$(cat "$TICK_FILE" 2>/dev/null || echo "0")

# 只有当云端 Tick 大于本地 Tick 时，才视为有效的新指令
if [ "$REMOTE_TICK" -gt "$LAST_TICK" ] 2>/dev/null; then
    log "🚀 发现新指令 (Tick: $REMOTE_TICK)，启动同步流程..."
    
    # 立即更新本地记录，防止在同步期间被重复触发
    echo "$REMOTE_TICK" > "$TICK_FILE"
    
    # 执行下载
    if sh "$DOWNLOAD_SCRIPT"; then
        # 执行配置熔炼与 HomeProxy 重启
        sh "$UPDATE_SCRIPT"
        log "✅ 自动化同步任务执行完毕。"
    else
        log "❌ 下载节点失败，本次同步中止。"
        # 如果下载失败，可以将本地 Tick 改回旧值，以便下一分钟重试
        # echo "$LAST_TICK" > "$TICK_FILE"
    fi
else
    # log "💤 信号未变动 ($REMOTE_TICK)，继续待命。"
    :
fi
