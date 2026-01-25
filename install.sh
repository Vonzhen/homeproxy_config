#!/bin/sh
# --- [ HPCC: HomeProxy Cloud Commander 一键安装工程车 ] ---

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
NC='\033[0m'

log() { echo -e "${GREEN}[安装]${NC} $1"; }
warn() { echo -e "${YELLOW}[警告]${NC} $1"; }

# 1. 检查必要依赖
log "检查系统依赖..."
for cmd in jq curl wget awk; do
    if ! command -v $cmd >/dev/null 2>&1; then
        warn "未找到 $cmd，尝试安装..."
        opkg update && opkg install $cmd
    fi
done

# 2. 初始化目录结构
log "初始化目录结构..."
mkdir -p /etc/hpcc/bin
mkdir -p /etc/hpcc/templates/nodes

# 3. 环境变量配置
CONF_FILE="/etc/hpcc/env.conf"
if [ ! -f "$CONF_FILE" ]; then
    log "检测到首次安装，开始配置环境变量..."
    read -p "请输入 GitHub 用户名: " GH_USER
    read -p "请输入 GitHub 仓库名: " GH_REPO
    read -p "请输入 Telegram Bot Token (若无则回车跳过): " TG_TOKEN
    read -p "请输入 Telegram Chat ID (若无则回车跳过): " TG_ID

    cat << EOF > "$CONF_FILE"
GH_USER="$GH_USER"
GH_REPO="$GH_REPO"
GH_RAW_URL="https://raw.githubusercontent.com/$GH_USER/$GH_REPO/master"
TG_BOT_TOKEN="$TG_TOKEN"
TG_CHAT_ID="$TG_ID"
EOF
    log "环境变量已保存至 $CONF_FILE"
else
    log "环境变量配置已存在，跳过手动输入。"
fi

source "$CONF_FILE"

# 4. 从 GitHub 拉取核心脚本
log "正在从云端拉取指挥部核心脚本..."
SCRIPTS="hp_download.sh hp_config_update.sh hp_rollback.sh hpcc"

for s in $SCRIPTS; do
    log "下载中: $s ..."
    wget -qO "/etc/hpcc/bin/$s" "$GH_RAW_URL/bin/$s"
    if [ $? -eq 0 ]; then
        chmod +x "/etc/hpcc/bin/$s"
    else
        echo -e "${RED}❌ 脚本 $s 下载失败，请检查仓库路径！${NC}"
        exit 1
    fi
done

# 5. 创建系统快捷方式
log "创建系统软连接..."
ln -sf /etc/hpcc/bin/hpcc /usr/bin/hpcc

# 6. 配置定时任务 (Cron)
log "配置自动化定时任务..."
# 移除旧的任务防止重复
(crontab -l | grep -v "hpcc") | crontab -
# 添加新任务：每天凌晨 4:00 自动执行一次完整同步
(crontab -l; echo "0 4 * * * /usr/bin/hpcc sync") | crontab -
log "已挂载：每天凌晨 04:00 自动同步云端节点及配置。"

# 7. 完成安装
echo -e "\n${GREEN}==============================================${NC}"
echo -e "${BLUE}   HPCC 指挥系统安装成功！${NC}"
echo -e "----------------------------------------------"
echo -e " 现在你可以直接输入: ${YELLOW}hpcc sync${NC} 来开始第一次同步。"
echo -e " 所有的本地配置文件备份在: /etc/config/homeproxy.bak"
echo -e "${GREEN}==============================================${NC}\n"
