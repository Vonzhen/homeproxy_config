#!/bin/sh
# --- 严格遵循原始逻辑：物理回滚 ---
source /etc/hpcc/env.conf

CONF="/etc/config/homeproxy"
BAK_CONF="/etc/config/homeproxy.bak"

log() { echo -e "\033[31m[救火]\033[0m $1"; }
send_tg() { [ -n "$TG_BOT_TOKEN" ] && curl -sk -X POST "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" -d "chat_id=$TG_CHAT_ID" -d "text=【指挥官】🚨 警告：系统已执行物理回滚！" > /dev/null; }

if [ -f "$BAK_CONF" ]; then
    log "正在执行物理回滚..."
    cp "$BAK_CONF" "$CONF"
    uci commit homeproxy
    log "✅ 已恢复至备份版本。正在重启服务以自愈..."
    /etc/init.d/homeproxy restart
    send_tg
else
    log "❌ 未发现备份文件 (.bak)，无法自动回滚。"
fi
