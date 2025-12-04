#!/bin/bash

# 快速测试脚本 - 测试新功能

echo "=========================================="
echo "  Xray 代理快速测试"
echo "=========================================="
echo

# 1. 语法检查
echo "[1/5] 语法检查..."
if bash -n xray-http-proxy.sh; then
    echo "✓ 语法检查通过"
else
    echo "✗ 语法检查失败"
    exit 1
fi
echo

# 2. 版本检查
echo "[2/5] 版本检查..."
version=$(./xray-http-proxy.sh --version 2>&1)
echo "当前版本: $version"
echo

# 3. 帮助信息
echo "[3/5] 帮助信息..."
if ./xray-http-proxy.sh --help >/dev/null 2>&1; then
    echo "✓ 帮助信息正常"
else
    echo "✗ 帮助信息异常"
fi
echo

# 4. 配置验证
echo "[4/5] 配置验证..."
if [ -f "proxy-config.env" ]; then
    if ./xray-http-proxy.sh --validate-config >/dev/null 2>&1; then
        echo "✓ 配置文件有效"
    else
        echo "⚠ 配置文件可能有问题"
    fi
else
    echo "⚠ 配置文件不存在"
fi
echo

# 5. 功能测试
echo "[5/5] 功能测试..."
echo "测试新增功能..."

# 测试健康检查
if ./xray-http-proxy.sh --health-check >/dev/null 2>&1; then
    echo "✓ 健康检查功能正常"
else
    echo "⚠ 健康检查功能异常（可能服务未运行）"
fi

# 测试流量统计
if ./xray-http-proxy.sh --stats >/dev/null 2>&1; then
    echo "✓ 流量统计功能正常"
else
    echo "⚠ 流量统计功能异常"
fi

echo
echo "=========================================="
echo "  测试完成"
echo "=========================================="
