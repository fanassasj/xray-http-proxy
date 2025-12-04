#!/bin/bash

echo "=========================================="
echo "  Xray 代理项目上传脚本"
echo "=========================================="
echo

# 1. 添加所有文件
echo "[1/5] 添加文件..."
git add -A
echo "✓ 文件已添加"
echo

# 2. 显示状态
echo "[2/5] 检查状态..."
git status --short
echo

# 3. 提交
echo "[3/5] 提交更改..."
git commit -m "v2.4.1 - 多协议支持和运维管理功能

新增功能:
- SOCKS5 协议支持
- HTTP + SOCKS5 双协议模式
- 连通性测试
- 系统健康检查
- 日志管理和轮转
- 流量统计
- 完善的运维功能

修复:
- 双协议显示问题
- SOCKS5 测试（改用 curl）
- Playwright 限制说明

文档:
- SOCKS5_GUIDE.md - SOCKS5 使用指南
- OPS_GUIDE.md - 运维管理指南
- FEATURES.md - 功能特性总览
- PROJECT_SUMMARY.md - 项目总结
- FILE_LIST.md - 文件清单

清理:
- 删除 8 个无用文件
- 优化项目结构

版本: v2.4.1
状态: 生产就绪
测试: 全部通过"

echo "✓ 提交完成"
echo

# 4. 创建标签
echo "[4/5] 创建版本标签..."
git tag -a v2.4.1 -m "v2.4.1 - 多协议支持和运维管理功能"
echo "✓ 标签已创建"
echo

# 5. 推送
echo "[5/5] 推送到远程仓库..."
echo "执行以下命令推送:"
echo
echo "  git push origin main"
echo "  git push origin v2.4.1"
echo
echo "或者一次性推送:"
echo
echo "  git push origin main --tags"
echo
echo "=========================================="
echo "  准备完成！"
echo "=========================================="
