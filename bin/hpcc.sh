#!/bin/sh
# --- HPCC 交互式管理面板 ---
source /etc/hpcc/env.conf

show_menu() {
    clear
    echo -e "\033[36m======================================\033[0m"
    echo -e "    \033[1mHomeProxy 云端指挥官 (HPCC)\033[0m"
    echo -e "\033[36m======================================\033[0m"
    echo -e "  1) 🚀 \033[32m立即同步\033[0m (强制从云端拉取配置)"
    echo -e "  2) 🚨 \033[31m紧急回滚\033[0m (恢复上次备份并重启)"
    echo -e "  3) 📋 \033[33m查看日志\033[0m (查看最近同步状态)"
    echo -e "  4) ⚙️  \033[35m环境配置\033[0m (查看当前变量设置)"
    echo -e "--------------------------------------"
    echo -e "  u) 🆙 检查更新 (从 GitHub 更新脚本)"
    echo -e "  x) 🗑️  完全卸载"
    echo -e "  q) 退出面板"
    echo -e "\033[36m======================================\033[0m"
    printf "请选择操作 [1-q]: "
}

while true; do
    show_menu
    read choice
    case $choice in
        1)
            echo "正在强制同步..."
            sh /etc/hpcc/bin/hp_download.sh && sh /etc/hpcc/bin/hp_config_update.sh
            echo "按回车键返回..."; read ;;
        2)
            sh /etc/hpcc/bin/hp_rollback.sh
            echo "按回车键返回..."; read ;;
        3)
            echo "最近同步 Tick: $(cat /etc/hpcc/last_tick 2>/dev/null)"
            echo "配置修改时间: $(ls -l /etc/config/homeproxy | awk '{print $6,$7,$8}')"
            echo "按回车键返回..."; read ;;
        4)
            cat /etc/hpcc/env.conf
            echo "按回车键返回..."; read ;;
        u)
            echo "正在从 GitHub 重新拉取所有积木..."
            # 这里可以调用 install.sh 的部分逻辑
            echo "按回车键返回..."; read ;;
        x)
            printf "⚠️ 确定要卸载 HPCC 吗？[y/N]: "
            read confirm; [ "$confirm" = "y" ] && sh /etc/hpcc/bin/uninstall.sh && exit
            ;;
        q) exit 0 ;;
        *) echo "无效选择"; sleep 1 ;;
    esac
done
