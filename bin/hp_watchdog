#!/bin/sh
# --- [ HPCC: 隐形哨兵 - 无面者版 ] ---

[ -f "/etc/hpcc/env.conf" ] || exit 1
source /etc/hpcc/env.conf

TICK_FILE="/etc/hpcc/last_tick"
LOCK_FILE="/tmp/hp_watchdog.lock"

# 1. 屏息：使用文件锁，确保不会有两个无面者同时现身
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    exit 1
fi

# 2. 截获密信：感应云端 Tick 信号
REMOTE_TICK=$(curl -skL --connect-timeout 10 "https://$CF_DOMAIN/tg-sync?token=$CF_TOKEN")

# 3. 身份验证
[ -z "$REMOTE_TICK" ] || [ "$REMOTE_TICK" = "Unauthorized" ] && exit 1

# 4. 命运裁决：只有当密令升级时，才执行任务
LAST_TICK=$(cat "$TICK_FILE" 2>/dev/null || echo "0")

if [ "$REMOTE_TICK" -gt "$LAST_TICK" ] 2>/dev/null; then
    # 占坑：立即更新本地 Tick，深藏功与名
    echo "$REMOTE_TICK" > "$TICK_FILE"
    
    # 5. 执行密令：静默调用搬运工与熔炼炉
    /bin/sh /etc/hpcc/bin/hp_download.sh >/dev/null 2>&1
    /bin/sh /etc/hpcc/bin/hp_config_update.sh >/dev/null 2>&1
fi

# 任务结束，fd 9 自动释放，哨兵再次归于虚无
