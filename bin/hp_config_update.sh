#!/bin/sh
# --- HPCC 核心重组脚本 (测试版：先生成文件而不强制覆盖) ---
source /etc/hpcc/env.conf

CONF="/etc/config/homeproxy"
BAK_CONF="/etc/config/homeproxy.bak"
TMP_CONF="/tmp/homeproxy.new"
JSON_FILE="/tmp/nodes.json"
SNIP_DIR="/tmp/hpcc_snippets"

log() { echo -e "\033[32m[核心]\033[0m $1"; }

# 1. 环境准备
mkdir -p $SNIP_DIR
log "📥 正在从 GitHub 同步底座与蓝图..."
wget -qO "$TMP_CONF" "$GH_RAW_URL/templates/hp_base.uci"
for type in vless trojan hysteria2 shadowsocks; do
    wget -qO "$SNIP_DIR/$type.snippet" "$GH_RAW_URL/templates/nodes/$type.snippet"
done

# 2. 节点解析与重构
log "🎨 正在解析 JSON 并通过蓝图填空..."
ALL_NODE_IDS=""
NODES_HK=""; NODES_US=""; NODES_SG=""; NODES_JP=""; NODES_TW=""

jq -c '.outbounds[]' "$JSON_FILE" | while read -r row; do
    LABEL=$(echo "$row" | jq -r '.tag')
    TYPE=$(echo "$row" | jq -r '.type')
    ID=$(echo -n "$LABEL" | md5sum | cut -d' ' -f1)
    ALL_NODE_IDS="$ALL_NODE_IDS $ID"

    # 地区归类
    L_LABEL=$(echo $LABEL | tr 'A-Z' 'a-z')
    case "$L_LABEL" in
        *hk*|*香港*) NODES_HK="$NODES_HK $ID" ;;
        *us*|*美国*) NODES_US="$NODES_US $ID" ;;
        *jp*|*日本*) NODES_JP="$NODES_JP $ID" ;;
        *sg*|*新加坡*) NODES_SG="$NODES_SG $ID" ;;
        *tw*|*台湾*) NODES_TW="$NODES_TW $ID" ;;
    esac

    SNIP="$SNIP_DIR/$TYPE.snippet"
    if [ -f "$SNIP" ]; then
        ITEM_TMP="/tmp/node_$ID.tmp"
        cp "$SNIP" "$ITEM_TMP"

        # 逻辑转换
        [ "$(echo "$row" | jq -r '.tls.insecure // false')" = "true" ] && INSECURE="1" || INSECURE="0"
        [ "$(echo "$row" | jq -r '.tls.enabled // true')" = "true" ] && TLS="1" || TLS="0"
        
        # 指纹默认值逻辑
        UTLS=$(echo "$row" | jq -r '.tls.utls // empty')
        [ -z "$UTLS" ] || [ "$UTLS" = "null" ] && UTLS="chrome"

        # 执行替换
        sed -i "s/{{ID}}/$ID/g; s/{{LABEL}}/$LABEL/g" "$ITEM_TMP"
        sed -i "s/{{SERVER}}/$(echo "$row" | jq -r '.server')/g" "$ITEM_TMP"
        sed -i "s/{{PORT}}/$(echo "$row" | jq -r '.server_port')/g" "$ITEM_TMP"
        sed -i "s/{{PASSWORD}}/$(echo "$row" | jq -r '.password // empty')/g" "$ITEM_TMP"
        sed -i "s/{{UUID}}/$(echo "$row" | jq -r '.uuid // empty')/g" "$ITEM_TMP"
        sed -i "s/{{METHOD}}/$(echo "$row" | jq -r '.method // empty')/g" "$ITEM_TMP"
        sed -i "s/{{SNI}}/$(echo "$row" | jq -r '.tls.server_name // .server')/g" "$ITEM_TMP"
        sed -i "s/{{INSECURE}}/$INSECURE/g; s/{{TLS}}/$TLS/g; s/{{UTLS}}/$UTLS/g" "$ITEM_TMP"
        
        # Reality 处理
        PK=$(echo "$row" | jq -r '.tls.reality.public_key // empty')
        [ -n "$PK" ] && sed -i "s/{{REALITY_ENABLE}}/1/g; s/{{REALITY_PK}}/$PK/g" "$ITEM_TMP" || sed -i "s/{{REALITY_ENABLE}}/0/g; s/{{REALITY_PK}}//g" "$ITEM_TMP"

        cat "$ITEM_TMP" >> "$TMP_CONF"
        rm -f "$ITEM_TMP"
    fi
done

# 3. 策略组缝合
log "🧵 正在根据底座 ID 回填节点..."
GROUPS=$(grep "config routing_node" "$TMP_CONF" | awk -F"'" '{print $2}')

for gid in $GROUPS; do
    case "$gid" in
        *hk*) targets="$NODES_HK" ;;
        *us*) targets="$NODES_US" ;;
        *jp*) targets="$NODES_JP" ;;
        *sg*) targets="$NODES_SG" ;;
        *tw*) targets="$NODES_TW" ;;
        *) targets="" ;;
    esac

    # 随机兜底
    [ -z "$targets" ] && targets=$(echo "$ALL_NODE_IDS" | tr ' ' '\n' | shuf -n 3 | tr '\n' ' ')

    for nid in $targets; do
        sed -i "/config routing_node '$gid'/a \    list urltest_nodes '$nid'" "$TMP_CONF"
    done
done

log "✅ 临时文件已生成在: $TMP_CONF"
log "👉 请执行 'cat $TMP_CONF' 查看结果是否符合预期。"
