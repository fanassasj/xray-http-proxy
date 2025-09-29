#!/bin/bash

echo "🎉 Xray HTTP 代理 - 增强功能演示"
echo "===================================="
echo

echo "✅ 最新功能更新："
echo

echo "🛡️ 白名单管理："
echo "   ✓ 完整的白名单管理界面"
echo "   ✓ 支持添加、删除、清空白名单项目"
echo "   ✓ 支持启用/禁用白名单功能"
echo "   ✓ 实时配置应用和代理重启"
echo "   ✓ IP/CIDR格式验证"
echo

echo "🌐 外部IP支持："
echo "   ✓ 自动获取服务器外部IP地址"
echo "   ✓ 代理监听所有接口 (0.0.0.0)"
echo "   ✓ 支持远程客户端连接"
echo

echo "🎲 随机端口："
echo "   ✓ 自动生成10000-65535范围内的随机端口"
echo "   ✓ 自动检测端口占用避免冲突"
echo "   ✓ 增强安全性，避免端口扫描"
echo

echo "📋 当前代理信息："
if [ -f "proxy-config.env" ]; then
    source proxy-config.env
    echo "   端口: $PROXY_PORT (随机生成)"
    echo "   用户名: $PROXY_USERNAME"
    echo "   密码: $PROXY_PASSWORD"
    echo "   白名单: $([ "$ENABLE_WHITELIST" = true ] && echo "已启用 ($WHITELIST_ITEMS)" || echo "已禁用")"

    # 获取外部IP
    external_ip=$(curl -s --connect-timeout 5 http://checkip.amazonaws.com 2>/dev/null || echo "获取失败")
    external_ip=$(echo "$external_ip" | tr -d '\n')
    echo "   外部IP: $external_ip"
    echo "   本地访问: http://$PROXY_USERNAME:$PROXY_PASSWORD@127.0.0.1:$PROXY_PORT"
    echo "   外部访问: http://$PROXY_USERNAME:$PROXY_PASSWORD@$external_ip:$PROXY_PORT"
else
    echo "   未发现配置文件"
fi
echo

echo "🚀 使用方法："
echo "   # 启动随机端口代理"
echo "   ./start-proxy.sh -d"
echo
echo "   # 指定端口启动"
echo "   ./start-proxy.sh -p 12345 -d"
echo
echo "   # 通过控制中心启动"
echo "   ./xray-control.sh start"
echo
echo "   # 管理白名单"
echo "   ./xray-control.sh 6"
echo

echo "🎭 Playwright 配置示例："
if [ -f "proxy-config.env" ]; then
    source proxy-config.env
    external_ip=$(curl -s --connect-timeout 5 http://checkip.amazonaws.com 2>/dev/null || echo "YOUR_SERVER_IP")
    external_ip=$(echo "$external_ip" | tr -d '\n')
    cat << EOF
   const { chromium } = require('playwright');
   const browser = await chromium.launch({
     proxy: {
       server: 'http://$external_ip:$PROXY_PORT',
       username: '$PROXY_USERNAME',
       password: '$PROXY_PASSWORD'
     }
   });
EOF
else
    echo "   (需要先启动代理获取具体配置)"
fi
echo

echo "🔧 安全特性："
echo "   ✓ 随机端口增强安全性"
echo "   ✓ 自动生成强密码"
echo "   ✓ 支持IP白名单限制客户端访问"
echo "   ✓ 外部访问支持远程自动化"
echo "   ✓ 完整的白名单管理界面"
echo

echo "🎯 完美适用于："
echo "   • 远程 Playwright 自动化测试"
echo "   • 分布式爬虫系统"
echo "   • 云端自动化任务"
echo "   • 安全的HTTP代理服务"
echo "   • 需要动态IP访问控制的场景"
echo

echo "💡 提示: 使用 ./xray-control.sh 获得完整的管理界面！"
echo "📌 新增: 选择选项 6 进入白名单管理界面！"