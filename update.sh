#!/bin/bash
#
# Xray HTTP 代理 - 更新脚本（简化版）
# 此脚本现在调用主脚本的集成更新功能
#
# 从 v2.1.0 开始，更新功能已集成到主脚本中
# 此脚本保留用于向后兼容
#

set -e

# 颜色定义
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}          🔄 Xray HTTP 代理 - 更新脚本${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo

# 检查主脚本是否存在
if [ ! -f "xray-http-proxy.sh" ]; then
    echo -e "${YELLOW}[WARNING]${NC} 主脚本 xray-http-proxy.sh 不存在"
    echo -e "${YELLOW}[INFO]${NC} 请确保在项目目录中运行此脚本"
    exit 1
fi

# 提示信息
echo -e "${CYAN}[INFO]${NC} 从 v2.1.0 开始，更新功能已集成到主脚本中"
echo -e "${CYAN}[INFO]${NC} 此脚本将调用主脚本的更新功能"
echo
echo -e "${CYAN}[INFO]${NC} 您也可以直接使用以下方式更新："
echo "  • 交互模式: ./xray-http-proxy.sh (选择菜单项 17)"
echo "  • 命令行: ./xray-http-proxy.sh --update"
echo
sleep 2

# 调用主脚本的更新功能
exec ./xray-http-proxy.sh --update
