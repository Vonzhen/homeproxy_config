#!/bin/sh
# --- HomeProxy 指挥官：终极整合版 (含 TG 通知 + Reality 补全) ---
source /etc/hpcc/env.conf

TMP_CONF="/tmp/homeproxy.new"
JSON_FILE="/tmp/nodes.json"
SNIP_DIR="/tmp/hpcc_snippets"
REGIONS="HK SG TW JP US"

# [情报模块] Telegram 发送函数
send_tg() {
    # 检查变量是否存在，不存在则跳过
    [ -z "$TG_BOT_TOKEN" ] || [ -z "$TG_CHAT_ID" ] && return
    local msg="【指挥官】✅ $1"
    # 使用 curl 异步发送，避免网络波动卡住主脚本
    curl -sk -X POST "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" \
        -d "chat_id=$TG_CHAT_ID" \
        -d "text=$msg" > /dev/null 2>&1 &
}

log() { echo -e "\033[32m[UPDATE]\033[0m $1"; }

# 1. 意图平移逻辑 (原始随机算法)
map_logic() {
    local val=$(echo "$1" | tr -d "' \t\r\n")
    [ "$val" = "direct-out" ] || [ "$val" = "blackhole-out" ] && echo "$val" && return
    local reg=$(echo "$val" | grep -oE "hk|tw|sg|jp|us")
    [ -z "$reg" ] && echo "$val" && return
    local num=$(echo "$val" | grep -oE "[0-9]+" | sed 's/^0//'); [ -z "$num" ] && num=1
    local N=$(grep "^$reg=" /tmp/hp_counts | cut -d'=' -f2)
    [ -z "$N" ] || [ "$N" -eq 0 ] && echo "${reg}01" && return
    local seed=$(hexdump -n 2 -e '/2 "%u"' /dev/urandom)
    if [ "$num" -le 3 ]; then
        local limit=$(( (N + 1) / 2 )); printf "%s%02d" "$reg" "$(( (seed % (limit > 0 ? limit : 1)) + 1 ))"
    else
        local start=$(( N / 2 + 1 )); local range=$(( N - start + 1 )); printf "%s%02d" "$reg" "$(( (seed % (range > 0 ? range : 1)) + (start > N ? N : start) ))"
    fi
}
if [ "$1" = "--map" ]; then map_logic "$2"; exit 0; fi

# 2. 资源获取
mkdir -p $SNIP_DIR
log "📥 正在同步云端底座与积木蓝图..."
wget -qO "$TMP_CONF.base" "$GH_RAW_URL/templates/hp_base.uci"
for type in vless trojan hysteria2 shadowsocks; do
    wget -qO "$SNIP_DIR/$type.snippet" "$GH_RAW_URL/templates/nodes/$type.snippet"
done

# 3. 统计分布 (按 JSON 出现顺序)
log "📊 统计机场分布..."
JSON_DATA=$(cat $JSON_FILE | jq -c '.outbounds')
AIRPORTS=$(echo "$JSON_DATA" | jq -r '.[] | .tag' | awk '{print $2}' | awk -F'-' '{print $1}' | awk '!x[$0]++')

rm -f /tmp/hp_counts
for reg in $REGIONS; do
    count=0; lower_reg=$(echo $reg | tr 'A-Z' 'a-z')
    for ap in $AIRPORTS; do
        nodes=$(echo "$JSON_DATA" | jq -r ".[] | select(.tag | contains(\"$ap\")) | select(.tag | contains(\"$reg\")) | .tag")
        [ -n "$nodes" ] && count=$((count + 1))
    done
    echo "$lower_reg=$count" >> /tmp/hp_counts
done

# 4. 重构底座意图
log "🏗️ 执行意图平移..."
awk -v script="$0" '
{
    if ($0 ~ /option outbound/) {
        if (match($0, /\047[^\047]+\047/)) {
            old_v = substr($0, RSTART+1, RLENGTH-2);
            cmd = "sh " script " --map " old_v;
            cmd | getline new_v; close(cmd);
            sub(/\047[^\047]+\047/, "\047" new_v "\047", $0);
        }
    }
    print $0
}' "$TMP_CONF.base" > "$TMP_CONF"

# 5. 生成策略组 (垂直隔离版)
log "🧵 生成策略组..."
for reg in $REGIONS; do
    idx=1; lower_reg=$(echo $reg | tr 'A-Z' 'a-z')
    case "$reg" in "HK") flag="🇭🇰" ;; "SG") flag="🇸🇬" ;; "TW") flag="🇹🇼" ;; "JP") flag="🇯🇵" ;; "US") flag="🇺🇸" ;; esac
    for ap in $AIRPORTS; do
        node_tags=$(echo "$JSON_DATA" | jq -r ".[] | select(.tag | contains(\"$ap\")) | select(.tag | contains(\"$reg\")) | .tag")
        if [ -n "$node_tags" ]; then
            G_ID="${lower_reg}$(printf "%02d" $idx)"
            {
                echo ""
                echo "config routing_node '$G_ID'"
                echo -e "\toption label '$flag $reg-$ap'"
                echo -e "\toption node 'urltest'"
                echo -e "\toption enabled '1'"
                echo -e "\toption urltest_tolerance '150'"
                echo -e "\toption urltest_interrupt_exist_connections '1'"
                echo "$node_tags" | while read tag; do
                    nid=$(echo -n "$tag" | md5sum | cut -d' ' -f1)
                    echo -e "\tlist urltest_nodes '$nid'"
                done
            } >> "$TMP_CONF"
            idx=$((idx + 1))
        fi
    done
done

# 6. 生成节点 (蓝图增强 + 格式对齐)
log "🎨 正在注入节点..."
safe_replace() { awk -v p="{{$1}}" -v r="$2" '{gsub(p,r);print}' "$3" > "$3.tmp" && mv "$3.tmp" "$3"; }

echo "$JSON_DATA" | jq -c '.[]' | while read -r row; do
    LABEL=$(echo "$row" | jq -r '.tag'); ID=$(echo -n "$LABEL" | md5sum | cut -d' ' -f1); TYPE=$(echo "$row" | jq -r '.type')
    SNIP="$SNIP_DIR/$TYPE.snippet"
    if [ -f "$SNIP" ]; then
        ITEM_TMP="/tmp/node_$ID.tmp"; cp "$SNIP" "$ITEM_TMP"
        
        RAW_UTLS=$(echo "$row" | jq -r '.tls.utls // empty')
        if echo "$RAW_UTLS" | grep -q "{"; then
            UTLS_VAL=$(echo "$RAW_UTLS" | jq -r '.fingerprint // "chrome"')
        else
            UTLS_VAL="${RAW_UTLS:-chrome}"
        fi
        [ "$UTLS_VAL" = "null" ] && UTLS_VAL="chrome"

        [ "$(echo "$row" | jq -r '.tls.insecure // false')" = "true" ] && INSECURE="1" || INSECURE="0"
        [ "$(echo "$row" | jq -r '.tls.enabled // true')" = "true" ] && TLS="1" || TLS="0"
        FLOW=$(echo "$row" | jq -r '.flow // empty')

        safe_replace "ID" "$ID" "$ITEM_TMP"
        safe_replace "LABEL" "$LABEL" "$ITEM_TMP"
        safe_replace "SERVER" "$(echo "$row" | jq -r '.server')" "$ITEM_TMP"
        safe_replace "PORT" "$(echo "$row" | jq -r '.server_port')" "$ITEM_TMP"
        safe_replace "PASSWORD" "$(echo "$row" | jq -r '.password // empty')" "$ITEM_TMP"
        safe_replace "UUID" "$(echo "$row" | jq -r '.uuid // empty')" "$ITEM_TMP"
        safe_replace "METHOD" "$(echo "$row" | jq -r '.method // empty')" "$ITEM_TMP"
        safe_replace "SNI" "$(echo "$row" | jq -r '.tls.server_name // .server')" "$ITEM_TMP"
        safe_replace "INSECURE" "$INSECURE" "$ITEM_TMP"
        safe_replace "TLS" "$TLS" "$ITEM_TMP"
        safe_replace "UTLS" "$UTLS_VAL" "$ITEM_TMP"
        safe_replace "FLOW" "$FLOW" "$ITEM_TMP"
        
        PK=$(echo "$row" | jq -r '.tls.reality.public_key // empty')
        SID=$(echo "$row" | jq -r '.tls.reality.short_id // empty')
        
        if [ -n "$PK" ] && [ "$PK" != "null" ]; then
            safe_replace "REALITY_ENABLE" "1" "$ITEM_TMP"
            safe_replace "REALITY_PK" "$PK" "$ITEM_TMP"
            safe_replace "REALITY_SID" "$SID" "$ITEM_TMP"
        else
            safe_replace "REALITY_ENABLE" "0" "$ITEM_TMP"
            safe_replace "REALITY_PK" "" "$ITEM_TMP"
            safe_replace "REALITY_SID" "" "$ITEM_TMP"
        fi

        echo "" >> "$TMP_CONF"
        cat "$ITEM_TMP" >> "$TMP_CONF"
        rm -f "$ITEM_TMP"
    fi
done

log "✅ 模拟生成完成：$TMP_CONF"

# 7. [应用与通知] 最终阶段
if [ -s "$TMP_CONF" ]; then
    # 备份并替换正式配置 (这一步建议放在 sync 脚本中，或者在这里直接处理)
    cp /etc/config/homeproxy /etc/config/homeproxy.bak
    mv "$TMP_CONF" /etc/config/homeproxy
    uci commit homeproxy
    
    # 构造简报信息
    REPORT="节点重组完成。机场分布：$(cat /tmp/hp_counts | tr '\n' ' ')"
    log "📡 发送 TG 战报..."
    send_tg "$REPORT"
fi
