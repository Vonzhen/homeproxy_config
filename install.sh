#!/bin/sh
# --- [ HPCC: 积木指挥官全自动部署脚本 - 维斯特洛版 ] ---

RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; NC='\033[0m'
log() { echo -e "${GREEN}[指令]${NC} $1"; }

# 1. 领地预备 (保留旧配置，仅清理执行文件)
CONF_FILE="/etc/hpcc/env.conf"
[ -d "/etc/hpcc/bin" ] && rm -rf /etc/hpcc/bin
mkdir -p /etc/hpcc/bin /etc/hpcc/templates/nodes

# 2. 锁定家族纹章 (GitHub 仓库坐标)
GH_USER="Vonzhen"
GH_REPO="homeproxy_config"
GH_BRANCH="master"
GH_BASE_URL="https://raw.githubusercontent.com/$GH_USER/$GH_REPO/$GH_BRANCH"

# 3. 智能情报感应：检查是否存在旧有领地密令
if [ -f "$CONF_FILE" ]; then
    source "$CONF_FILE"
    log "🏮 检获现有领地情报，【$LOCATION】战区正在静默整编..."
else
    log "领主大人，未发现旧有密令，请下达领地情报参数..."
    echo "------------------------------------------------"
    exec < /dev/tty

    echo -e "${BLUE}1. 领地坐标选择${NC}"
    printf "   [1] 家  [2] 公司 (默认 1): "; read -r LOC_CHOICE
    [ "$LOC_CHOICE" = "2" ] && LOCATION="公司" || LOCATION="家"

    echo -e "\n${BLUE}2. 渡鸦联络域名 (Worker)${NC}"
    printf "   请输入: "; read -r CF_DOMAIN
    echo -e "\n${BLUE}3. 密语验证 Token${NC}"
    printf "   请输入: "; read -r CF_TOKEN
    echo -e "\n${BLUE}4. 战报推送 (TG 可选)${NC}"
    printf "   请输入 Bot Token (跳过请回车): "; read -r TG_TOKEN
    printf "   请输入 Chat ID (跳过请回车):   "; read -r TG_ID
    echo "------------------------------------------------"

    # 熔炼配置文件 (仅在初次安装时写入)
    {
        echo "GH_USER='$GH_USER'"
        echo "GH_REPO='$GH_REPO'"
        echo "GH_RAW_URL='$GH_BASE_URL'"
        echo "CF_DOMAIN='$CF_DOMAIN'"
        echo "CF_TOKEN='$CF_TOKEN'"
        echo "TG_BOT_TOKEN='$TG_TOKEN'"
        echo "TG_CHAT_ID='$TG_ID'"
        echo "LOCATION='$LOCATION'"
        echo "MODE='got'"
    } > "$CONF_FILE"
fi

# 4. 集结积木纵队 (拉取组件)
SCRIPTS="hp_download hp_config_update hp_rollback hpcc hp_watchdog"

smart_download() {
    local name=$1
    local local_path="/etc/hpcc/bin/$name"
    wget -qO "$local_path" "$GH_BASE_URL/bin/$name" || wget -qO "$local_path" "$GH_BASE_URL/bin/$name.sh"
    [ -s "$local_path" ] && chmod +x "$local_path" && return 0
    return 1
}

for s in $SCRIPTS; do
    log "同步中: $s ..."
    smart_download "$s" || { echo -e "${RED}❌ $s 同步失败${NC}"; exit 1; }
done

# 5. 挂载指挥部与埋伏哨兵
ln -sf /etc/hpcc/bin/hpcc /usr/bin/hpcc
(crontab -l 2>/dev/null | grep -v "hpcc") | crontab -
(crontab -l 2>/dev/null; echo "* * * * * /bin/sh /etc/hpcc/bin/hp_watchdog") | crontab -

echo -e "\n${GREEN}==============================================${NC}"
echo -e "${BLUE}   HPCC 战略堡垒整编完毕！${NC}"
echo -e "----------------------------------------------"
echo -e " 领主：${YELLOW}$GH_USER${NC}"
echo -e " 坐标：${YELLOW}【$LOCATION】${NC}"
echo -e " 指引：输入 ${GREEN}'hpcc'${NC} 进入议事厅"
echo -e "${GREEN}==============================================${NC}\n"

rm -f "$0"
