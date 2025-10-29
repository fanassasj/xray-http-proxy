#!/bin/bash
#
# Xray HTTP 代理 - 一键更新脚本
# 用于快速更新项目到最新版本
#

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否在项目目录
if [ ! -f "xray-http-proxy.sh" ]; then
    log_error "请在 xray-http-proxy 项目目录中运行此脚本"
    exit 1
fi

echo "═══════════════════════════════════════════════════════════════"
echo "          🔄 Xray HTTP 代理 - 一键更新脚本"
echo "═══════════════════════════════════════════════════════════════"
echo

# 1. 检查 Git 仓库
if [ ! -d ".git" ]; then
    log_warning "这不是一个 Git 仓库"
    log_info "如果要使用 Git 更新，请先初始化："
    echo "  git init"
    echo "  git remote add origin <仓库地址>"
    echo
    read -p "是否继续手动更新？[y/N]: " manual_update
    if [[ ! "$manual_update" =~ ^[yY]$ ]]; then
        log_info "更新已取消"
        exit 0
    fi
else
    # 2. 显示当前状态
    log_info "当前分支: $(git branch --show-current)"
    log_info "最后提交: $(git log -1 --oneline)"
    echo
fi

# 3. 备份配置文件
log_info "正在备份配置文件..."
if [ -f "proxy-config.env" ]; then
    cp proxy-config.env proxy-config.env.backup
    log_success "配置已备份到: proxy-config.env.backup"
else
    log_warning "未找到配置文件，跳过备份"
fi

# 4. 停止代理服务
log_info "正在停止代理服务..."
if ./xray-http-proxy.sh --status >/dev/null 2>&1; then
    ./xray-http-proxy.sh --stop
    log_success "服务已停止"
else
    log_info "服务未运行，跳过停止"
fi

# 5. 拉取更新（如果是 Git 仓库）
if [ -d ".git" ]; then
    log_info "正在拉取最新代码..."

    # 保存本地更改（如果有）
    if [ -n "$(git status --porcelain)" ]; then
        log_warning "检测到本地更改，正在暂存..."
        git stash
        STASHED=true
    fi

    # 拉取更新
    if git pull origin $(git branch --show-current); then
        log_success "代码已更新"
    else
        log_error "代码拉取失败"
        if [ "$STASHED" = true ]; then
            log_info "恢复本地更改..."
            git stash pop
        fi
        exit 1
    fi

    # 恢复本地更改
    if [ "$STASHED" = true ]; then
        log_info "恢复本地更改..."
        if git stash pop; then
            log_success "本地更改已恢复"
        else
            log_warning "恢复时发现冲突，请手动解决"
            log_info "查看冲突文件: git status"
            log_info "解决后执行: git add . && git commit"
        fi
    fi
fi

# 6. 恢复配置文件
if [ -f "proxy-config.env.backup" ]; then
    log_info "正在恢复配置文件..."
    cp proxy-config.env.backup proxy-config.env
    chmod 600 proxy-config.env
    log_success "配置已恢复"
fi

# 7. 赋予执行权限
log_info "正在设置脚本权限..."
chmod +x xray-http-proxy.sh
log_success "权限已设置"

# 8. 验证配置
log_info "正在验证配置..."
if [ -f "proxy-config.env" ]; then
    if ./xray-http-proxy.sh --validate-config >/dev/null 2>&1; then
        log_success "配置验证通过"
    else
        log_error "配置验证失败"
        echo
        ./xray-http-proxy.sh --validate-config
        echo
        log_warning "请修复配置错误后手动启动服务"
        exit 1
    fi
else
    log_warning "未找到配置文件，需要重新配置"
    read -p "是否现在配置？[Y/n]: " do_config
    if [[ ! "$do_config" =~ ^[nN]$ ]]; then
        ./xray-http-proxy.sh --configure
    fi
fi

# 9. 重启服务
log_info "正在重启代理服务..."
if ./xray-http-proxy.sh --start -d; then
    log_success "服务已重启"
else
    log_error "服务启动失败"
    log_info "查看日志: tail -f xray-proxy.log"
    exit 1
fi

# 10. 验证服务状态
sleep 2
echo
log_info "正在验证服务状态..."
./xray-http-proxy.sh --status
echo

# 11. 显示版本信息
if [ -d ".git" ]; then
    echo "═══════════════════════════════════════════════════════════════"
    log_info "当前版本信息:"
    log_info "  分支: $(git branch --show-current)"
    log_info "  提交: $(git log -1 --oneline)"
    log_info "  日期: $(git log -1 --format=%cd --date=short)"
    echo "═══════════════════════════════════════════════════════════════"
fi

echo
log_success "🎉 更新完成！"
echo

# 12. 清理备份（可选）
read -p "是否删除配置备份文件？[y/N]: " cleanup
if [[ "$cleanup" =~ ^[yY]$ ]]; then
    rm -f proxy-config.env.backup
    log_info "备份文件已删除"
fi

exit 0
