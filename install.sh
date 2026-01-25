#!/bin/sh
# --- [ HPCC: 积木指挥官哨兵版安装脚本 ] ---

RED='\033[31m'; GREEN='\033[32m'; BLUE='\033[34m'; NC='\033[0m'
log() { echo -e "${GREEN}[安装]${NC} $1"; }

# 1. 环境清理
[ -d "/etc/hpcc" ] && rm -rf /etc/hpcc
mkdir -p /etc/hpcc/bin /etc/hpcc/templates/nodes

# 2. 静态仓库坐标
GH_USER="Vonzhen"
GH_REPO="homeproxy_config"
GH_BRANCH="master"
GH_BASE_URL="https://raw.githubusercontent.com/$GH_USER/$GH_REPO/$GH_BRANCH"

# 3. 引导式交互获取变量
log "开始配置指挥系统情报参数..."
exec < /dev/tty
echo "------------------------------------------------"
printf "请输入 Cloudflare Worker 域名: "; read -r CF_DOMAIN
printf "请输入 Worker Auth Token: "; read -r CF_TOKEN
printf "请输入 Telegram Bot Token (跳过请回车): "; read -r TG_TOKEN
printf "请输入 Telegram Chat ID (跳过请回车): "; read -r TG_ID
echo "------------------------------------------------"

# 4. 写入环境变量
CONF_FILE="/etc/hpcc/env.conf"
{
    echo "GH_USER='$GH_USER'"
    echo "GH_REPO='$GH_REPO'"
    echo "GH_RAW_URL='$GH_BASE_URL'"
    echo "CF_DOMAIN='$CF_DOMAIN'"
    echo "CF_TOKEN='$CF_TOKEN'"
    echo "TG_BOT_TOKEN='$TG_TOKEN'"
    echo "TG_CHAT_ID='$TG_ID'"
} > "$CONF_FILE"

# 5. 智能拉取所有脚本 (包含哨兵)
source "$CONF_FILE"
log "正在拉取指挥部核心组件 (含哨兵模块)..."

# 脚本列表增加了 hp_watchdog.sh
SCRIPTS="hp_download.sh hp_config_update.sh hp_rollback.sh hpcc hp_watchdog.sh"

smart_download() {
    local name=$1
    local local_path="/etc/hpcc/bin/$name"
    wget -qO "$local_path" "$GH_RAW_URL/bin/$name" || wget -qO "$local_path" "$GH_RAW_URL/bin/$name.sh"
    [ -s "$local_path" ] && chmod +x "$local_path" && return 0
    return 1
}

for s in $SCRIPTS; do
    log "同步中: $s ..."
    if ! smart_download "$s"; then
        echo -e "${RED}❌ $s 同步失败！${NC}"
        exit 1
    fi
done

# 6. 系统挂载与哨兵巡逻
ln -sf /etc/hpcc/bin/hpcc /usr/bin/hpcc

# 清理旧任务，挂载每分钟一次的哨兵模式
log "激活哨兵巡逻模式 (每分钟探测一次云端信号)..."
(crontab -l 2>/dev/null | grep -v "hpcc") | crontab -
(crontab -l 2>/dev/null; echo "* * * * * /bin/sh /etc/hpcc/bin/hp_watchdog.sh") | crontab -

echo -e "\n${GREEN}==============================================${NC}"
echo -e "${BLUE}   HPCC 哨兵系统部署完毕！${NC}"
echo -e "----------------------------------------------"
echo -e " 系统已进入自适应监控状态。"
echo -e " 你只需在云端修改 Tick，家里即可自动同步。"
echo -e "${GREEN}==============================================${NC}\n"

rm -f "$0"
