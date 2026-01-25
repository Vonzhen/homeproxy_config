#!/bin/sh
# --- 严格遵循原始逻辑：数据下载与校验 ---
source /etc/hpcc/env.conf

TEMP_JSON="/tmp/nodes_download.json"
FINAL_JSON="/tmp/nodes.json"

log() { echo -e "\033[33m[搬运]\033[0m $1"; }

log "📡 正在从云端拉取最新节点..."

# 1. 执行下载
curl -skL --connect-timeout 15 "$WORKER_URL/fetch-nodes?token=$AUTH_TOKEN" -o "$TEMP_JSON"

# 2. 严格校验 JSON 合法性
if [ ! -s "$TEMP_JSON" ]; then
    log "❌ 下载文件为空"
    exit 1
fi

# 使用 jq 检查是否为合法的 JSON 且包含 outbounds
if ! jq empty "$TEMP_JSON" 2>/dev/null; then
    log "❌ JSON 格式损坏"
    rm -f "$TEMP_JSON"
    exit 1
fi

# 3. 校验通过，转正文件
mv "$TEMP_JSON" "$FINAL_JSON"
log "✅ 节点数据已落位 /tmp/nodes.json"

# 接下来，我们可以触发积木 C 进行配置重组
# sh /etc/hpcc/bin/hp_config_update.sh
