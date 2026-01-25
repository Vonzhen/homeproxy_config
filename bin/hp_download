#!/bin/sh
# --- HPCC 下载模块：适配 fetch-nodes 路径 ---
source /etc/hpcc/env.conf

TEMP_JSON="/tmp/nodes_download.json"
FINAL_JSON="/tmp/nodes.json"

log() { echo -e "\033[33m[搬运]\033[0m $1"; }

log "📡 正在从云端拉取最新节点..."

# 1. 执行下载 (使用 CF_DOMAIN 和 CF_TOKEN)
# 修正路径为 /fetch-nodes
curl -skL --connect-timeout 15 "https://$CF_DOMAIN/fetch-nodes?token=$CF_TOKEN" -o "$TEMP_JSON"

# 2. 严格校验
if [ ! -s "$TEMP_JSON" ]; then
    log "❌ 下载文件为空 (请检查 Worker 域名和 Token 是否正确)"
    exit 1
fi

# 检查 JSON 是否合法
if ! jq empty "$TEMP_JSON" 2>/dev/null; then
    log "❌ JSON 格式损坏 (Worker 可能返回了错误页面)"
    rm -f "$TEMP_JSON"
    exit 1
fi

# 3. 校验通过，转正文件
mv "$TEMP_JSON" "$FINAL_JSON"
log "✅ 节点数据已落位 /tmp/nodes.json"
