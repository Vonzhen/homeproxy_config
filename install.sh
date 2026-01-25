#!/bin/sh
# --- [ HPCC: 积木指挥官全自动安装脚本 - 交互优化版 ] ---

RED='\033[31m'; GREEN='\033[32m'; BLUE='\033[34m'; NC='\033[0m'
log() { echo -e "${GREEN}[安装]${NC} $1"; }
warn() { echo -e "${YELLOW}[注意]${NC} $1"; }

# 1. 环境初始化
[ -d "/etc/hpcc" ] && rm -rf /etc/hpcc
mkdir -p /etc/hpcc/bin /etc/hpcc/templates/nodes

# 2. 仓库坐标
GH_USER="Vonzhen"
GH_REPO="homeproxy_config"
GH_BRANCH="master"
GH_BASE_URL="https://raw.githubusercontent.com/$GH_USER/$GH_REPO/$GH_BRANCH"

# 3. 引导式交互获取变量
log "开始配置指挥系统情报参数..."
echo "------------------------------------------------"

# 强制重定向输入流以支持管道安装模式
exec < /dev/tty

# 域名格式引导
echo -e "${BLUE}1. Cloudflare Worker 域名${NC}"
echo -e "   格式示例: ${GREEN}sub.yourname.workers.dev${NC} (不要带 http://)"
printf "   请输入: "; read -r CF_DOMAIN

# Token 引导
echo -e "\n${BLUE}2. Worker 验证 Token${NC}"
printf "   请输入: "; read -r CF_TOKEN

# TG 通知引导 (可选)
echo -e "\n${BLUE}3. Telegram 通知推送 (可选)${NC}"
echo -e "   如果不需要通知，请${YELLOW}直接按回车跳过${NC}"
printf "   请输入 Bot Token: "; read -r TG_TOKEN
printf "   请输入 Chat ID:   "; read -r TG_ID

echo -e "------------------------------------------------"

# 4. 安全写入环境变量
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

# 5. 执行拉取
source "$CONF_FILE"
log "正在从云端拉取核心脚本组件..."

SCRIPTS="hp_download.sh hp_config_update.sh hp_rollback.sh hpcc"

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
        echo -e "${RED}❌ $s 同步失败，请检查仓库 bin/ 目录${NC}"
        exit 1
    fi
done

# 6. 系统挂载与定时任务
ln -sf /etc/hpcc/bin/hpcc /usr/bin/hpcc
(crontab -l 2>/dev/null | grep -v "hpcc") | crontab -
(crontab -l 2>/dev/null; echo "0 4 * * * /usr/bin/hpcc sync") | crontab -

echo -e "\n${GREEN}==============================================${NC}"
echo -e "${BLUE}   HPCC 指挥系统部署完毕！${NC}"
echo -e "----------------------------------------------"
echo -e " 指令集已就绪，请输入: ${YELLOW}hpcc sync${NC}"
[ -z "$TG_TOKEN" ] && echo -e " 提示: ${YELLOW}未配置 TG 通知，同步结果将仅在本地显示${NC}"
echo -e "${GREEN}==============================================${NC}\n"

# 自动清理安装脚本
rm -f "$0"
