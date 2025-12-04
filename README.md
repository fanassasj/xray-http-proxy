# Xray HTTP/SOCKS5 代理一体化脚本

一个基于 Xray 核心的多协议代理服务器一体化解决方案，支持 HTTP 和 SOCKS5 协议、Playwright 自动化测试、IP 白名单、随机端口等高级功能。

[![GitHub](https://img.shields.io/badge/GitHub-fanassasj/xray--http--proxy-blue?logo=github)](https://github.com/fanassasj/xray-http-proxy)
[![License](https://img.shields.io/badge/License-MIT-green)](https://github.com/fanassasj/xray-http-proxy/blob/main/LICENSE)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-red?logo=gnu-bash)](https://github.com/fanassasj/xray-http-proxy)

## ✨ 主要特性

- 🚀 **一键安装部署** - 自动安装 Xray 核心和配置代理
- 🌐 **多协议支持** - HTTP、SOCKS5 或双协议同时运行
- 🎲 **随机端口生成** - 自动生成 10000-65535 范围内的随机端口
- 🔐 **自动认证生成** - 自动生成安全的用户名和密码
- 🛡️ **IP 白名单控制** - 支持客户端 IP 访问控制（支持单个 IP 和 CIDR 网段）
- 🎭 **Playwright 集成** - 完美支持 Playwright 自动化测试
- 🌐 **外部 IP 支持** - 自动获取外部 IP，支持远程访问
- 📱 **交互式管理** - 友好的命令行界面和菜单系统
- 🧪 **连通性测试** - 自动测试代理连接状态
- 🏥 **健康检查** - 全面的系统状态检查
- 📊 **流量统计** - 连接数和使用情况统计
- 📜 **日志管理** - 完善的日志查看和清理功能

## 🚀 快速开始

### 下载脚本

```bash
# 方法1: 直接下载
wget https://raw.githubusercontent.com/fanassasj/xray-http-proxy/main/xray-http-proxy.sh
chmod +x xray-http-proxy.sh

# 方法2: 克隆仓库
git clone https://github.com/fanassasj/xray-http-proxy.git
cd xray-http-proxy
chmod +x xray-http-proxy.sh
```

### 基础使用

```bash
# 启动交互式菜单
./xray-http-proxy.sh

# 快速启动代理（随机端口，默认双协议）
./xray-http-proxy.sh --start -d

# 指定端口启动
./xray-http-proxy.sh --start -p 8080 -d

# 启用 IP 白名单
./xray-http-proxy.sh --start -w "127.0.0.1,192.168.1.0/24" -d
```

## 📖 使用说明

### 协议选择

配置时可选择：
1. **HTTP 代理** - 适用于浏览器、Playwright 等
2. **SOCKS5 代理** - 适用于更广泛的应用（SSH、Git、Docker 等）
3. **HTTP + SOCKS5 双协议** - 同时提供两种协议（推荐）

### 命令行选项

```bash
# 交互模式
./xray-http-proxy.sh                    # 启动交互式主菜单

# 快速操作
./xray-http-proxy.sh --install          # 安装 Xray 核心
./xray-http-proxy.sh --configure        # 交互式配置
./xray-http-proxy.sh --start            # 启动代理
./xray-http-proxy.sh --stop             # 停止代理
./xray-http-proxy.sh --status           # 查看状态
./xray-http-proxy.sh --whitelist        # 管理白名单
./xray-http-proxy.sh --test             # 测试 Playwright
```

### 启动参数

```bash
-p, --port PORT        # 代理端口（默认随机生成）
-u, --username USER    # 用户名（默认自动生成）
-P, --password PASS    # 密码（默认自动生成）
-w, --whitelist IPS    # IP白名单，用逗号分隔
-d, --daemon          # 后台运行
```

## 🎭 Playwright 集成

### HTTP 代理示例

**Node.js:**
```javascript
const { chromium } = require('playwright');

const browser = await chromium.launch({
  proxy: {
    server: 'http://YOUR_SERVER_IP:HTTP_PORT',
    username: 'GENERATED_USERNAME',
    password: 'GENERATED_PASSWORD'
  }
});
```

**Python:**
```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(
        proxy={
            "server": "http://YOUR_SERVER_IP:HTTP_PORT",
            "username": "GENERATED_USERNAME",
            "password": "GENERATED_PASSWORD"
        }
    )
```

### SOCKS5 代理示例

**Node.js:**
```javascript
const { chromium } = require('playwright');

const browser = await chromium.launch({
  proxy: {
    server: 'socks5://YOUR_SERVER_IP:SOCKS5_PORT',
    username: 'GENERATED_USERNAME',
    password: 'GENERATED_PASSWORD'
  }
});
```

**Python:**
```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(
        proxy={
            "server": "socks5://YOUR_SERVER_IP:SOCKS5_PORT",
            "username": "GENERATED_USERNAME",
            "password": "GENERATED_PASSWORD"
        }
    )
```

## 🧪 测试代理

```bash
# 测试 HTTP 代理
node test-proxy.js

# 测试 SOCKS5 代理
node test-socks5.js
```

## 🔧 运维管理

### 连通性测试
```bash
# 测试代理是否正常工作
./xray-http-proxy.sh --test-connectivity
```

### 健康检查
```bash
# 全面检查系统状态
./xray-http-proxy.sh --health-check

# 检查项目:
# - Xray 安装状态
# - 配置文件有效性
# - 服务运行状态
# - 端口监听状态
# - 日志文件状态
# - 代理连通性
```

### 日志管理
```bash
# 查看日志
./xray-http-proxy.sh --logs

# 清理日志
./xray-http-proxy.sh --clean-logs

# 日志自动轮转（超过 50MB）
```

### 流量统计
```bash
# 查看使用统计
./xray-http-proxy.sh --stats

# 显示:
# - 总连接数
# - 错误次数
# - 最近活动
# - 连接记录
```

详细运维指南: [OPS_GUIDE.md](OPS_GUIDE.md)

## 🛡️ 安全特性

### IP 白名单

脚本支持基于来源 IP 的访问控制：

- **单个 IP**: `127.0.0.1`
- **IP 范围**: `192.168.1.0/24`
- **多个规则**: `127.0.0.1,192.168.1.0/24,10.0.0.1`

白名单限制**客户端连接**到代理的 IP，但代理本身可以访问所有网站。

### 随机端口

自动生成 10000-65535 范围内的随机端口，增强安全性，避免端口扫描。

### 强密码生成

自动生成 12 位随机密码，包含大小写字母和数字。

## 📋 系统要求

- **操作系统**: Linux / macOS
- **架构支持**: x86_64, i386, ARM32, ARM64
- **Node.js**: 14+ （用于 Playwright 测试，可选）
- **权限**: sudo 权限（仅用于安装 Xray）

## 📦 部署和更新

### 在新服务器上部署

详细的部署指南请查看：**[DEPLOYMENT.md](DEPLOYMENT.md)**

**快速部署**：
```bash
# 1. 克隆项目
git clone https://github.com/your-username/xray-http-proxy.git
cd xray-http-proxy

# 2. 安装 Xray
./xray-http-proxy.sh --install

# 3. 配置代理（选择协议）
./xray-http-proxy.sh --configure

# 4. 启动服务
./xray-http-proxy.sh --start -d

# 5. 启用开机自启动（可选）
./xray-http-proxy.sh --enable-autostart
```

### 更新项目

**方法 1: 使用集成更新功能（推荐）** ⭐
```bash
# 交互模式
./xray-http-proxy.sh
# 选择菜单项 17

# 命令行模式
./xray-http-proxy.sh --update
```

**方法 2: 使用独立更新脚本**
```bash
./update.sh
```

完整的部署和更新指南：**[DEPLOYMENT.md](DEPLOYMENT.md)**

## 🔧 故障排除

### 常见问题

1. **端口被占用**
   ```bash
   # 查看端口使用情况
   netstat -tlnp | grep :PORT
   ```

2. **Xray 安装失败**
   ```bash
   # 手动安装
   ./xray-http-proxy.sh --install
   ```

3. **代理测试失败**
   ```bash
   # 检查代理状态
   ./xray-http-proxy.sh --status

   # 手动测试 HTTP
   curl -x http://USER:PASS@127.0.0.1:PORT https://httpbin.org/ip

   # 手动测试 SOCKS5
   curl --socks5 USER:PASS@127.0.0.1:PORT https://httpbin.org/ip
   ```

### 日志查看

```bash
# 查看 Xray 进程
ps aux | grep xray

# 查看端口监听
netstat -tlnp | grep :PORT

# 查看日志
tail -f xray-proxy.log
```

## 📄 许可证

MIT License

## 📚 完整文档

- **[README.md](README.md)** - 项目介绍和快速开始（本文档）
- **[SOCKS5_GUIDE.md](SOCKS5_GUIDE.md)** - SOCKS5 使用指南
- **[OPS_GUIDE.md](OPS_GUIDE.md)** - 运维管理功能指南
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - 部署和更新指南
- **[AUTOSTART_GUIDE.md](AUTOSTART_GUIDE.md)** - 开机自启动详细指南
- **[CHANGELOG.md](CHANGELOG.md)** - 版本更新日志

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📞 支持

- **GitHub Issues**: [提交问题](https://github.com/fanassasj/xray-http-proxy/issues)
- **Xray 官方**: https://github.com/XTLS/Xray-core
- **Playwright 官方**: https://playwright.dev/

---

⭐ 如果这个项目对你有帮助，请给一个 Star！
