# Xray HTTP 代理部署指南

本文档说明如何在新服务器上部署和更新此项目。

---

## 📦 首次部署

### 1. 准备服务器环境

**最低要求**:
- 操作系统: Linux (Ubuntu/Debian/CentOS 等)
- 内存: 512MB+
- 磁盘: 100MB+
- 权限: root 或 sudo

**必需工具**:
```bash
# 确保已安装 git 和 curl
apt update && apt install -y git curl      # Ubuntu/Debian
yum install -y git curl                    # CentOS/RHEL
```

---

### 2. 克隆项目

#### 方案 A: 从 GitHub/GitLab 克隆

```bash
# 克隆项目（替换为你的实际仓库地址）
git clone https://github.com/your-username/xray-http-proxy.git

# 进入项目目录
cd xray-http-proxy

# 赋予脚本执行权限
chmod +x xray-http-proxy.sh
```

#### 方案 B: 从本地服务器传输

```bash
# 在源服务器上打包项目（排除配置文件和日志）
cd /home/admin
tar --exclude='xray-http-proxy/proxy-config.env' \
    --exclude='xray-http-proxy/*.log' \
    --exclude='xray-http-proxy/xray-proxy-config.json' \
    --exclude='xray-http-proxy/node_modules' \
    -czf xray-http-proxy.tar.gz xray-http-proxy/

# 传输到目标服务器
scp xray-http-proxy.tar.gz user@target-server:/home/admin/

# 在目标服务器上解压
ssh user@target-server
cd /home/admin
tar -xzf xray-http-proxy.tar.gz
cd xray-http-proxy
chmod +x xray-http-proxy.sh
```

---

### 3. 安装 Xray 核心

```bash
# 使用交互式菜单
./xray-http-proxy.sh
# 选择: 1. 🔧 安装 Xray 核心

# 或使用命令行
./xray-http-proxy.sh --install
```

**验证安装**:
```bash
xray version
# 应该显示: Xray 1.8.x (Xray, Penetrates Everything.)
```

---

### 4. 配置代理

#### 方案 A: 交互式配置（推荐）

```bash
./xray-http-proxy.sh --configure
```

交互式配置会引导你：
1. 设置代理端口（或自动生成）
2. 设置用户名（或自动生成）
3. 设置密码（或自动生成）
4. 配置 IP 白名单（可选）
5. 自动保存到 `proxy-config.env`（权限 600）

#### 方案 B: 使用命令行参数

```bash
./xray-http-proxy.sh --start -p 8080 -u admin -P mypassword -d
```

#### 方案 C: 手动创建配置文件

```bash
cat > proxy-config.env << 'EOF'
# Xray 代理配置文件
PROXY_PORT=8080
PROXY_USERNAME=admin
PROXY_PASSWORD=secure_password_here
ENABLE_WHITELIST=true
WHITELIST_ITEMS="127.0.0.1,YOUR_CLIENT_IP,192.168.1.0/24"
EOF

chmod 600 proxy-config.env
```

---

### 5. 启动代理服务

```bash
# 启动代理（后台运行）
./xray-http-proxy.sh --start -d

# 或使用配置文件启动
./xray-http-proxy.sh
# 选择: 3. 🚀 启动代理服务
```

**验证运行状态**:
```bash
./xray-http-proxy.sh --status
```

---

### 6. 配置开机自启动（可选）

```bash
# 启用开机自启动
./xray-http-proxy.sh --enable-autostart

# 验证自启动状态
./xray-http-proxy.sh --autostart-status
```

对于 systemd 系统，还可以使用：
```bash
systemctl status xray-http-proxy
systemctl enable xray-http-proxy
```

---

## 🔄 更新项目

### 更新方式 1: Git 拉取（推荐）

如果项目托管在 Git 仓库：

```bash
cd /home/admin/xray-http-proxy

# 1. 备份当前配置
cp proxy-config.env proxy-config.env.backup 2>/dev/null || true

# 2. 停止代理服务
./xray-http-proxy.sh --stop

# 3. 拉取最新代码
git pull origin main

# 4. 恢复配置文件（如果被覆盖）
[ -f proxy-config.env.backup ] && cp proxy-config.env.backup proxy-config.env

# 5. 赋予执行权限
chmod +x xray-http-proxy.sh

# 6. 验证配置
./xray-http-proxy.sh --validate-config

# 7. 重启代理
./xray-http-proxy.sh --start -d
```

**一键更新脚本**:
```bash
cat > update.sh << 'SCRIPT'
#!/bin/bash
set -e

echo "🔄 开始更新 Xray HTTP 代理..."

# 备份配置
[ -f proxy-config.env ] && cp proxy-config.env proxy-config.env.backup
echo "✓ 配置已备份"

# 停止服务
./xray-http-proxy.sh --stop 2>/dev/null || true
echo "✓ 服务已停止"

# 拉取更新
git pull origin main
echo "✓ 代码已更新"

# 恢复配置
[ -f proxy-config.env.backup ] && cp proxy-config.env.backup proxy-config.env
echo "✓ 配置已恢复"

# 赋予权限
chmod +x xray-http-proxy.sh

# 验证配置
if ./xray-http-proxy.sh --validate-config; then
    echo "✓ 配置验证通过"
else
    echo "❌ 配置验证失败，请检查配置"
    exit 1
fi

# 重启服务
./xray-http-proxy.sh --start -d
echo "✓ 服务已重启"

echo "🎉 更新完成！"
./xray-http-proxy.sh --status
SCRIPT

chmod +x update.sh
```

使用方法：
```bash
./update.sh
```

---

### 更新方式 2: 手动传输

```bash
# 在源服务器上
cd /home/admin
tar --exclude='xray-http-proxy/proxy-config.env' \
    --exclude='xray-http-proxy/*.log' \
    --exclude='xray-http-proxy/xray-proxy-config.json' \
    --exclude='xray-http-proxy/node_modules' \
    -czf xray-http-proxy-update.tar.gz xray-http-proxy/

# 传输到目标服务器
scp xray-http-proxy-update.tar.gz user@target-server:/tmp/

# 在目标服务器上
cd /home/admin/xray-http-proxy

# 备份配置
cp proxy-config.env proxy-config.env.backup

# 停止服务
./xray-http-proxy.sh --stop

# 解压更新
cd /home/admin
tar -xzf /tmp/xray-http-proxy-update.tar.gz

# 恢复配置
cp xray-http-proxy/proxy-config.env.backup xray-http-proxy/proxy-config.env

# 重启服务
cd xray-http-proxy
chmod +x xray-http-proxy.sh
./xray-http-proxy.sh --start -d
```

---

## 🔍 验证部署

### 1. 检查服务状态

```bash
./xray-http-proxy.sh --status
```

**预期输出**:
```
✓ 代理正在运行 (PID: xxxxx)
```

### 2. 验证配置

```bash
./xray-http-proxy.sh --validate-config
```

**预期输出**:
```
🔍 配置文件验证
✓ 配置验证通过 ✓
🎉 配置文件完全正常！
```

### 3. 查看系统信息

```bash
./xray-http-proxy.sh --info
```

### 4. 测试 Playwright 集成（如果需要）

```bash
# 先安装 Node.js 和 Playwright
npm install
npm install -g playwright

# 运行测试
./xray-http-proxy.sh --test
```

---

## 🛡️ 安全建议

### 1. 保护配置文件

配置文件包含敏感信息（密码），确保权限正确：

```bash
chmod 600 proxy-config.env
ls -la proxy-config.env
# 应该显示: -rw------- (只有所有者可读写)
```

### 2. 使用强密码

```bash
# 生成 16 字符随机密码
openssl rand -base64 16
```

### 3. 配置防火墙

```bash
# 只允许特定 IP 访问代理端口
ufw allow from YOUR_CLIENT_IP to any port 8080
ufw enable
```

### 4. 定期更新

```bash
# 更新 Xray 核心
./xray-http-proxy.sh --install  # 会自动检测并更新

# 更新项目代码
git pull origin main
```

---

## 📋 常用管理命令

```bash
# 启动代理
./xray-http-proxy.sh --start -d

# 停止代理
./xray-http-proxy.sh --stop

# 重启代理
./xray-http-proxy.sh --restart

# 查看状态
./xray-http-proxy.sh --status

# 验证配置
./xray-http-proxy.sh --validate-config

# 管理白名单
./xray-http-proxy.sh --whitelist

# 查看日志
tail -f xray-proxy.log

# 查看帮助
./xray-http-proxy.sh --help
```

---

## 🐛 故障排查

### 问题 1: 代理无法启动

**检查日志**:
```bash
tail -50 xray-proxy.log
```

**常见原因**:
- 端口被占用: `lsof -i :端口号`
- Xray 未安装: `xray version`
- 配置文件错误: `./xray-http-proxy.sh --validate-config`

### 问题 2: 连接被阻止

**检查白名单**:
```bash
cat proxy-config.env | grep WHITELIST
```

**查看路由日志**:
```bash
tail -f xray-proxy.log | grep "blocked"
```

**临时禁用白名单测试**:
```bash
# 编辑配置文件
nano proxy-config.env
# 设置: ENABLE_WHITELIST=false
# 重启服务
./xray-http-proxy.sh --restart
```

### 问题 3: Git 更新冲突

```bash
# 保存本地更改
git stash

# 拉取更新
git pull origin main

# 恢复本地更改
git stash pop

# 如果有冲突，手动解决后提交
git add .
git commit -m "Merge local changes"
```

---

## 📚 相关文档

- **README.md** - 项目介绍和快速开始
- **OPTIMIZATION_SUMMARY.md** - 优化说明
- **AUTOSTART_GUIDE.md** - 开机自启动详细指南
- **CHANGELOG.md** - 版本更新日志
- **PROJECT_COMPLETION_REPORT.md** - 项目完成度报告

---

## 🆘 获取帮助

如果遇到问题：

1. 查看文档: `./xray-http-proxy.sh --help`
2. 验证配置: `./xray-http-proxy.sh --validate-config`
3. 查看日志: `tail -f xray-proxy.log`
4. 查看系统信息: `./xray-http-proxy.sh --info`

---

**最后更新**: 2025-10-29
**版本**: v2.0.0
**项目主页**: [GitHub 仓库地址]
