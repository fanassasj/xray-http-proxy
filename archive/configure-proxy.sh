#!/bin/bash

# 交互式代理配置脚本

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# 配置变量
PROXY_PORT=""
PROXY_USERNAME=""
PROXY_PASSWORD=""
ENABLE_WHITELIST=false
WHITELIST_ITEMS=()
AUTO_START=true

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

log_prompt() {
    echo -e "${CYAN}[INPUT]${NC} $1"
}

log_highlight() {
    echo -e "${MAGENTA}$1${NC}"
}

# 显示配置横幅
show_config_banner() {
    cat << 'EOF'

╔═══════════════════════════════════════════════════════════╗
║                  🚀 Xray 代理配置向导                      ║
║                                                           ║
║   通过简单的步骤配置您的 HTTP 代理服务器                    ║
╚═══════════════════════════════════════════════════════════╝

EOF
}

# 生成随机用户名
generate_username() {
    echo "user_$(openssl rand -hex 6 2>/dev/null || xxd -l 6 -p /dev/urandom || head -c 12 /dev/urandom | base64 | tr -d '=' | tr '+/' 'ab' | head -c 12)"
}

# 生成随机密码
generate_password() {
    local password
    password=$(openssl rand -base64 12 2>/dev/null | tr -d '=\n' | tr '+/' 'ab' | head -c 12)
    if [ -z "$password" ]; then
        password=$(xxd -l 9 -p /dev/urandom 2>/dev/null | tr -d '\n')
    fi
    if [ -z "$password" ]; then
        password=$(head -c 12 /dev/urandom | base64 | tr -d '=\n' | tr '+/' 'ab' | head -c 12)
    fi
    echo -n "$password"
}

# 生成随机端口
generate_random_port() {
    local port
    while true; do
        # 生成10000-65535之间的随机端口
        port=$((RANDOM % 55536 + 10000))

        # 检查端口是否被占用
        if ! netstat -tuln 2>/dev/null | grep -q ":$port " && ! ss -tuln 2>/dev/null | grep -q ":$port "; then
            echo "$port"
            return 0
        fi
    done
}

# 读取用户输入
read_input() {
    local prompt="$1"
    local default="$2"
    local value=""

    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " value
        if [ -z "$value" ]; then
            value="$default"
        fi
    else
        read -p "$prompt: " value
    fi

    echo "$value"
}

# 读取密码输入
read_password() {
    local prompt="$1"
    local default="$2"
    local value=""

    if [ -n "$default" ]; then
        read -s -p "$prompt [自动生成]: " value
        echo >&2  # 只在stderr输出换行，不影响返回值
        if [ -z "$value" ]; then
            value="$default"
        fi
    else
        read -s -p "$prompt: " value
        echo >&2  # 只在stderr输出换行，不影响返回值
    fi

    echo -n "$value"  # 使用echo -n确保没有换行
}

# 读取是否确认
read_confirm() {
    local prompt="$1"
    local default="$2"
    local value=""

    if [ "$default" = "y" ]; then
        read -p "$prompt [Y/n]: " value
        case "$value" in
            [nN]|[nN][oO]) echo "n" ;;
            *) echo "y" ;;
        esac
    else
        read -p "$prompt [y/N]: " value
        case "$value" in
            [yY]|[yY][eE][sS]) echo "y" ;;
            *) echo "n" ;;
        esac
    fi
}

# 验证端口号
validate_port() {
    local port="$1"

    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        return 1
    fi

    # 检查端口是否被占用
    if command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            return 1
        fi
    elif command -v ss >/dev/null 2>&1; then
        if ss -tuln 2>/dev/null | grep -q ":$port "; then
            return 1
        fi
    fi

    return 0
}

# 验证IP地址或网段
validate_ip_or_cidr() {
    local input="$1"

    # 检查是否为有效的IPv4地址
    if [[ "$input" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        # 检查每个数字是否在0-255范围内
        local IFS='.'
        local -a ip_parts=($input)
        for part in "${ip_parts[@]}"; do
            if [[ $part -lt 0 || $part -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi

    # 检查是否为有效的CIDR网段
    if [[ "$input" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        local ip_part="${input%/*}"
        local cidr_part="${input#*/}"

        # 验证IP部分
        if validate_ip_or_cidr "$ip_part"; then
            # 验证CIDR部分
            if [[ $cidr_part -ge 0 && $cidr_part -le 32 ]]; then
                return 0
            fi
        fi
        return 1
    fi

    return 1
}

# 配置代理端口
configure_port() {
    echo
    log_highlight "📍 步骤 1: 配置代理端口"
    echo

    # 生成随机端口作为默认值
    local default_port
    default_port=$(generate_random_port)
    log_info "已生成随机端口: $default_port"
    echo

    while true; do
        PROXY_PORT=$(read_input "请输入代理端口（回车使用随机端口）" "$default_port")

        if validate_port "$PROXY_PORT"; then
            log_success "端口 $PROXY_PORT 可用"
            break
        else
            log_error "端口 $PROXY_PORT 无效或已被占用，请选择其他端口"
            # 重新生成一个随机端口作为建议
            default_port=$(generate_random_port)
            log_info "建议使用随机端口: $default_port"
        fi
    done
}

# 配置认证信息
configure_auth() {
    echo
    log_highlight "🔐 步骤 2: 配置认证信息"
    echo

    # 配置用户名
    local default_username
    default_username=$(generate_username)
    PROXY_USERNAME=$(read_input "请输入用户名" "$default_username")

    echo
    # 配置密码
    local default_password
    default_password=$(generate_password)
    PROXY_PASSWORD=$(read_password "请输入密码" "$default_password")

    log_success "认证信息配置完成"
    echo "  用户名: $PROXY_USERNAME"
    echo "  密码: $PROXY_PASSWORD"
}

# 配置白名单
configure_whitelist() {
    echo
    log_highlight "🛡️  步骤 3: 配置客户端IP白名单"
    echo

    log_info "IP白名单功能可以限制哪些客户端IP地址可以连接到代理"
    log_info "如果不启用IP白名单，所有IP都可以连接到代理"
    log_info "代理本身可以访问所有网站（不限制出站）"
    echo

    local enable_whitelist
    enable_whitelist=$(read_confirm "是否启用客户端IP白名单功能？" "n")

    if [ "$enable_whitelist" = "y" ]; then
        ENABLE_WHITELIST=true

        echo
        log_info "请输入允许连接的客户端IP地址或网段"
        log_info "示例: 127.0.0.1, 192.168.1.100, 192.168.1.0/24"
        log_info "输入空行结束添加"
        echo

        local count=1
        while true; do
            local ip
            ip=$(read_input "客户端IP/网段 #$count (回车结束)")

            if [ -z "$ip" ]; then
                break
            fi

            if validate_ip_or_cidr "$ip"; then
                WHITELIST_ITEMS+=("$ip")
                log_success "已添加: $ip"
                count=$((count + 1))
            else
                log_error "无效的IP地址或网段: $ip"
            fi
        done

        if [ ${#WHITELIST_ITEMS[@]} -eq 0 ]; then
            log_warning "未添加任何白名单项，IP白名单功能将被禁用"
            ENABLE_WHITELIST=false
        else
            log_success "IP白名单配置完成，共添加 ${#WHITELIST_ITEMS[@]} 个项目:"
            for item in "${WHITELIST_ITEMS[@]}"; do
                echo "  - $item"
            done
        fi
    else
        ENABLE_WHITELIST=false
        log_info "IP白名单功能已禁用，所有客户端IP都可以连接代理"
    fi
}

# 显示配置摘要
show_config_summary() {
    echo
    log_highlight "📋 配置摘要"
    echo

    cat << EOF
┌─────────────────────────────────────────────────────────┐
│                      代理配置信息                         │
├─────────────────────────────────────────────────────────┤
│ 代理端口: $PROXY_PORT
│ 用户名:   $PROXY_USERNAME
│ 密码:     $PROXY_PASSWORD
│ 白名单:   $([ "$ENABLE_WHITELIST" = true ] && echo "已启用 - 客户端IP限制 (${#WHITELIST_ITEMS[@]} 项)" || echo "已禁用 - 允许所有IP连接")
│ 代理URL:  http://$PROXY_USERNAME:$PROXY_PASSWORD@<外部IP>:$PROXY_PORT
└─────────────────────────────────────────────────────────┘

EOF

    if [ "$ENABLE_WHITELIST" = true ]; then
        echo "允许的客户端IP:"
        for item in "${WHITELIST_ITEMS[@]}"; do
            echo "  ✓ $item"
        done
        echo
    fi
}

# 启动代理
start_proxy_with_config() {
    log_highlight "🚀 启动代理服务器"
    echo

    if [ ! -f "./start-proxy.sh" ]; then
        log_error "找不到 start-proxy.sh 脚本"
        return 1
    fi

    local proxy_args=("-p" "$PROXY_PORT" "-u" "$PROXY_USERNAME" "-P" "$PROXY_PASSWORD")

    if [ "$ENABLE_WHITELIST" = true ] && [ ${#WHITELIST_ITEMS[@]} -gt 0 ]; then
        local whitelist_str
        whitelist_str=$(IFS=,; echo "${WHITELIST_ITEMS[*]}")
        proxy_args+=("-w" "$whitelist_str")
    fi

    log_info "正在启动代理服务器..."

    if ./start-proxy.sh "${proxy_args[@]}" -d; then
        echo
        log_success "🎉 代理服务器启动成功！"
        echo
        show_usage_info
        return 0
    else
        log_error "代理服务器启动失败"
        return 1
    fi
}

# 显示使用说明
show_usage_info() {
    cat << EOF
$(echo -e "${GREEN}📖 使用说明:${NC}")

$(echo -e "${CYAN}🔗 代理连接信息:${NC}")
  代理地址: 127.0.0.1:$PROXY_PORT
  用户名:   $PROXY_USERNAME
  密码:     $PROXY_PASSWORD
  完整URL:  http://$PROXY_USERNAME:$PROXY_PASSWORD@127.0.0.1:$PROXY_PORT

$(echo -e "${CYAN}🎭 在 Playwright 中使用:${NC}")
  const { chromium } = require('playwright');
  const browser = await chromium.launch({
    proxy: {
      server: 'http://127.0.0.1:$PROXY_PORT',
      username: '$PROXY_USERNAME',
      password: '$PROXY_PASSWORD'
    }
  });

$(echo -e "${CYAN}⚙️  管理命令:${NC}")
  查看状态: ./start-proxy.sh -S
  停止代理: ./start-proxy.sh -s
  重新配置: ./configure-proxy.sh

$(echo -e "${CYAN}🧪 测试代理:${NC}")
  运行测试: ./test-playwright.sh -p $PROXY_PORT

EOF
}

# 保存配置到文件
save_config() {
    local config_file="proxy-config.env"

    cat > "$config_file" << EOF
# Xray 代理配置文件
# 由 configure-proxy.sh 生成

PROXY_PORT=$PROXY_PORT
PROXY_USERNAME=$PROXY_USERNAME
PROXY_PASSWORD=$PROXY_PASSWORD
ENABLE_WHITELIST=$ENABLE_WHITELIST
WHITELIST_ITEMS="$(IFS=,; echo "${WHITELIST_ITEMS[*]}")"
EOF

    log_info "配置已保存到 $config_file"
}

# 主配置流程
main_configure() {
    show_config_banner

    # 检查 Xray 是否已安装
    if ! command -v xray >/dev/null 2>&1; then
        log_error "Xray 未安装，请先运行 ./install-xray.sh"
        exit 1
    fi

    log_info "欢迎使用 Xray 代理配置向导！"
    log_info "我们将通过几个简单步骤配置您的代理服务器"
    echo

    # 配置步骤
    configure_port
    configure_auth
    configure_whitelist

    # 显示摘要
    show_config_summary

    # 确认启动
    echo
    local start_now
    start_now=$(read_confirm "是否立即启动代理服务器？" "y")

    if [ "$start_now" = "y" ]; then
        save_config
        start_proxy_with_config
    else
        save_config
        echo
        log_info "配置已保存，您可以稍后使用以下命令启动代理:"

        local cmd="./start-proxy.sh -p $PROXY_PORT -u '$PROXY_USERNAME' -P '$PROXY_PASSWORD'"
        if [ "$ENABLE_WHITELIST" = true ] && [ ${#WHITELIST_ITEMS[@]} -gt 0 ]; then
            local whitelist_str
            whitelist_str=$(IFS=,; echo "${WHITELIST_ITEMS[*]}")
            cmd="$cmd -w '$whitelist_str'"
        fi
        cmd="$cmd -d"

        echo "  $cmd"
    fi
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main_configure "$@"
fi