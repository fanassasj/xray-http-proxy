# SOCKS5 代理使用指南

## 概述

从 v2.3.0 开始，本项目支持 SOCKS5 协议，可以单独使用或与 HTTP 协议同时运行。

## SOCKS5 vs HTTP

| 特性 | HTTP 代理 | SOCKS5 代理 |
|------|----------|-------------|
| 协议支持 | HTTP/HTTPS | 所有 TCP/UDP |
| 性能 | 中等 | 更快 |
| 应用场景 | 浏览器、API | SSH、Git、Docker、游戏 |
| UDP 支持 | ❌ | ✅ |
| 配置复杂度 | 简单 | 简单 |

## 快速开始

### 1. 配置 SOCKS5 代理

```bash
# 启动配置向导
./xray-http-proxy.sh --configure

# 选择协议
# 1) HTTP 代理
# 2) SOCKS5 代理
# 3) HTTP + SOCKS5 双协议 (推荐)

# 选择 2 或 3
```

### 2. 启动代理

```bash
# 使用配置文件启动
./xray-http-proxy.sh --start -d

# 查看状态
./xray-http-proxy.sh --status
```

### 3. 测试连接

```bash
# 使用 curl 测试
curl --socks5 USERNAME:PASSWORD@127.0.0.1:PORT https://httpbin.org/ip

# 使用 Playwright 测试
node test-socks5.js
```

## 应用场景

### 1. Playwright 自动化

**⚠️ 重要限制**: Chromium/Firefox/WebKit **不支持 SOCKS5 代理认证**

**推荐方案**: 使用 HTTP 代理

**Node.js (推荐 - 使用 HTTP):**
```javascript
const { chromium } = require('playwright');

const browser = await chromium.launch({
  proxy: {
    server: 'http://YOUR_IP:HTTP_PORT',  // 使用 HTTP 代理
    username: 'YOUR_USERNAME',
    password: 'YOUR_PASSWORD'
  }
});

const page = await browser.newPage();
await page.goto('https://example.com');
```

**Python (推荐 - 使用 HTTP):**
```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(
        proxy={
            "server": "http://YOUR_IP:HTTP_PORT",  # 使用 HTTP 代理
            "username": "YOUR_USERNAME",
            "password": "YOUR_PASSWORD"
        }
    )
    page = browser.new_page()
    page.goto("https://example.com")
```

**SOCKS5 无认证方案** (不推荐):
```javascript
// 仅当 SOCKS5 代理不需要认证时可用
const browser = await chromium.launch({
  proxy: {
    server: 'socks5://YOUR_IP:SOCKS5_PORT'
    // 不能添加 username 和 password
  }
});
```

**解决方案**:
- ✅ **方案1**: 使用 HTTP 代理（推荐）
- ✅ **方案2**: 配置双协议模式，Playwright 用 HTTP，其他应用用 SOCKS5
- ❌ **不可行**: 直接在 Playwright 中使用带认证的 SOCKS5
```

### 2. SSH 隧道

```bash
# 通过 SOCKS5 代理连接 SSH
ssh -o ProxyCommand="nc -X 5 -x 127.0.0.1:PORT %h %p" user@remote-host
```

### 3. Git 操作

```bash
# 配置 Git 使用 SOCKS5 代理
git config --global http.proxy socks5://USERNAME:PASSWORD@127.0.0.1:PORT
git config --global https.proxy socks5://USERNAME:PASSWORD@127.0.0.1:PORT

# 克隆仓库
git clone https://github.com/user/repo.git
```

### 4. Docker

```bash
# 配置 Docker 使用 SOCKS5 代理
# 编辑 ~/.docker/config.json
{
  "proxies": {
    "default": {
      "httpProxy": "socks5://USERNAME:PASSWORD@127.0.0.1:PORT",
      "httpsProxy": "socks5://USERNAME:PASSWORD@127.0.0.1:PORT"
    }
  }
}
```

### 5. curl 命令

```bash
# 使用 SOCKS5 代理
curl --socks5 USERNAME:PASSWORD@127.0.0.1:PORT https://api.example.com

# 或使用环境变量
export ALL_PROXY=socks5://USERNAME:PASSWORD@127.0.0.1:PORT
curl https://api.example.com
```

### 6. Python requests

```python
import requests

proxies = {
    'http': 'socks5://USERNAME:PASSWORD@127.0.0.1:PORT',
    'https': 'socks5://USERNAME:PASSWORD@127.0.0.1:PORT'
}

response = requests.get('https://httpbin.org/ip', proxies=proxies)
print(response.json())
```

## 双协议模式

推荐使用双协议模式，同时提供 HTTP 和 SOCKS5：

```bash
# 配置示例
PROXY_PROTOCOL=both
PROXY_PORT=13053          # HTTP 端口
PROXY_SOCKS5_PORT=14052   # SOCKS5 端口
```

**优势**:
- 灵活选择协议
- 不同应用使用不同协议
- 最大兼容性

## 性能优化

### SOCKS5 性能更好的原因

1. **协议开销小**: SOCKS5 是传输层代理，HTTP 是应用层
2. **无需解析**: 不需要解析 HTTP 头
3. **直接转发**: 数据包直接转发，无需修改

### 使用建议

- **浏览器/API**: 使用 HTTP 代理（更好的兼容性）
- **SSH/Git/Docker**: 使用 SOCKS5 代理（更好的性能）
- **游戏/P2P**: 使用 SOCKS5 代理（支持 UDP）

## 故障排除

### 1. 连接失败

```bash
# 检查端口是否监听
netstat -tlnp | grep SOCKS5_PORT

# 查看日志
tail -f xray-proxy.log

# 测试本地连接
curl --socks5 USERNAME:PASSWORD@127.0.0.1:PORT https://httpbin.org/ip
```

### 2. 认证失败

- 确认用户名密码正确
- 检查配置文件 `proxy-config.env`
- 重启代理服务

### 3. UDP 不工作

- 确认使用 SOCKS5 协议（HTTP 不支持 UDP）
- 检查防火墙规则
- 确认应用支持 SOCKS5 UDP

## 安全建议

1. **使用强密码**: 自动生成的密码已经足够强
2. **启用 IP 白名单**: 限制客户端访问
3. **定期更换凭据**: 定期重新配置
4. **监控日志**: 检查异常访问

## 配置文件示例

### 仅 SOCKS5
```bash
PROXY_PROTOCOL=socks5
PROXY_PORT=14052
PROXY_SOCKS5_PORT=
PROXY_USERNAME=user_xxx
PROXY_PASSWORD=xxx
```

### HTTP + SOCKS5
```bash
PROXY_PROTOCOL=both
PROXY_PORT=13053
PROXY_SOCKS5_PORT=14052
PROXY_USERNAME=user_xxx
PROXY_PASSWORD=xxx
```

## 常见问题

**Q: Playwright 能用 SOCKS5 代理吗？**
A: **不能使用带认证的 SOCKS5**。Chromium 不支持 SOCKS5 代理认证。请使用 HTTP 代理或配置双协议模式。

**Q: 为什么 Playwright 测试 SOCKS5 失败？**
A: 错误 "Browser does not support socks5 proxy authentication" 是正常的。这是浏览器的限制，不是代理问题。解决方法：
- 使用 HTTP 代理测试
- 配置双协议模式（推荐）

**Q: SOCKS5 比 HTTP 快多少？**
A: 通常快 10-30%，取决于具体应用场景。但 Playwright 必须用 HTTP。

**Q: 可以只用 SOCKS5 吗？**
A: 可以，但 Playwright 等浏览器自动化工具无法使用。建议配置双协议模式。

**Q: UDP 转发有什么用？**
A: 用于 DNS 查询、游戏、视频通话等需要 UDP 的应用。

**Q: 双协议会占用更多资源吗？**
A: 资源占用极小，可以忽略不计。推荐使用双协议模式以获得最大兼容性。

## 更多信息

- [README.md](README.md) - 项目主文档
- [CHANGELOG.md](CHANGELOG.md) - 版本更新日志
- [DEPLOYMENT.md](DEPLOYMENT.md) - 部署指南
