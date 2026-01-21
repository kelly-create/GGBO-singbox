# GGBO Sing-box Script

一个基于 Sing-box 的一键安装与管理脚本。支持多种协议配置、SNI 优选等功能。

## ✨ 特性 (Features)

- **一键安装**: 自动化安装 Sing-box 核心及必要依赖。
- **SNI 优选**: [NEW] 集成智能 SNI 优选功能，自动筛选低延迟、支持 HTTP/2 的最佳大厂域名（如 Microsoft, Azure 等），降低被墙风险。
- **协议支持**: 支持 Reality, Hysteria2, VMess, VLESS, Trojan, Shadowsocks 等主流协议。
- **自动管理**: 包含服务管理、日志查看、自动 TLS 配置 (Caddy) 等。

## 🚀 快速开始 (Quick Start)

推荐使用以下一键安装命令：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/kelly-create/GGBO-singbox/master/install.sh)
```

## 🛠️ 使用说明 (Usage)

安装完成后，可使用 `sb` 命令进行管理：

- `sb` : 显示主菜单
- `sb add` : 添加新配置
- `sb change` : 修改现有配置
- `sb info` : 查看配置信息
- `sb update` : 更新脚本或内核
- `sb uninstall` : 卸载脚本

### SNI 优选使用
在添加 (`sb add`) 或修改 (`sb change`) 配置涉及 SNI (serverName) 时，脚本会提供以下选项：
1. **手动输入**: 自定义域名。
2. **自动优选**: 脚本均自动测试并选择最佳域名。
3. **随机选择**: 随机从内置列表中选取。

建议选择 **自动优选** 以获得最佳连接体验。

## ⚙️ 系统支持
- Ubuntu / Debian / CentOS / Alpine 等主流 Linux 发行版
- 架构: AMD64, ARM64

## 📜 免责声明
本脚本仅供学习交流使用，请勿用于非法用途。
