# 项目文件清单

## 核心文件

### 主脚本
- `xray-http-proxy.sh` - 主脚本（127KB，3800+ 行）

### 配置文件
- `proxy-config.env` - 代理配置（自动生成）
- `xray-proxy-config.json` - Xray 配置（自动生成）
- `package.json` - Node.js 依赖
- `package-lock.json` - 依赖锁定

### 测试脚本
- `test-proxy.js` - HTTP 代理测试
- `test-socks5.js` - SOCKS5 代理测试
- `quick-test.sh` - 快速测试脚本

### 工具脚本
- `update.sh` - 更新脚本
- `git-commit.sh` - Git 提交辅助

## 文档

### 主要文档
- `README.md` - 项目主文档
- `CHANGELOG.md` - 版本更新日志
- `FEATURES.md` - 功能特性总览

### 使用指南
- `SOCKS5_GUIDE.md` - SOCKS5 使用指南
- `OPS_GUIDE.md` - 运维管理指南
- `DEPLOYMENT.md` - 部署指南
- `AUTOSTART_GUIDE.md` - 开机自启动指南

## 运行时文件

### 日志和截图
- `xray-proxy.log` - 运行日志
- `playwright-test.png` - HTTP 测试截图
- `socks5-test.png` - SOCKS5 测试截图（可选）

### 进程文件
- `/tmp/xray-proxy.pid` - 进程 ID 文件

## 目录

### 归档
- `archive/` - 旧版本脚本归档
  - `install-xray.sh`
  - `configure-proxy.sh`
  - `start-proxy.sh`
  - `feature-demo.sh`

### 依赖
- `node_modules/` - Node.js 依赖包
  - `playwright/`
  - `playwright-core/`

### Git
- `.git/` - Git 仓库
- `.gitignore` - Git 忽略规则

### 其他
- `.claude/` - Claude 配置

## 文件统计

**总文件数**: ~20 个核心文件
**代码行数**: ~3800 行
**文档数**: 7 个
**测试脚本**: 3 个

## 文件大小

- 主脚本: 127KB
- 文档总计: ~50KB
- 日志文件: 动态增长
- 截图: ~45KB 每个

## 清理建议

### 可以删除
- `playwright-test.png` - 测试截图（可重新生成）
- `socks5-test.png` - 测试截图（可重新生成）
- `xray-proxy.log` - 日志文件（可清理）

### 保留
- 所有 `.sh` 脚本
- 所有 `.js` 测试脚本
- 所有 `.md` 文档
- `proxy-config.env` - 配置文件
- `package.json` - 依赖配置

## 备份建议

**重要文件**:
- `xray-http-proxy.sh`
- `proxy-config.env`
- 所有文档

**备份命令**:
```bash
tar -czf xray-proxy-backup.tar.gz \
  xray-http-proxy.sh \
  proxy-config.env \
  *.md \
  test-*.js \
  package.json
```
