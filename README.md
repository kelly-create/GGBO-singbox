# GGBO Sing-box Script

一个基于 Sing-box 的一键安装与管理脚本。支持多种协议配置、SNI 优选等功能。

### ✨ 功能特性

- **一键安装**：支持 Debian/Ubuntu/CentOS/Fedora/ArchLinux 一键部署
- **多协议支持**：集成 VLESS/VMess/Trojan/Hysteria2/Tuic 等主流协议
- **智能 SNI 优选**：内置自动探测工具，智能选择延迟最低的优选域名（支持排序与中文评级）
- **全中文界面**：深度汉化，操作直观友好
- **自动化管理**：内置自动更新、自动证书续期、BBR 加速管理(Caddy) 等。

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
