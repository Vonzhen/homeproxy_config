#!/bin/sh
# --- [ Homeproxy 配置文件自动部署脚本 ] ---

RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; NC='\033[0m'
log() { echo -e "${GREEN}[安装]${NC} $1"; }

[ -d "/etc/hpcc" ] && rm -rf /etc/hpcc
mkdir -p /etc/hpcc/bin /etc/hpcc/templates/nodes

# --- 自动解析 GitHub 坐标逻辑 ---
DEFAULT_USER="Vonzhen"; DEFAULT_REPO="homeproxy_config"; DEFAULT_BRANCH="master"

# 捕获 wget 进程中的 URL
RAW_URL=$(ps -w | grep wget | grep "install.sh" | grep -v grep | awk '{for(i=1;i<=NF;i++) if($i ~ /githubusercontent\.com/) print $i}' | head -n 1)

if [ -n "$RAW_URL" ]; then
    GH_USER=$(echo "$RAW_URL" | cut -d'/' -f4)
    GH_REPO=$(echo "$RAW_URL" | cut -d'/' -f5)
    GH_BRANCH=$(echo "$RAW_URL" | cut -d'/' -f6)
    log "📡 自动识别仓库: $GH_USER/$GH_REPO ($GH_BRANCH)"
else
    GH_USER="$DEFAULT_USER"; GH_REPO="$DEFAULT_REPO"; GH_BRANCH="$DEFAULT_BRANCH"
    log "🔔 使用预设仓库: $GH_USER/$GH_REPO"
fi
GH_BASE_URL="https://raw.githubusercontent.com/$GH_USER/$GH_REPO/$GH_BRANCH"
# ------------------------------

log "开始配置系统情报参数..."
echo "------------------------------------------------"
exec < /dev/tty

echo -e "${BLUE}1. 部署位置选择${NC}"
printf "   [1] 家  [2] 公司 (默认 1): "; read -r LOC_CHOICE
[ "$LOC_CHOICE" = "2" ] && LOCATION="公司" || LOCATION="家"

echo -e "\n${BLUE}2. Cloudflare Worker 域名${NC}"
echo -e "   示例: ${GREEN}sub.name.workers.dev${NC}"
printf "   请输入: "; read -r CF_DOMAIN

echo -e "\n${BLUE}3. Worker 验证 Token${NC}"
printf "   请输入: "; read -r CF_TOKEN

echo -e "\n${BLUE}4. Telegram 通知 (可选)${NC}"
printf "   请输入 Bot Token (跳过请回车): "; read -r TG_TOKEN
printf "   请输入 Chat ID (跳过请回车):   "; read -r TG_ID
echo "------------------------------------------------"

CONF_FILE="/etc/hpcc/env.conf"
{
    echo "GH_USER='$GH_USER'"
    echo "GH_REPO='$GH_REPO'"
    echo "GH_RAW_URL='$GH_BASE_URL'"
    echo "CF_DOMAIN='$CF_DOMAIN'"
    echo "CF_TOKEN='$CF_TOKEN'"
    echo "TG_BOT_TOKEN='$TG_TOKEN'"
    echo "TG_CHAT_ID='$TG_ID'"
    echo "LOCATION='$LOCATION'"
} > "$CONF_FILE"

source "$CONF_FILE"
log "正在拉取指挥组件..."
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
    smart_download "$s" || { echo -e "${RED}❌ $s 同步失败${NC}"; exit 1; }
done

ln -sf /etc/hpcc/bin/hpcc /usr/bin/hpcc
(crontab -l 2>/dev/null | grep -v "hpcc") | crontab -
(crontab -l 2>/dev/null; echo "* * * * * /bin/sh /etc/hpcc/bin/hp_watchdog.sh") | crontab -

echo -e "\n${GREEN}==============================================${NC}"
echo -e "${BLUE}   HPCC 哨兵系统部署完毕！${NC}"
echo -e "----------------------------------------------"
echo -e " 来源：${CYAN}$GH_USER/$GH_REPO${NC}"
echo -e " 地点：${YELLOW}【$LOCATION】${NC}"
echo -e " 状态：${GREEN}哨兵自感应中${NC}"
echo -e "${GREEN}==============================================${NC}\n"
rm -f "$0"
