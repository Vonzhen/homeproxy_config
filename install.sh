#!/bin/sh
# --- [ HPCC: 积木指挥官哨兵完全体 - 交互优化版 ] ---

RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; NC='\033[0m'
log() { echo -e "${GREEN}[安装]${NC} $1"; }
warn() { echo -e "${YELLOW}[注意]${NC} $1"; }

# 1. 环境初始化（强制清理旧环境，确保纯净安装）
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

# 5. 执行拉取全套组件
source "$CONF_FILE"
log "正在从云端拉取全套指挥组件..."

# 核心脚本清单：增加了 hp_watchdog.sh
SCRIPTS="hp_download.sh hp_config_update.sh hp_rollback.sh hpcc hp_watchdog.sh"

smart_download() {
    local name=$1
    local local_path="/etc/hpcc/bin/$name"
    # 尝试直接下载或带 .sh 后缀下载
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

# 6. 系统挂载与哨兵巡逻配置
ln -sf /etc/hpcc/bin/hpcc /usr/bin/hpcc

log "正在激活【哨兵巡逻模式】(每分钟自动感应云端信号)..."
# 彻底清理旧任务（包含之前的凌晨4点任务），只挂载哨兵每分钟巡逻
(crontab -l 2>/dev/null | grep -v "hpcc") | crontab -
(crontab -l 2>/dev/null; echo "* * * * * /bin/sh /etc/hpcc/bin/hp_watchdog.sh") | crontab -

echo -e "\n${GREEN}==============================================${NC}"
echo -e "${BLUE}   HPCC 哨兵系统部署完毕！${NC}"
echo -e "----------------------------------------------"
echo -e " 指令集已就绪，当前状态：${GREEN}哨兵自感应中${NC}"
echo -e " 云端信号 (Tick) 只要改变，家里就会在 60 秒内自动同步。"
[ -z "$TG_TOKEN" ] && echo -e " 提示: ${YELLOW}未配置 TG 通知，同步将静默执行${NC}"
echo -e "${GREEN}==============================================${NC}\n"

# 自动清理临时安装脚本
rm -f "$0"
