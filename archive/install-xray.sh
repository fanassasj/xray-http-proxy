#!/bin/bash

# Xray 安装脚本
# 支持 Linux x64, arm64 和 macOS

set -e

XRAY_VERSION="v1.8.6"
INSTALL_DIR="/usr/local/bin"
TEMP_DIR="/tmp/xray-install"
CONFIG_DIR="$HOME/.config/xray"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
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

# 检测系统架构
detect_arch() {
    local arch
    arch=$(uname -m)
    case $arch in
        x86_64)
            echo "64"
            ;;
        aarch64|arm64)
            echo "arm64-v8a"
            ;;
        armv7l)
            echo "arm32-v7a"
            ;;
        *)
            log_error "不支持的架构: $arch"
            exit 1
            ;;
    esac
}

# 检测操作系统
detect_os() {
    local os
    os=$(uname -s)
    case $os in
        Linux)
            echo "linux"
            ;;
        Darwin)
            echo "macos"
            ;;
        *)
            log_error "不支持的操作系统: $os"
            exit 1
            ;;
    esac
}

# 检查是否有 root 权限
check_root() {
    if [ "$EUID" -ne 0 ] && [ ! -w "$INSTALL_DIR" ]; then
        log_warning "没有写入 $INSTALL_DIR 的权限"
        log_info "将安装到 $HOME/.local/bin"
        INSTALL_DIR="$HOME/.local/bin"
        mkdir -p "$INSTALL_DIR"

        # 添加到 PATH
        if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
            log_info "已添加 $HOME/.local/bin 到 PATH，请重新加载 shell 或运行: source ~/.bashrc"
        fi
    fi
}

# 下载并安装 Xray
install_xray() {
    local os arch download_url filename

    os=$(detect_os)
    arch=$(detect_arch)

    filename="Xray-${os}-${arch}.zip"
    download_url="https://github.com/XTLS/Xray-core/releases/download/${XRAY_VERSION}/${filename}"

    log_info "检测到系统: $os-$arch"
    log_info "下载 Xray $XRAY_VERSION..."

    # 创建临时目录
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"

    # 下载
    if command -v wget >/dev/null 2>&1; then
        wget -O "$filename" "$download_url"
    elif command -v curl >/dev/null 2>&1; then
        curl -L -o "$filename" "$download_url"
    else
        log_error "需要 wget 或 curl 来下载文件"
        exit 1
    fi

    # 解压
    if command -v unzip >/dev/null 2>&1; then
        unzip -q "$filename"
    else
        log_error "需要 unzip 来解压文件"
        exit 1
    fi

    # 安装
    chmod +x xray
    mv xray "$INSTALL_DIR/"

    # 创建配置目录
    mkdir -p "$CONFIG_DIR"

    log_success "Xray 安装完成: $INSTALL_DIR/xray"

    # 清理
    cd /
    rm -rf "$TEMP_DIR"
}

# 验证安装
verify_installation() {
    if command -v xray >/dev/null 2>&1; then
        local version
        version=$(xray version 2>/dev/null | head -n1 || echo "未知版本")
        log_success "Xray 安装验证成功"
        log_info "版本: $version"
    else
        log_error "Xray 安装验证失败"
        log_info "请确保 $INSTALL_DIR 在您的 PATH 中"
        exit 1
    fi
}

# 安装后配置向导
post_install_configure() {
    echo
    log_info "🎉 Xray 安装成功！"
    echo

    # 检查是否有配置脚本
    if [ -f "./configure-proxy.sh" ]; then
        local configure_now
        echo "现在您可以配置并启动您的 HTTP 代理服务器"
        read -p "是否现在进行代理配置？[Y/n]: " configure_now

        case "$configure_now" in
            [nN]|[nN][oO])
                echo
                log_info "您可以稍后运行以下命令进行配置:"
                log_info "  ./configure-proxy.sh"
                log_info "或者手动启动代理:"
                log_info "  ./start-proxy.sh -p 8080"
                ;;
            *)
                echo
                log_info "启动配置向导..."
                chmod +x ./configure-proxy.sh
                ./configure-proxy.sh
                ;;
        esac
    else
        log_warning "未找到配置脚本，请手动配置代理"
        log_info "您可以使用以下命令启动代理:"
        log_info "  ./start-proxy.sh -p 8080"
    fi
}

# 主函数
main() {
    log_info "开始安装 Xray..."

    check_root
    install_xray
    verify_installation

    log_success "Xray 安装完成！"
    log_info "您现在可以使用 'xray' 命令"
    log_info "配置文件目录: $CONFIG_DIR"

    # 安装后配置向导
    post_install_configure
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi