#!/bin/sh
# --- [ HPCC: 积木指挥官全自动部署脚本 - 维斯特洛版 ] ---

RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; NC='\033[0m'
log() { echo -e "${GREEN}[指令]${NC} $1"; }

# 1. 领地初创
[ -d "/etc/hpcc" ] && rm -rf /etc/hpcc
mkdir -p /etc/hpcc/bin /etc/hpcc/templates/nodes

# 2. 自动识别家族纹章 (GitHub 仓库坐标)
DEFAULT_USER="Vonzhen"; DEFAULT_REPO="homeproxy_config"; DEFAULT_BRANCH="master"
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

# 3. 领主议事：情报参数配置
log "领主大人，请下达领地情报参数..."
echo "------------------------------------------------"
exec < /dev/tty

# 部署位置提示
echo -e "${BLUE}1. 领地坐标选择${NC}"
printf "   [1] 家  [2] 公司 (默认 1): "; read -r LOC_CHOICE
[ "$LOC_CHOICE" = "2" ] && LOCATION="公司" || LOCATION="家"

# Worker 域名提示
echo -e "\n${BLUE}2. 渡鸦联络域名 (Cloudflare Worker)${NC}"
echo -e "   示例: ${GREEN}sub.name.workers.dev${NC}"
printf "   请输入: "; read -r CF_DOMAIN

# Token 提示
echo -e "\n${BLUE}3. 密语验证 Token${NC}"
printf "   请输入: "; read -r CF_TOKEN

# TG 提示
echo -e "\n${BLUE}4. 战报推送 (Telegram 可选)${NC}"
echo -e "   如果不需要通知，请${YELLOW}直接按回车跳过${NC}"
printf "   请输入 Bot Token: "; read -r TG_TOKEN
printf "   请输入 Chat ID:   "; read -r TG_ID
echo "------------------------------------------------"

# 4. 熔炼配置文件
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
    echo "MODE='got'"  # 锁定权游模式
} > "$CONF_FILE"

# 5. 集结积木纵队 (拉取组件)
source "$CONF_FILE"
log "正在集结您的积木纵队..."
SCRIPTS="hp_download hp_config_update hp_rollback hpcc hp_watchdog"

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

# 6. 挂载指挥部与埋伏哨兵
ln -sf /etc/hpcc/bin/hpcc /usr/bin/hpcc
(crontab -l 2>/dev/null | grep -v "hpcc") | crontab -
(crontab -l 2>/dev/null; echo "* * * * * /bin/sh /etc/hpcc/bin/hp_watchdog.sh") | crontab -

echo -e "\n${GREEN}==============================================${NC}"
echo -e "${BLUE}   HPCC 战略堡垒已筑起！${NC}"
echo -e "----------------------------------------------"
echo -e " 来源：${YELLOW}$GH_USER/$GH_REPO${NC}"
echo -e " 坐标：${YELLOW}【$LOCATION】${NC}"
echo -e " 状态：${GREEN}无面者哨兵已在暗处就位。${NC}"
echo -e "${GREEN}==============================================${NC}\n"

rm -f "$0"
