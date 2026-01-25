#!/bin/sh
# --- [ HPCC: 极致简化的全自动安装工程车 ] ---

# 颜色定义
RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; NC='\033[0m'

log() { echo -e "${GREEN}[安装]${NC} $1"; }
warn() { echo -e "${YELLOW}[警告]${NC} $1"; }

# 1. 强制初始化环境 (清理之前残留的错误 env.conf)
[ -d "/etc/hpcc" ] && rm -rf /etc/hpcc
mkdir -p /etc/hpcc/bin /etc/hpcc/templates/nodes

# 2. 自动定义仓库坐标 (固定为你当前的仓库)
GH_USER="Vonzhen"
GH_REPO="homeproxy_config"
GH_BRANCH="master"
GH_BASE_URL="https://raw.githubusercontent.com/$GH_USER/$GH_REPO/$GH_BRANCH"

# 3. 交互获取核心变量
CONF_FILE="/etc/hpcc/env.conf"
log "开始配置通信指挥部..."
echo -e "${BLUE}----------------------------------------------${NC}"
read -p "请输入 Cloudflare Worker 域名: " CF_DOMAIN
read -p "请输入 Worker Auth Token: " CF_TOKEN
read -p "请输入 Telegram Bot Token: " TG_TOKEN
read -p "请输入 Telegram Chat ID: " TG_ID
echo -e "${BLUE}----------------------------------------------${NC}"

# 写入纯净的环境变量
cat << EOF > "$CONF_FILE"
GH_USER="$GH_USER"
GH_REPO="$GH_REPO"
GH_RAW_URL="$GH_BASE_URL"
CF_DOMAIN="$CF_DOMAIN"
CF_TOKEN="$CF_TOKEN"
TG_BOT_TOKEN="$TG_TOKEN"
TG_CHAT_ID="$TG_ID"
EOF

# 验证文件是否正确写入
source "$CONF_FILE"

# 4. 智能拉取核心组件
log "正在拉取指挥部核心脚本..."
SCRIPTS="hp_download.sh hp_config_update.sh hp_rollback.sh hpcc"

smart_download() {
    local name=$1
    local local_path="/etc/hpcc/bin/$name"
    # 尝试直接下载，如果失败尝试带 .sh 后缀
    wget -qO "$local_path" "$GH_RAW_URL/bin/$name" || wget -qO "$local_path" "$GH_RAW_URL/bin/$name.sh"
    
    if [ -s "$local_path" ]; then
        chmod +x "$local_path"
        return 0
    fi
    return 1
}

for s in $SCRIPTS; do
    log "正在拉取: $s ..."
    if ! smart_download "$s"; then
        echo -e "${RED}❌ $s 下载失败！请检查 GitHub bin 目录下是否存在该文件。${NC}"
        exit 1
    fi
done

# 5. 挂载系统快捷命令与定时任务
ln -sf /etc/hpcc/bin/hpcc /usr/bin/hpcc
(crontab -l | grep -v "hpcc") | crontab -
(crontab -l; echo "0 4 * * * /usr/bin/hpcc sync") | crontab -

echo -e "\n${GREEN}==============================================${NC}"
echo -e "${BLUE}   HPCC 指挥系统安装成功！${NC}"
echo -e "----------------------------------------------"
echo -e " 现在你可以输入: ${YELLOW}hpcc sync${NC} 发起首轮攻势。"
echo -e "${GREEN}==============================================${NC}\n"
