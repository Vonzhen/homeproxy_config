
---

# HPCC: HomeProxy Config Commander 

HPCC 是一套 [HomeProxy](https://github.com/immortalwrt/homeproxy) 的配置自动化方案。通过 **Sub-Store (处理)** -> **Cloudflare Worker (中转/触发)** -> **HPCC 哨兵 (同步/重组)** 的完整链路，实现节点配置的动态更新与一键回滚。

### ⚙️ 项目操作流程

本项目的运行遵循 **“信号触发 -> 自动同步重组 -> 手动重启生效”** 的安全逻辑：

1. **节点处理**：在 **Sub-Store** 中对订阅进行筛选、去重及重命名（如 `HK-`、`US-` 等前缀），并导出 JSON 链接。
2. **信号触发**：手动执行更新信号。您可以通过 **访问特定 URL**、**iOS 快捷指令** 或 **Telegram 发送 `/update` 指令**，告知 Worker 累加 `Tick` 信号。
3. **本地感应与同步**：
* 部署在路由器的 `hp_watchdog` 哨兵每分钟感应一次 `Tick`。
* 检测到变动后，脚本自动拉取最新节点 JSON，并执行“意图平移”映射算法。
* **自动重组**：脚本会自动更新 HomeProxy 的配置文件（UCI），并完成备份。


4. **手动重启**：配置重组完成后，**手动重启 HomeProxy 服务**（可通过 `hpcc` 面板或系统服务管理），以确保新配置生效并在必要时进行现场调试。
5. **紧急回滚**：如遇新配置不可用，通过 `hpcc` 面板或系统服务管理执行回滚，一键恢复至上一个稳定的配置文件备份。

---

### 🛠 安装与维护指南

#### 1. 前置准备（Worker 部署变量）

在 Cloudflare Worker 部署时，需绑定 **KV 空间**（变量名 `CONFIG_KV`），并在环境变量中配置：

* `SUB_STORE_URL`: Sub-Store 的 JSON 导出链接。
* `CF_TOKEN`: 通信校验密钥。
* `TG_BOT_TOKEN`: 用于接收指令及发送指令。
* `TG_CHAT_ID`: 您的 Telegram 账户 ID。

#### 2. 本地哨兵安装

执行以下命令进行安装（需输入部署位置、域名、Token 及 TG 等变量）：

```bash
rm -rf /etc/hpcc && wget -qO /tmp/i.sh https://raw.githubusercontent.com/Vonzhen/homeproxy_config/master/install.sh && sh /tmp/i.sh

```

#### 3. 常用维护指令

终端输入 **`hpcc`** 进入交互管理面板：

* `1`: **强制同步** - 立即同步配置并根据需要手动重启。
* `2`: **紧急回滚** - 快速恢复上一个稳定备份。
* `u`: **静默升级** - 自动更新脚本代码并保留本地 `env.conf` 参数。
* **注意**：本工具仅维护节点与策略组，**规则集（Rulesets）** 需配合 [hprc](https://www.google.com/search?q=https://github.com/Vonzhen/homeproxy_config/blob/master/bin/hprc) 另行维护。

---

### 🤝 致谢与声明

* **核心引擎**：感谢 [SagerNet/sing-box](https://github.com/SagerNet/sing-box) 提供强大的底层平台。
* **插件支持**：感谢 [immortalwrt/homeproxy](https://github.com/immortalwrt/homeproxy) 提供的优秀核心与 UCI 架构。
* **订阅管理**：感谢 [sub-store-org/Sub-Store](https://github.com/sub-store-org/Sub-Store) 提供的强大处理能力。
* **AI 协助**：本项目由 **Gemini (AI)** 协助实现，涵盖了从架构逻辑设计、Telegram 联动机制到 Shell 脚本自动化重构的全过程。

---
