#!/bin/sh
# --- [ HPCC: 终极稳健版安装脚本 ] ---

RED='\033[31m'; GREEN='\033[32m'; BLUE='\033[34m'; NC='\033[0m'
log() { echo -e "${GREEN}[安装]${NC} $1"; }

# 1. 环境清理与初始化
[ -d "/etc/hpcc" ] && rm -rf /etc/hpcc
mkdir -p /etc/hpcc/bin /etc/hpcc/templates/nodes

# 2. 静态坐标
GH_USER="Vonzhen"
GH_REPO="homeproxy_config"
GH_BRANCH="master"
GH_BASE_URL="https://raw.githubusercontent.com/$GH_USER/$GH_REPO/$GH_BRANCH"

# 3. 交互获取变量
log "开始配置通信指挥部..."
echo "----------------------------------------------"
# 使用 printf 确保提示符在同一行，且不受 shell 解释器引号干扰
printf "请输入 Cloudflare Worker 域名: "; read -r CF_DOMAIN
printf "请输入 Worker Auth Token: "; read -r CF_TOKEN
printf "请输入 Telegram Bot Token: "; read -r TG_TOKEN
printf "请输入 Telegram Chat ID: "; read -r TG_ID
echo "----------------------------------------------"

# 4. 安全写入环境变量 (避免使用 EOF 导致引号冲突)
CONF_FILE="/etc/hpcc/env.conf"
echo "GH_USER='$GH_USER'" > "$CONF_FILE"
echo "GH_REPO='$GH_REPO'" >> "$CONF_FILE"
echo "GH_RAW_URL='$GH_BASE_URL'" >> "$CONF_FILE"
echo "CF_DOMAIN='$CF_DOMAIN'" >> "$CONF_FILE"
echo "CF_TOKEN='$CF_TOKEN'" >> "$CONF_FILE"
echo "TG_BOT_TOKEN='$TG_TOKEN'" >> "$CONF_FILE"
echo "TG_CHAT_ID='$TG_ID'" >> "$CONF_FILE"

# 5. 验证并同步脚本
source "$CONF_FILE"

log "正在从云端拉取核心组件..."
SCRIPTS="hp_download.sh hp_config_update.sh hp_rollback.sh hpcc"

smart_download() {
    local name=$1
    local local_path="/etc/hpcc/bin/$name"
    # 尝试多种路径可能
    wget -qO "$local_path" "$GH_RAW_URL/bin/$name" || \
    wget -qO "$local_path" "$GH_RAW_URL/bin/$name.sh"
    
    if [ -s "$local_path" ]; then
        chmod +x "$local_path"
        return 0
    fi
    return 1
}

for s in $SCRIPTS; do
    log "正在拉取: $s ..."
    if ! smart_download "$s"; then
        echo -e "${RED}❌ $s 下载失败！${NC}"
        exit 1
    fi
done

# 6. 系统挂载
ln -sf /etc/hpcc/bin/hpcc /usr/bin/hpcc
(crontab -l 2>/dev/null | grep -v "hpcc") | crontab -
(crontab -l; echo "0 4 * * * /usr/bin/hpcc sync") | crontab -

echo -e "\n${GREEN}==============================================${NC}"
echo -e "${BLUE}   HPCC 指挥系统安装成功！${NC}"
echo -e "----------------------------------------------"
echo -e " 指令集已就绪，请输入: ${YELLOW}hpcc sync${NC}"
echo -e "${GREEN}==============================================${NC}\n"
