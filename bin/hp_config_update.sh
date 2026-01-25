#!/bin/sh
# --- 严格遵循原始逻辑：底座优先 + 蓝图填空 + 意图平移 ---
source /etc/hpcc/env.conf

# 路径定义
CONF="/etc/config/homeproxy"
BAK_CONF="/etc/config/homeproxy.bak"
TMP_CONF="/tmp/homeproxy.new"
JSON_FILE="/tmp/nodes.json"
SNIPPET_DIR="/tmp/hpcc_snippets"

log() { echo -e "\033[32m[更新]\033[0m $1"; }
send_tg() { [ -n "$TG_BOT_TOKEN" ] && curl -sk -X POST "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" -d "chat_id=$TG_CHAT_ID" -d "text=【指挥官】✅ $1" > /dev/null; }

# 1. 物理备份
[ -f "$CONF" ] && cp "$CONF" "$BAK_CONF" && log "💾 已备份旧配置"

# 2. 拉取云端底座与蓝图
log "🏗️ 正在同步云端底座与积木蓝图..."
mkdir -p $SNIPPET_DIR
wget -qO "$TMP_CONF" "$GH_RAW_URL/templates/hp_base.uci"
# 下载常用的几种蓝图 (可以根据需要增减)
for type in vless trojan hysteria2 shadowsocks; do
    wget -qO "$SNIPPET_DIR/$type.snippet" "$GH_RAW_URL/templates/nodes/$type.snippet"
done

# 3. 节点染色注入逻辑
log "🎨 正在进行节点重塑与染色..."
ALL_NODE_IDS=""
NODES_HK=""; NODES_US=""; NODES_SG=""; NODES_JP=""

# 遍历 JSON 节点并根据蓝图填空
jq -c '.outbounds[]' "$JSON_FILE" | while read -r row; do
    LABEL=$(echo "$row" | jq -r '.tag')
    TYPE=$(echo "$row" | jq -r '.type')
    ID=$(echo -n "$LABEL" | md5sum | cut -c1-8)
    ALL_NODE_IDS="$ALL_NODE_IDS $ID"
    
    # 简单的染色逻辑：根据标签匹配地区
    case "$(echo $LABEL | tr 'A-Z' 'a-z')" in
        *hk*|*香港*) NODES_HK="$NODES_HK $ID" ;;
        *us*|*美国*) NODES_US="$NODES_US $ID" ;;
        *sg*|*新加坡*) NODES_SG="$NODES_SG $ID" ;;
        *jp*|*日本*) NODES_JP="$NODES_JP $ID" ;;
    esac

    # 填空逻辑 (使用 sed 替换蓝图中的占位符)
    SNIP="$SNIPPET_DIR/$TYPE.snippet"
    if [ -f "$SNIP" ]; then
        # 提取字段进行替换
        ITEM_TMP="/tmp/node_$ID.tmp"
        cp "$SNIP" "$ITEM_TMP"
        sed -i "s/{{ID}}/$ID/g; s/{{LABEL}}/$LABEL/g" "$ITEM_TMP"
        sed -i "s/{{SERVER}}/$(echo "$row" | jq -r '.server')/g" "$ITEM_TMP"
        sed -i "s/{{PORT}}/$(echo "$row" | jq -r '.server_port')/g" "$ITEM_TMP"
        # 针对协议的特殊字段 (如 VLESS)
        sed -i "s/{{UUID}}/$(echo "$row" | jq -r '.uuid // empty')/g" "$ITEM_TMP"
        sed -i "s/{{PASSWORD}}/$(echo "$row" | jq -r '.password // empty')/g" "$ITEM_TMP"
        sed -i "s/{{SNI}}/$(echo "$row" | jq -r '.tls.server_name // .server')/g" "$ITEM_TMP"
        
        cat "$ITEM_TMP" >> "$TMP_CONF"
        rm -f "$ITEM_TMP"
    fi
done

# 4. 意图平移：回填策略组并实现随机兜底
log "🧵 正在缝合策略组..."
# 提取底座中的所有 routing_node ID
GROUPS=$(grep "config routing_node" "$TMP_CONF" | awk -F"'" '{print $2}')

for gid in $GROUPS; do
    # 根据 ID 决定填入哪组节点
    case "$gid" in
        *hk*) targets="$NODES_HK" ;;
        *us*) targets="$NODES_US" ;;
        *sg*) targets="$NODES_SG" ;;
        *jp*) targets="$NODES_JP" ;;
        *) targets="" ;;
    esac

    # 随机兜底逻辑：如果该组没匹配到节点，则从全量节点中随机抽 3 个
    if [ -z "$targets" ]; then
        log "⚠️ 策略组 $gid 未匹配，启动随机兜底..."
        targets=$(echo "$ALL_NODE_IDS" | tr ' ' '\n' | shuf -n 3 | tr '\n' ' ')
    fi

    # 注入到配置中
    for nid in $targets; do
        sed -i "/config routing_node '$gid'/a \    list urltest_nodes '$nid'" "$TMP_CONF"
    done
done

# 5. 落盘与通知
if [ -s "$TMP_CONF" ]; then
    mv "$TMP_CONF" "$CONF"
    uci commit homeproxy
    log "🚀 重构完成！"
    send_tg "指挥部指令已执行：底座架构与节点已重塑完成，请前往路由器手动应用。"
fi
