#!/bin/sh
# --- [ HPCC: 极致简化的全自动安装工程车 ] ---

# 颜色定义
RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'; BLUE='\033[34m'; NC='\033[0m'

log() { echo -e "${GREEN}[安装]${NC} $1"; }

# 1. 自动解析仓库坐标
# 通过当前脚本的下载路径（如果通过 pipe 执行，这部分需要预设或从 URL 抓取）
# 默认指向你当前的仓库，除非用户手动修改 env.conf
GH_USER="Vonzhen"
GH_REPO="homeproxy_config"
GH_BRANCH="master"

# 2. 初始化环境
mkdir -p /etc/hpcc/bin /etc/hpcc/templates/nodes

# 3. 交互获取最小化变量 (仅 Worker 和 TG)
CONF_FILE="/etc/hpcc/env.conf"
if [ ! -f "$CONF_FILE" ]; then
    log "开始配置通信指挥部..."
    read -p "请输入 Cloudflare Worker 域名: " CF_DOMAIN
    read -p "请输入 Worker Auth Token: " CF_TOKEN
    read -p "请输入 Telegram Bot Token: " TG_TOKEN
    read -p "请输入 Telegram Chat ID: " TG_ID

    cat << EOF > "$CONF_FILE"
GH_USER="$GH_USER"
GH_REPO="$GH_REPO"
GH_RAW_URL="https://raw.githubusercontent.com/$GH_USER/$GH_REPO/$GH_BRANCH"
CF_DOMAIN="$CF_DOMAIN"
CF_TOKEN="$CF_TOKEN"
TG_BOT_TOKEN="$TG_TOKEN"
TG_CHAT_ID="$TG_ID"
EOF
    log "基础通信配置已保存。"
fi

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
    log "拉取中: $s ..."
    if ! smart_download "$s"; then
        echo -e "${RED}❌ $s 下载失败！${NC}"
        exit 1
    fi
done

# 5. 挂载系统与定时任务
ln -sf /etc/hpcc/bin/hpcc /usr/bin/hpcc
(crontab -l | grep -v "hpcc") | crontab -
(crontab -l; echo "0 4 * * * /usr/bin/hpcc sync") | crontab -

log "🎉 安装成功！"
log "👉 现在请输入 'hpcc sync' 发起首轮攻势。"
