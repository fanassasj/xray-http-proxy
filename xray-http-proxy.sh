#!/bin/bash

# =============================================================================
# Xray HTTP 代理一体化脚本
# 集成了安装、配置、启动、管理、测试等全部功能
# 支持 Playwright 自动化、IP白名单、随机端口等高级功能
#
# GitHub: https://github.com/fanassasj/xray-http-proxy
# 使用方法:
#   chmod +x xray-http-proxy.sh
#   ./xray-http-proxy.sh
# =============================================================================

set -e

# 脚本版本和信息
SCRIPT_VERSION="2.0.0"
SCRIPT_NAME="Xray HTTP 代理一体化脚本"

# 默认配置
DEFAULT_PORT=""  # 将使用随机端口
DEFAULT_USERNAME=""
DEFAULT_PASSWORD=""
DEFAULT_WHITELIST=""
DEFAULT_CONFIG_FILE="xray-proxy-config.json"
DEFAULT_LOG_FILE="xray-proxy.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# 变量
PORT=""  # 将在参数解析后设置
USERNAME=$DEFAULT_USERNAME
PASSWORD=$DEFAULT_PASSWORD
WHITELIST=$DEFAULT_WHITELIST
CONFIG_FILE=$DEFAULT_CONFIG_FILE
DAEMON=false
STOP=false
STATUS=false
PID_FILE="/tmp/xray-proxy.pid"
LOG_FILE="$DEFAULT_LOG_FILE"
CACHED_EXTERNAL_IP=""  # 缓存外部IP，避免重复请求

# 配置变量
PROXY_PORT=""
PROXY_USERNAME=""
PROXY_PASSWORD=""
ENABLE_WHITELIST=false
WHITELIST_ITEMS=()
AUTO_START=true
SYSTEMD_SERVICE_NAME="xray-http-proxy"
SYSTEMD_SERVICE_FILE="/etc/systemd/system/${SYSTEMD_SERVICE_NAME}.service"

# =============================================================================
# 基础工具函数
# =============================================================================

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

log_header() {
    echo -e "${CYAN}$1${NC}"
}

log_menu() {
    echo -e "${WHITE}$1${NC}"
}

log_highlight() {
    echo -e "${MAGENTA}$1${NC}"
}

log_prompt() {
    echo -e "${CYAN}[INPUT]${NC} $1"
}

# =============================================================================
# 核心工具函数
# =============================================================================

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

# 获取服务器外部IP（带缓存）
get_external_ip() {
    # 如果已有缓存，直接返回
    if [ -n "$CACHED_EXTERNAL_IP" ]; then
        echo "$CACHED_EXTERNAL_IP"
        return 0
    fi

    local external_ip
    external_ip=$(curl -s --connect-timeout 5 http://checkip.amazonaws.com 2>/dev/null || \
                 curl -s --connect-timeout 5 http://ipinfo.io/ip 2>/dev/null || \
                 curl -s --connect-timeout 5 http://icanhazip.com 2>/dev/null || \
                 echo "127.0.0.1")
    external_ip=$(echo "$external_ip" | tr -d '\n')

    # 缓存结果
    CACHED_EXTERNAL_IP="$external_ip"
    echo "$external_ip"
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

# 等待用户按键
wait_for_key() {
    echo
    read -p "按回车键继续..." -r
}

# 添加必要的IP到白名单（避免代码重复）
add_essential_ips_to_whitelist() {
    local whitelist_var="$1"  # 传入当前的白名单字符串
    local auto_added=false

    # 添加127.0.0.1
    if [[ ",$whitelist_var," != *",127.0.0.1,"* ]]; then
        if [ -z "$whitelist_var" ]; then
            whitelist_var="127.0.0.1"
        else
            whitelist_var="$whitelist_var,127.0.0.1"
        fi
        log_success "自动添加本地回环地址: 127.0.0.1" >&2
        auto_added=true
    fi

    # 添加服务器外部IP
    local external_ip
    external_ip=$(get_external_ip)
    if [ -n "$external_ip" ] && [[ ",$whitelist_var," != *",$external_ip,"* ]]; then
        if [ -z "$whitelist_var" ]; then
            whitelist_var="$external_ip"
        else
            whitelist_var="$whitelist_var,$external_ip"
        fi
        log_success "自动添加服务器外部IP: $external_ip" >&2
        auto_added=true
    fi

    if [ "$auto_added" = true ]; then
        echo >&2
        log_info "为确保本地测试和管理功能正常，已自动添加必要IP" >&2
    fi

    echo "$whitelist_var"
}

# =============================================================================
# Xray 安装功能
# =============================================================================

# 检测系统架构
detect_arch() {
    local arch
    arch=$(uname -m)
    case $arch in
        x86_64)
            echo "64"
            ;;
        i386|i686)
            echo "32"
            ;;
        armv7l)
            echo "arm32-v7a"
            ;;
        aarch64|arm64)
            echo "arm64-v8a"
            ;;
        *)
            log_error "不支持的系统架构: $arch"
            return 1
            ;;
    esac
}

# 安装 Xray
install_xray() {
    log_header "🔧 安装 Xray 核心"
    echo

    # 检查是否已经安装
    if command -v xray >/dev/null 2>&1; then
        local current_version
        current_version=$(xray version 2>/dev/null | head -n1 | grep -oP 'Xray \K[0-9.]+' || echo "unknown")
        log_warning "Xray 已安装 (版本: $current_version)"

        read -p "是否重新安装？[y/N]: " reinstall
        case "$reinstall" in
            [yY]|[yY][eE][sS])
                log_info "开始重新安装..."
                ;;
            *)
                log_info "保持现有安装"
                return 0
                ;;
        esac
    fi

    # 检测系统架构
    local arch
    arch=$(detect_arch)
    if [ $? -ne 0 ]; then
        return 1
    fi

    log_info "检测到系统架构: $(uname -m) -> $arch"

    # 创建临时目录
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir" || {
        log_error "无法进入临时目录: $temp_dir"
        return 1
    }

    log_info "正在下载 Xray..."

    # 下载 Xray
    local download_url="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-$arch.zip"

    if ! curl -L -o "xray.zip" "$download_url"; then
        log_error "下载失败，请检查网络连接"
        rm -rf "$temp_dir"
        return 1
    fi

    log_info "正在解压..."
    if ! unzip -q xray.zip; then
        log_error "解压失败"
        rm -rf "$temp_dir"
        return 1
    fi

    log_info "正在安装..."

    # 安装到 /usr/local/bin
    if [ ! -d "/usr/local/bin" ]; then
        sudo mkdir -p "/usr/local/bin"
    fi

    sudo mv xray /usr/local/bin/
    sudo chmod +x /usr/local/bin/xray

    # 清理临时文件
    cd - >/dev/null
    rm -rf "$temp_dir"

    # 验证安装
    if command -v xray >/dev/null 2>&1; then
        local version
        version=$(xray version 2>/dev/null | head -n1)
        log_success "Xray 安装成功！"
        log_info "版本信息: $version"
    else
        log_error "安装验证失败"
        return 1
    fi

    echo
    log_info "安装完成！现在可以使用代理配置功能。"

    wait_for_key
}

# =============================================================================
# 代理配置功能
# =============================================================================

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
            # 自动添加必要的IP以确保本地测试可用
            echo
            log_info "自动添加必要IP以确保功能正常..."

            # 将数组转为逗号分隔字符串
            local whitelist_str
            whitelist_str=$(IFS=,; echo "${WHITELIST_ITEMS[*]}")

            # 使用统一函数添加必要IP
            whitelist_str=$(add_essential_ips_to_whitelist "$whitelist_str")

            # 转回数组
            IFS=',' read -ra WHITELIST_ITEMS <<< "$whitelist_str"

            echo
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

# 保存配置到文件
save_config() {
    local config_file="proxy-config.env"

    cat > "$config_file" << EOF
# Xray 代理配置文件
# 由配置向导生成

PROXY_PORT=$PROXY_PORT
PROXY_USERNAME=$PROXY_USERNAME
PROXY_PASSWORD=$PROXY_PASSWORD
ENABLE_WHITELIST=$ENABLE_WHITELIST
WHITELIST_ITEMS="$(IFS=,; echo "${WHITELIST_ITEMS[*]}")"
EOF

    # 设置严格权限保护敏感信息
    chmod 600 "$config_file"
    log_info "配置已保存到 $config_file (权限: 600)"
}

# 主配置流程
main_configure() {
    show_config_banner

    # 检查 Xray 是否已安装
    if ! command -v xray >/dev/null 2>&1; then
        log_error "Xray 未安装，请先安装 Xray"
        return 1
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
        log_info "配置已保存，您可以稍后使用启动功能启动代理"
    fi
}

# =============================================================================
# 配置验证功能
# =============================================================================

# 验证配置文件
validate_config() {
    local config_file="${1:-proxy-config.env}"
    local silent="${2:-false}"  # 静默模式，只返回状态码

    # 1. 检查配置文件是否存在
    if [ ! -f "$config_file" ]; then
        [ "$silent" = false ] && log_error "配置文件不存在: $config_file"
        return 1
    fi

    # 2. 检查配置文件权限
    local file_perms
    file_perms=$(stat -c "%a" "$config_file" 2>/dev/null || stat -f "%OLp" "$config_file" 2>/dev/null)
    if [ "$file_perms" != "600" ]; then
        [ "$silent" = false ] && log_warning "配置文件权限不安全: $file_perms (建议: 600)"
        [ "$silent" = false ] && log_info "自动修复权限..."
        chmod 600 "$config_file"
    fi

    # 3. 加载配置文件
    local temp_port temp_username temp_password temp_whitelist temp_enable_wl

    # 安全地加载配置（避免代码注入）
    while IFS='=' read -r key value; do
        # 跳过注释和空行
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue

        # 移除引号
        value="${value%\"}"
        value="${value#\"}"

        case "$key" in
            PROXY_PORT) temp_port="$value" ;;
            PROXY_USERNAME) temp_username="$value" ;;
            PROXY_PASSWORD) temp_password="$value" ;;
            ENABLE_WHITELIST) temp_enable_wl="$value" ;;
            WHITELIST_ITEMS) temp_whitelist="$value" ;;
        esac
    done < "$config_file"

    local errors=0

    # 4. 验证必需字段
    if [ -z "$temp_port" ]; then
        [ "$silent" = false ] && log_error "配置错误: 缺少 PROXY_PORT"
        errors=$((errors + 1))
    fi

    if [ -z "$temp_username" ]; then
        [ "$silent" = false ] && log_error "配置错误: 缺少 PROXY_USERNAME"
        errors=$((errors + 1))
    fi

    if [ -z "$temp_password" ]; then
        [ "$silent" = false ] && log_error "配置错误: 缺少 PROXY_PASSWORD"
        errors=$((errors + 1))
    fi

    # 5. 验证端口号
    if [ -n "$temp_port" ]; then
        if ! [[ "$temp_port" =~ ^[0-9]+$ ]]; then
            [ "$silent" = false ] && log_error "配置错误: 端口号必须是数字: $temp_port"
            errors=$((errors + 1))
        elif [ "$temp_port" -lt 1 ] || [ "$temp_port" -gt 65535 ]; then
            [ "$silent" = false ] && log_error "配置错误: 端口号超出范围 (1-65535): $temp_port"
            errors=$((errors + 1))
        fi
    fi

    # 6. 验证用户名（不应包含特殊字符）
    if [ -n "$temp_username" ]; then
        if [[ "$temp_username" =~ [[:space:]\"\'\\] ]]; then
            [ "$silent" = false ] && log_error "配置错误: 用户名包含非法字符"
            errors=$((errors + 1))
        fi
    fi

    # 7. 验证密码长度
    if [ -n "$temp_password" ]; then
        if [ ${#temp_password} -lt 6 ]; then
            [ "$silent" = false ] && log_warning "配置警告: 密码长度过短 (建议至少6位)"
        fi
    fi

    # 8. 验证白名单配置
    if [ "$temp_enable_wl" = "true" ]; then
        if [ -z "$temp_whitelist" ]; then
            [ "$silent" = false ] && log_error "配置错误: 启用了白名单但未配置IP地址"
            errors=$((errors + 1))
        else
            # 验证每个IP/CIDR
            local invalid_ips=()
            IFS=',' read -ra ips <<< "$temp_whitelist"
            for ip in "${ips[@]}"; do
                # 跳过空项
                ip=$(echo "$ip" | xargs)  # 去除前后空格
                [ -z "$ip" ] && continue

                if ! validate_ip_or_cidr "$ip"; then
                    invalid_ips+=("$ip")
                fi
            done

            if [ ${#invalid_ips[@]} -gt 0 ]; then
                [ "$silent" = false ] && log_error "配置错误: 无效的IP地址/网段:"
                for invalid_ip in "${invalid_ips[@]}"; do
                    [ "$silent" = false ] && echo "  - $invalid_ip"
                done
                errors=$((errors + 1))
            fi
        fi
    fi

    # 9. 返回验证结果
    if [ $errors -eq 0 ]; then
        [ "$silent" = false ] && log_success "配置验证通过 ✓"
        return 0
    else
        [ "$silent" = false ] && log_error "配置验证失败，发现 $errors 个错误"
        return 1
    fi
}

# 快速检查配置是否存在且有效
check_config_exists() {
    local config_file="${1:-proxy-config.env}"
    [ -f "$config_file" ] && validate_config "$config_file" true
    return $?
}

# 显示配置验证详情
show_config_validation() {
    log_header "🔍 配置文件验证"
    echo

    local config_file="proxy-config.env"

    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        echo
        log_info "请先运行配置向导创建配置："
        echo "  ./xray-http-proxy.sh --configure"
        return 1
    fi

    log_info "正在验证配置文件: $config_file"
    echo

    if validate_config "$config_file"; then
        echo
        log_success "🎉 配置文件完全正常！"
        echo

        # 显示配置摘要
        source "$config_file"
        log_info "配置摘要："
        echo "  端口: $PROXY_PORT"
        echo "  用户名: $PROXY_USERNAME"
        echo "  密码: ${PROXY_PASSWORD:0:3}*** (已隐藏)"
        echo "  白名单: $([ "$ENABLE_WHITELIST" = true ] && echo "启用 ($WHITELIST_ITEMS)" || echo "禁用")"
        echo "  文件权限: $(stat -c "%a" "$config_file" 2>/dev/null || stat -f "%OLp" "$config_file" 2>/dev/null)"
    else
        echo
        log_error "❌ 配置验证失败"
        echo
        log_info "建议："
        echo "  1. 重新运行配置向导: ./xray-http-proxy.sh --configure"
        echo "  2. 或手动编辑配置文件: nano $config_file"
        return 1
    fi
}

# =============================================================================
# 代理启动管理功能
# =============================================================================

# 生成 Xray 配置
generate_config() {
    local config_content

    # 如果没有指定用户名和密码，自动生成
    if [ -z "$USERNAME" ]; then
        USERNAME=$(generate_username)
    fi
    if [ -z "$PASSWORD" ]; then
        PASSWORD=$(generate_password)
    fi

    config_content=$(cat << EOF
{
  "log": {
    "loglevel": "warning",
    "access": "$LOG_FILE",
    "error": "$LOG_FILE"
  },
  "inbounds": [
    {
      "tag": "http-in",
      "listen": "0.0.0.0",
      "port": $PORT,
      "protocol": "http",
      "settings": {
        "auth": "password",
        "accounts": [
          {
            "user": "$USERNAME",
            "pass": "$PASSWORD"
          }
        ],
        "allowTransparent": false
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      },
      "streamSettings": {
        "sockopt": {
          "acceptProxyProtocol": false
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom",
      "settings": {}
    },
    {
      "tag": "blocked",
      "protocol": "blackhole",
      "settings": {}
    }
  ]
EOF
)

    # 如果有IP白名单，添加路由规则（真正的入站IP限制）
    if [ -n "$WHITELIST" ]; then
        # 自动添加必要的IP以确保本地测试可用
        local essential_ips="127.0.0.1"

        # 获取服务器外部IP并添加到必要IP列表
        local external_ip
        external_ip=$(get_external_ip)
        if [ -n "$external_ip" ]; then
            essential_ips="$essential_ips,$external_ip"
        fi

        # 检查并添加必要的IP到白名单
        local updated_whitelist="$WHITELIST"
        for essential_ip in $(echo "$essential_ips" | tr ',' ' '); do
            if ! echo "$WHITELIST" | grep -q "$essential_ip"; then
                updated_whitelist="$updated_whitelist,$essential_ip"
                log_info "自动添加必要IP到白名单: $essential_ip"
            fi
        done

        # 清理重复的逗号并更新WHITELIST（使用bash内置功能优化）
        updated_whitelist="${updated_whitelist#,}"  # 删除开头的逗号
        WHITELIST="${updated_whitelist//,,/,}"       # 删除连续的逗号

        # 将逗号分隔的IP转换为 JSON 数组（优化为单次sed操作）
        local ips_json
        ips_json=$(echo "$WHITELIST" | sed 's/\([^,]*\)/"\1"/g')

        # 使用路由规则：白名单内的IP允许，其他IP拒绝
        config_content="${config_content},
  \"routing\": {
    \"domainStrategy\": \"AsIs\",
    \"rules\": [
      {
        \"type\": \"field\",
        \"source\": [$ips_json],
        \"inboundTag\": [\"http-in\"],
        \"outboundTag\": \"direct\"
      },
      {
        \"type\": \"field\",
        \"inboundTag\": [\"http-in\"],
        \"outboundTag\": \"blocked\"
      }
    ]
  }"
    fi

    config_content="${config_content}
}"

    echo "$config_content" > "$CONFIG_FILE"
}

# 检查代理状态
check_status() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_success "代理正在运行 (PID: $pid)"
            return 0
        else
            log_warning "PID 文件存在但进程不在运行"
            rm -f "$PID_FILE"
            return 1
        fi
    else
        log_info "代理未运行"
        return 1
    fi
}

# 停止代理（改进版，使用SIGTERM优雅关闭）
stop_proxy() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "正在停止代理 (PID: $pid)..."

            # 先发送SIGTERM，给进程时间优雅关闭
            kill -TERM "$pid" 2>/dev/null

            # 等待进程结束（最多10秒）
            local count=0
            while kill -0 "$pid" 2>/dev/null && [ $count -lt 10 ]; do
                sleep 1
                count=$((count + 1))
            done

            # 如果进程仍未结束，强制终止
            if kill -0 "$pid" 2>/dev/null; then
                log_warning "进程未正常结束，强制终止..."
                kill -9 "$pid" 2>/dev/null
                sleep 1
            fi

            rm -f "$PID_FILE"
            log_success "代理已停止"
        else
            log_warning "PID 文件存在但进程不在运行"
            rm -f "$PID_FILE"
        fi
    else
        log_warning "代理未运行"
    fi

    # 清理配置文件
    [ -f "$CONFIG_FILE" ] && rm -f "$CONFIG_FILE"
}

# 启动代理
start_proxy() {
    # 如果没有指定端口，生成随机端口
    if [ -z "$PORT" ]; then
        PORT=$(generate_random_port)
        log_info "生成随机端口: $PORT"
    fi

    # 检查是否已在运行
    if check_status >/dev/null 2>&1; then
        log_error "代理已在运行"
        return 1
    fi

    # 检查 xray 是否可用
    if ! command -v xray >/dev/null 2>&1; then
        log_error "xray 未安装或不在 PATH 中"
        log_info "请先运行安装功能"
        return 1
    fi

    # 生成配置
    generate_config

    local external_ip
    external_ip=$(get_external_ip)

    log_info "启动 Xray HTTP 代理..."
    log_info "端口: $PORT"
    log_info "用户名: $USERNAME"
    log_info "密码: $PASSWORD"
    log_info "日志文件: $LOG_FILE"
    log_info "本地访问: http://$USERNAME:$PASSWORD@127.0.0.1:$PORT"
    log_info "外部访问: http://$USERNAME:$PASSWORD@$external_ip:$PORT"
    if [ -n "$WHITELIST" ]; then
        log_info "白名单: $WHITELIST"
    fi

    if [ "$DAEMON" = true ]; then
        # 后台运行，输出到日志文件
        nohup xray run -config "$CONFIG_FILE" >> "$LOG_FILE" 2>&1 &
        local pid=$!
        echo $pid > "$PID_FILE"
        log_success "代理已在后台启动 (PID: $pid)"
        log_info "查看日志: tail -f $LOG_FILE"

        # 等待一下确保启动成功
        sleep 2
        if ! kill -0 "$pid" 2>/dev/null; then
            log_error "代理启动失败，请查看日志: $LOG_FILE"
            rm -f "$PID_FILE"
            return 1
        fi
    else
        # 前台运行
        trap 'log_info "正在停止代理..."; kill $! 2>/dev/null; rm -f "$CONFIG_FILE"; exit 0' INT TERM
        xray run -config "$CONFIG_FILE" &
        local pid=$!
        echo $pid > "$PID_FILE"

        log_success "代理已启动 (PID: $pid)"
        log_info "按 Ctrl+C 停止代理"

        wait $pid
        rm -f "$PID_FILE" "$CONFIG_FILE"
    fi
}

# 启动代理（使用配置）
start_proxy_with_config() {
    log_highlight "🚀 启动代理服务器"
    echo

    # 验证配置文件
    if ! validate_config "proxy-config.env" true; then
        log_error "配置文件验证失败，请检查配置"
        echo
        validate_config "proxy-config.env" false  # 显示详细错误
        return 1
    fi

    local proxy_args=("-p" "$PROXY_PORT" "-u" "$PROXY_USERNAME" "-P" "$PROXY_PASSWORD")

    if [ "$ENABLE_WHITELIST" = true ] && [ ${#WHITELIST_ITEMS[@]} -gt 0 ]; then
        local whitelist_str
        whitelist_str=$(IFS=,; echo "${WHITELIST_ITEMS[*]}")
        proxy_args+=("-w" "$whitelist_str")
    fi

    log_info "正在启动代理服务器..."

    # 设置参数
    PORT="$PROXY_PORT"
    USERNAME="$PROXY_USERNAME"
    PASSWORD="$PROXY_PASSWORD"
    DAEMON=true
    if [ "$ENABLE_WHITELIST" = true ] && [ ${#WHITELIST_ITEMS[@]} -gt 0 ]; then
        WHITELIST=$(IFS=,; echo "${WHITELIST_ITEMS[*]}")
    fi

    if start_proxy; then
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
  查看状态: $0 --status
  停止代理: $0 --stop
  重新配置: $0 --configure

EOF
}

# =============================================================================
# 白名单管理功能
# =============================================================================

# 管理白名单
manage_whitelist() {
    log_header "🛡️ 管理客户端IP白名单"
    echo

    # 检查配置文件是否存在
    if [ ! -f "proxy-config.env" ]; then
        log_warning "未发现配置文件，请先配置代理"
        read -p "是否现在配置代理？[Y/n]: " config_now
        case "$config_now" in
            [nN]|[nN][oO])
                return 1
                ;;
            *)
                main_configure
                return
                ;;
        esac
    fi

    # 加载配置
    source proxy-config.env

    while true; do
        echo
        log_info "当前白名单状态: $([ "$ENABLE_WHITELIST" = true ] && echo "已启用" || echo "已禁用")"
        if [ "$ENABLE_WHITELIST" = true ] && [ -n "$WHITELIST_ITEMS" ]; then
            log_info "当前白名单项目:"
            IFS=',' read -ra ITEMS <<< "$WHITELIST_ITEMS"
            local count=1
            for item in "${ITEMS[@]}"; do
                echo "  $count. $item"
                count=$((count + 1))
            done
        fi
        echo

        log_menu "白名单管理选项:"
        log_menu "  1) 启用/禁用白名单"
        log_menu "  2) 添加IP地址"
        log_menu "  3) 删除IP地址"
        log_menu "  4) 清空白名单"
        log_menu "  5) 应用配置并重启代理"
        log_menu "  6) 返回主菜单"
        echo

        read -p "请选择 [1-6]: " whitelist_choice

        case "$whitelist_choice" in
            1)
                # 启用/禁用白名单
                if [ "$ENABLE_WHITELIST" = true ]; then
                    read -p "当前白名单已启用，是否禁用？[y/N]: " disable_wl
                    if [[ "$disable_wl" =~ ^[yY] ]]; then
                        ENABLE_WHITELIST=false
                        log_success "白名单已禁用"
                    fi
                else
                    read -p "当前白名单已禁用，是否启用？[Y/n]: " enable_wl
                    case "$enable_wl" in
                        [nN]|[nN][oO]) ;;
                        *)
                            ENABLE_WHITELIST=true
                            log_success "白名单已启用"

                            # 使用统一函数添加必要IP
                            WHITELIST_ITEMS=$(add_essential_ips_to_whitelist "$WHITELIST_ITEMS")
                            ;;
                    esac
                fi
                ;;
            2)
                # 添加IP地址
                echo
                log_info "支持的格式: 单个IP (192.168.1.100) 或 CIDR网段 (192.168.1.0/24)"
                read -p "请输入要添加的IP地址或网段: " new_ip

                if [ -n "$new_ip" ]; then
                    # 验证IP地址格式
                    if validate_ip_or_cidr "$new_ip"; then
                        # 检查是否已存在
                        if [[ ",$WHITELIST_ITEMS," == *",$new_ip,"* ]]; then
                            log_warning "IP地址 $new_ip 已存在于白名单中"
                        else
                            if [ -z "$WHITELIST_ITEMS" ]; then
                                WHITELIST_ITEMS="$new_ip"
                            else
                                WHITELIST_ITEMS="$WHITELIST_ITEMS,$new_ip"
                            fi
                            log_success "已添加 $new_ip 到白名单"
                            # 如果白名单被禁用，询问是否启用
                            if [ "$ENABLE_WHITELIST" != true ]; then
                                read -p "白名单当前被禁用，是否启用？[Y/n]: " enable_now
                                case "$enable_now" in
                                    [nN]|[nN][oO]) ;;
                                    *)
                                        ENABLE_WHITELIST=true
                                        log_success "白名单已启用"

                                        # 使用统一函数添加必要IP
                                        WHITELIST_ITEMS=$(add_essential_ips_to_whitelist "$WHITELIST_ITEMS")
                                        ;;
                                esac
                            fi
                        fi
                    else
                        log_error "无效的IP地址或网段格式: $new_ip"
                    fi
                fi
                ;;
            3)
                # 删除IP地址
                if [ -z "$WHITELIST_ITEMS" ]; then
                    log_warning "白名单为空，无法删除"
                else
                    echo
                    log_info "当前白名单项目:"
                    IFS=',' read -ra ITEMS <<< "$WHITELIST_ITEMS"
                    local count=1
                    for item in "${ITEMS[@]}"; do
                        echo "  $count. $item"
                        count=$((count + 1))
                    done
                    echo

                    read -p "请输入要删除的项目编号 [1-${#ITEMS[@]}]: " del_num

                    if [[ "$del_num" =~ ^[0-9]+$ ]] && [ "$del_num" -ge 1 ] && [ "$del_num" -le ${#ITEMS[@]} ]; then
                        local del_index=$((del_num - 1))
                        local del_item="${ITEMS[$del_index]}"

                        # 重建白名单字符串，排除要删除的项目
                        local new_whitelist=""
                        for i in "${!ITEMS[@]}"; do
                            if [ $i -ne $del_index ]; then
                                if [ -z "$new_whitelist" ]; then
                                    new_whitelist="${ITEMS[$i]}"
                                else
                                    new_whitelist="$new_whitelist,${ITEMS[$i]}"
                                fi
                            fi
                        done

                        WHITELIST_ITEMS="$new_whitelist"
                        log_success "已删除 $del_item"

                        # 如果白名单为空，询问是否禁用
                        if [ -z "$WHITELIST_ITEMS" ] && [ "$ENABLE_WHITELIST" = true ]; then
                            read -p "白名单已为空，是否禁用白名单功能？[Y/n]: " disable_empty
                            case "$disable_empty" in
                                [nN]|[nN][oO]) ;;
                                *) ENABLE_WHITELIST=false; log_success "白名单已禁用" ;;
                            esac
                        fi
                    else
                        log_error "无效的项目编号"
                    fi
                fi
                ;;
            4)
                # 清空白名单
                if [ -n "$WHITELIST_ITEMS" ]; then
                    read -p "确定要清空所有白名单项目吗？[y/N]: " clear_confirm
                    if [[ "$clear_confirm" =~ ^[yY] ]]; then
                        WHITELIST_ITEMS=""
                        ENABLE_WHITELIST=false
                        log_success "白名单已清空并禁用"
                    fi
                else
                    log_warning "白名单已为空"
                fi
                ;;
            5)
                # 应用配置并重启代理
                log_info "正在保存配置..."

                # 更新配置文件
                cat > "proxy-config.env" << EOF
# Xray 代理配置文件
# 由配置向导生成

PROXY_PORT=$PROXY_PORT
PROXY_USERNAME=$PROXY_USERNAME
PROXY_PASSWORD=$PROXY_PASSWORD
ENABLE_WHITELIST=$ENABLE_WHITELIST
WHITELIST_ITEMS="$WHITELIST_ITEMS"
EOF
                chmod 600 "proxy-config.env"

                log_success "配置已保存"

                # 询问是否重启代理
                read -p "是否重启代理应用新的白名单配置？[Y/n]: " restart_confirm
                case "$restart_confirm" in
                    [nN]|[nN][oO])
                        log_info "配置已保存，请手动重启代理以应用更改"
                        ;;
                    *)
                        restart_proxy_service
                        ;;
                esac
                return
                ;;
            6)
                # 返回主菜单
                return
                ;;
            *)
                log_error "无效选择，请输入 1-6"
                sleep 1
                ;;
        esac
    done
}

# =============================================================================
# Playwright 测试功能
# =============================================================================

# 创建 Playwright 测试脚本
create_playwright_test() {
    cat > "test-proxy.js" << 'EOF'
const { chromium } = require('playwright');
const fs = require('fs');

async function testProxy() {
    console.log('[INFO] 开始 Playwright 代理测试...');

    let browser = null;
    let context = null;

    try {
        // 读取当前代理配置
        if (!fs.existsSync('proxy-config.env')) {
            throw new Error('未找到代理配置文件 proxy-config.env，请先启动代理');
        }

        console.log('[INFO] 读取代理配置...');
        const configContent = fs.readFileSync('proxy-config.env', 'utf8');
        const config = {};

        configContent.split('\n').forEach(line => {
            if (line.includes('=') && !line.startsWith('#')) {
                const [key, value] = line.split('=', 2);
                config[key.trim()] = value.trim().replace(/^"/, '').replace(/"$/, '');
            }
        });

        const proxyPort = config.PROXY_PORT;
        const proxyUsername = config.PROXY_USERNAME;
        const proxyPassword = config.PROXY_PASSWORD;

        if (!proxyPort || !proxyUsername || !proxyPassword) {
            throw new Error('代理配置不完整，请重新配置代理');
        }

        console.log(`[INFO] 使用代理配置: ${proxyUsername}@127.0.0.1:${proxyPort}`);

        // 启动浏览器，使用当前运行的代理
        console.log('[INFO] 启动浏览器...');
        browser = await chromium.launch({
            headless: true,
            proxy: {
                server: `http://127.0.0.1:${proxyPort}`,
                username: proxyUsername,
                password: proxyPassword
            }
        });

        context = await browser.newContext();
        const page = await context.newPage();

        // 设置超时
        page.setDefaultTimeout(15000);

        console.log('[INFO] 访问测试页面...');

        // 首先测试IP检查 - 使用多个备用服务
        console.log('[INFO] 检查当前IP...');
        let ipInfo = null;
        const ipServices = [
            'https://api.ipify.org?format=json',
            'https://httpbin.org/ip',
            'https://ifconfig.me/ip'
        ];

        for (const service of ipServices) {
            try {
                console.log(`[INFO] 尝试访问: ${service}`);
                const ipResponse = await page.goto(service, { waitUntil: 'networkidle' });
                if (ipResponse.ok()) {
                    const ipContent = await page.textContent('body');
                    if (service.includes('ifconfig.me')) {
                        ipInfo = { ip: ipContent.trim() };
                    } else {
                        ipInfo = JSON.parse(ipContent);
                    }
                    console.log(`[INFO] 当前IP: ${ipInfo.ip || ipInfo.origin}`);
                    break;
                }
            } catch (error) {
                console.log(`[WARNING] ${service} 访问失败: ${error.message}`);
                continue;
            }
        }

        if (!ipInfo) {
            throw new Error('所有IP检查服务都无法访问');
        }

        // 测试主要网站 - 使用可靠的测试站点
        console.log('[INFO] 访问测试网站...');
        const testSites = [
            { url: 'https://example.com', name: 'Example.com' },
            { url: 'https://httpbin.org/get', name: 'HTTPBin GET' },
            { url: 'https://www.google.com', name: 'Google' },
            { url: 'https://sehuatang.org/', name: 'Sehuatang.org' },
            { url: 'https://sehuatang.net/', name: 'Sehuatang.net' }
        ];

        let successCount = 0;
        for (const site of testSites) {
            try {
                console.log(`[INFO] 访问 ${site.name}: ${site.url}`);
                const response = await page.goto(site.url, { waitUntil: 'domcontentloaded' });
                if (response.ok()) {
                    console.log(`[SUCCESS] ${site.name} 加载成功 (${response.status()})`);
                    const title = await page.title();
                    console.log(`[INFO] 页面标题: ${title}`);
                    successCount++;
                } else {
                    console.log(`[WARNING] ${site.name} HTTP ${response.status()}: ${response.statusText()}`);
                }
            } catch (error) {
                console.log(`[WARNING] ${site.name} 访问失败: ${error.message}`);
            }
        }

        if (successCount === 0) {
            throw new Error('所有测试网站都无法访问');
        }

        console.log(`[SUCCESS] 成功访问 ${successCount}/${testSites.length} 个测试网站`);

        // 保存截图
        await page.screenshot({ path: 'playwright-test.png', fullPage: true });
        console.log('[SUCCESS] 截图已保存: playwright-test.png');

        console.log('[SUCCESS] ✅ Playwright 代理测试完成！');

    } catch (error) {
        console.error(`[ERROR] ❌ 测试失败: ${error.message}`);
        process.exit(1);
    } finally {
        if (context) await context.close();
        if (browser) await browser.close();
    }
}

testProxy().catch(console.error);
EOF
}

# 测试 Playwright 集成
test_playwright() {
    log_header "🎭 测试 Playwright 集成"
    echo

    # 检查代理是否运行
    if ! check_status >/dev/null 2>&1; then
        log_warning "代理未运行"
        read -p "是否先启动代理？[Y/n]: " start_first
        case "$start_first" in
            [nN]|[nN][oO])
                log_info "请先启动代理服务"
                return 1
                ;;
            *)
                # 尝试使用配置启动代理
                if [ -f "proxy-config.env" ]; then
                    source proxy-config.env
                    PORT="$PROXY_PORT"
                    USERNAME="$PROXY_USERNAME"
                    PASSWORD="$PROXY_PASSWORD"
                    DAEMON=true
                    if [ "$ENABLE_WHITELIST" = true ] && [ -n "$WHITELIST_ITEMS" ]; then
                        WHITELIST="$WHITELIST_ITEMS"
                    fi
                    start_proxy
                else
                    log_info "未发现配置，请先进行配置"
                    return 1
                fi
                ;;
        esac
    fi

    # 检查 Node.js
    if ! command -v node >/dev/null 2>&1; then
        log_error "Node.js 未安装"
        log_info "请先安装 Node.js: https://nodejs.org/"
        return 1
    fi

    # 检查 Playwright (尝试安装)
    if ! node -e "require('playwright')" 2>/dev/null; then
        log_info "Playwright 未安装，正在安装..."
        if command -v npm >/dev/null 2>&1; then
            npm install playwright
            npx playwright install chromium
        else
            log_error "npm 不可用，无法安装 Playwright"
            return 1
        fi
    fi

    # 创建测试脚本
    log_info "创建测试脚本..."
    create_playwright_test

    # 运行测试
    log_info "运行 Playwright 测试..."

    if node test-proxy.js; then
        log_success "✅ Playwright 测试通过！"
    else
        log_error "❌ Playwright 测试失败"
        return 1
    fi

    wait_for_key
}

# =============================================================================
# 开机自启动管理功能
# =============================================================================

# 检查systemd是否可用
check_systemd() {
    if command -v systemctl >/dev/null 2>&1 && [ -d /etc/systemd/system ]; then
        return 0
    else
        return 1
    fi
}

# 生成systemd服务文件
generate_systemd_service() {
    local script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    local working_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    cat << EOF
[Unit]
Description=Xray HTTP Proxy Service
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=forking
User=$USER
WorkingDirectory=$working_dir
ExecStart=$script_path --start -d
ExecStop=$script_path --stop
ExecReload=$script_path --restart
Restart=on-failure
RestartSec=10s
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
}

# 启用开机自启动
enable_autostart() {
    log_header "🚀 启用开机自启动"
    echo

    # 检查配置文件是否存在
    if [ ! -f "proxy-config.env" ]; then
        log_error "未发现代理配置文件，请先配置代理"
        read -p "是否现在配置代理？[Y/n]: " do_config
        case "$do_config" in
            [nN]|[nN][oO])
                return 1
                ;;
            *)
                main_configure
                return
                ;;
        esac
    fi

    if check_systemd; then
        log_info "检测到 systemd，将创建系统服务"

        # 生成服务文件
        log_info "生成 systemd 服务文件..."
        generate_systemd_service | sudo tee "$SYSTEMD_SERVICE_FILE" > /dev/null

        if [ $? -ne 0 ]; then
            log_error "创建服务文件失败，需要 sudo 权限"
            return 1
        fi

        # 重新加载 systemd
        log_info "重新加载 systemd..."
        sudo systemctl daemon-reload

        # 启用服务
        log_info "启用开机自启动..."
        sudo systemctl enable "$SYSTEMD_SERVICE_NAME"

        if [ $? -eq 0 ]; then
            log_success "✅ 开机自启动已启用！"
            echo
            log_info "服务管理命令:"
            echo "  启动服务: sudo systemctl start $SYSTEMD_SERVICE_NAME"
            echo "  停止服务: sudo systemctl stop $SYSTEMD_SERVICE_NAME"
            echo "  查看状态: sudo systemctl status $SYSTEMD_SERVICE_NAME"
            echo "  查看日志: sudo journalctl -u $SYSTEMD_SERVICE_NAME -f"
        else
            log_error "启用开机自启动失败"
            return 1
        fi
    else
        log_warning "未检测到 systemd"
        log_info "尝试使用 rc.local 方式..."

        # 使用 rc.local 方式
        local script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
        local rc_local="/etc/rc.local"

        if [ ! -f "$rc_local" ]; then
            log_info "创建 rc.local 文件..."
            sudo bash -c "cat > $rc_local" << 'EOF'
#!/bin/bash
# rc.local - 开机自启动脚本
exit 0
EOF
            sudo chmod +x "$rc_local"
        fi

        # 检查是否已存在
        if sudo grep -q "$script_path" "$rc_local" 2>/dev/null; then
            log_warning "rc.local 中已存在该脚本的启动命令"
        else
            log_info "添加启动命令到 rc.local..."
            sudo sed -i "/^exit 0/i $script_path --start -d" "$rc_local"
            log_success "✅ 已添加到 rc.local"
        fi
    fi

    wait_for_key
}

# 禁用开机自启动
disable_autostart() {
    log_header "⏹️ 禁用开机自启动"
    echo

    if check_systemd; then
        if [ -f "$SYSTEMD_SERVICE_FILE" ]; then
            log_info "禁用 systemd 服务..."
            sudo systemctl disable "$SYSTEMD_SERVICE_NAME"
            sudo systemctl stop "$SYSTEMD_SERVICE_NAME" 2>/dev/null

            log_info "删除服务文件..."
            sudo rm -f "$SYSTEMD_SERVICE_FILE"
            sudo systemctl daemon-reload

            log_success "✅ 开机自启动已禁用"
        else
            log_warning "未找到 systemd 服务文件"
        fi
    else
        # 从 rc.local 中移除
        local script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
        local rc_local="/etc/rc.local"

        if [ -f "$rc_local" ]; then
            if sudo grep -q "$script_path" "$rc_local" 2>/dev/null; then
                log_info "从 rc.local 中移除..."
                sudo sed -i "\|$script_path|d" "$rc_local"
                log_success "✅ 已从 rc.local 中移除"
            else
                log_warning "rc.local 中未找到启动命令"
            fi
        fi
    fi

    wait_for_key
}

# 查看自启动状态
check_autostart_status() {
    log_header "📊 开机自启动状态"
    echo

    if check_systemd; then
        if [ -f "$SYSTEMD_SERVICE_FILE" ]; then
            log_info "systemd 服务状态:"
            sudo systemctl status "$SYSTEMD_SERVICE_NAME" --no-pager || true
            echo

            if sudo systemctl is-enabled "$SYSTEMD_SERVICE_NAME" >/dev/null 2>&1; then
                log_success "✅ 开机自启动: 已启用"
            else
                log_warning "⚠️ 开机自启动: 未启用"
            fi
        else
            log_info "❌ 未配置 systemd 服务"
        fi
    else
        local script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
        local rc_local="/etc/rc.local"

        if [ -f "$rc_local" ] && sudo grep -q "$script_path" "$rc_local" 2>/dev/null; then
            log_success "✅ rc.local 中已配置开机自启动"
            echo
            log_info "启动命令:"
            sudo grep "$script_path" "$rc_local"
        else
            log_info "❌ 未配置开机自启动"
        fi
    fi

    wait_for_key
}

# =============================================================================
# 主控制界面
# =============================================================================

# 显示横幅
show_banner() {
    clear
    cat << 'EOF'

██╗  ██╗██████╗  █████╗ ██╗   ██╗    ██████╗ ██████╗  ██████╗ ██╗  ██╗██╗   ██╗
╚██╗██╔╝██╔══██╗██╔══██╗╚██╗ ██╔╝    ██╔══██╗██╔══██╗██╔═══██╗╚██╗██╔╝╚██╗ ██╔╝
 ╚███╔╝ ██████╔╝███████║ ╚████╔╝     ██████╔╝██████╔╝██║   ██║ ╚███╔╝  ╚████╔╝
 ██╔██╗ ██╔══██╗██╔══██║  ╚██╔╝      ██╔═══╝ ██╔══██╗██║   ██║ ██╔██╗   ╚██╔╝
██╔╝ ██╗██║  ██║██║  ██║   ██║       ██║     ██║  ██║╚██████╔╝██╔╝ ██╗   ██║
╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝       ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝

                        HTTP 代理一体化脚本 v$SCRIPT_VERSION
                     支持 Playwright | IP白名单 | 随机端口

EOF
}

# 显示主菜单
show_menu() {
    echo
    log_header "═══════════════════════════════════════════════════════════════"
    log_header "                      🎛️  主功能菜单                          "
    log_header "═══════════════════════════════════════════════════════════════"
    echo

    log_menu "   1. 🔧 安装 Xray 核心"
    log_menu "   2. ⚙️  交互式配置代理"
    log_menu "   3. 🚀 启动代理服务"
    log_menu "   4. ⏹️  停止代理服务"
    log_menu "   5. ⚙️  查看和修改配置文件"
    log_menu "   6. 🔍 验证配置文件"
    echo
    log_menu "   7. 🛡️  管理白名单"
    log_menu "   8. 🎭 测试 Playwright 集成"
    log_menu "   9. 📊 查看代理状态"
    log_menu "  10. 📋 查看系统信息"
    log_menu "  11. 🔄 重启代理服务"
    echo
    log_menu "  12. 🔥 启用开机自启动"
    log_menu "  13. ⏸️  禁用开机自启动"
    log_menu "  14. 📡 查看自启动状态"
    echo
    log_menu "  15. 🧹 清理配置文件"
    log_menu "  16. ❓ 显示帮助信息"
    echo
    log_header "═══════════════════════════════════════════════════════════════"
    echo
}

# 重启代理服务
restart_proxy_service() {
    log_header "🔄 重启代理服务"
    echo

    log_info "正在重启代理服务..."

    # 停止代理
    stop_proxy

    sleep 2

    # 重新启动
    if [ -f "proxy-config.env" ]; then
        source proxy-config.env
        PORT="$PROXY_PORT"
        USERNAME="$PROXY_USERNAME"
        PASSWORD="$PROXY_PASSWORD"
        DAEMON=true
        if [ "$ENABLE_WHITELIST" = true ] && [ -n "$WHITELIST_ITEMS" ]; then
            WHITELIST="$WHITELIST_ITEMS"
        fi

        log_info "使用已有配置重启代理..."
        start_proxy
    else
        log_info "使用默认配置重启代理..."
        PORT=""
        USERNAME=""
        PASSWORD=""
        DAEMON=true
        start_proxy
    fi

    wait_for_key
}

# 清理配置文件
cleanup_files() {
    log_header "🧹 清理配置文件"
    echo

    log_warning "这将删除以下文件:"
    local files=("proxy-config.env" "xray-proxy-config.json" "playwright-test.png" "test-proxy.js")
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            echo "  - $file"
        fi
    done
    echo

    read -p "确认删除？[y/N]: " confirm
    case "$confirm" in
        [yY]|[yY][eE][sS])
            for file in "${files[@]}"; do
                if [ -f "$file" ]; then
                    rm -f "$file"
                    log_success "已删除: $file"
                fi
            done

            # 停止代理
            stop_proxy

            log_success "清理完成"
            ;;
        *)
            log_info "已取消清理"
            ;;
    esac

    wait_for_key
}

# 查看系统信息
# 查看和修改配置文件
view_edit_config() {
    log_header "⚙️ 查看和修改配置文件"
    echo

    if [ ! -f "proxy-config.env" ]; then
        log_warning "配置文件不存在，请先进行配置 (选项 2)"
        wait_for_key
        return
    fi

    # 显示当前配置
    log_info "当前配置内容:"
    echo
    cat proxy-config.env
    echo

    # 询问是否修改
    while true; do
        echo
        log_info "请选择操作:"
        echo "  1. 修改代理端口"
        echo "  2. 修改用户名"
        echo "  3. 修改密码"
        echo "  4. 切换白名单状态"
        echo "  5. 修改白名单IP"
        echo "  6. 重新生成随机端口"
        echo "  7. 重新生成随机凭据"
        echo "  8. 查看配置文件路径"
        echo "  9. 返回主菜单"
        echo

        read -p "请选择 [1-9]: " config_choice

        case "$config_choice" in
            1)
                read -p "请输入新的端口号 (10000-65535): " new_port
                if [[ "$new_port" =~ ^[0-9]+$ ]] && [ "$new_port" -ge 10000 ] && [ "$new_port" -le 65535 ]; then
                    sed -i "s/^PROXY_PORT=.*/PROXY_PORT=$new_port/" proxy-config.env
                    log_success "端口已更新为: $new_port"
                else
                    log_error "无效的端口号"
                fi
                ;;
            2)
                read -p "请输入新的用户名: " new_user
                if [ -n "$new_user" ]; then
                    sed -i "s/^PROXY_USERNAME=.*/PROXY_USERNAME=$new_user/" proxy-config.env
                    log_success "用户名已更新为: $new_user"
                fi
                ;;
            3)
                read -p "请输入新的密码: " new_pass
                if [ -n "$new_pass" ]; then
                    sed -i "s/^PROXY_PASSWORD=.*/PROXY_PASSWORD=$new_pass/" proxy-config.env
                    log_success "密码已更新"
                fi
                ;;
            4)
                source proxy-config.env
                if [ "$ENABLE_WHITELIST" = "true" ]; then
                    sed -i "s/^ENABLE_WHITELIST=.*/ENABLE_WHITELIST=false/" proxy-config.env
                    log_success "白名单已禁用"
                else
                    sed -i "s/^ENABLE_WHITELIST=.*/ENABLE_WHITELIST=true/" proxy-config.env
                    log_success "白名单已启用"
                fi
                ;;
            5)
                read -p "请输入白名单IP (用逗号分隔): " new_whitelist
                sed -i "s/^WHITELIST_ITEMS=.*/WHITELIST_ITEMS=\"$new_whitelist\"/" proxy-config.env
                log_success "白名单IP已更新"
                ;;
            6)
                new_random_port=$(generate_random_port)
                sed -i "s/^PROXY_PORT=.*/PROXY_PORT=$new_random_port/" proxy-config.env
                log_success "已生成新的随机端口: $new_random_port"
                ;;
            7)
                new_user="user_$(head -c 6 /dev/urandom | xxd -p 2>/dev/null || head -c 12 /dev/urandom | base64 | tr -d '=\n' | tr '+/' 'ab' | head -c 12)"
                new_pass=$(head -c 12 /dev/urandom | xxd -p 2>/dev/null | tr -d '\n' || head -c 12 /dev/urandom | base64 | tr -d '=\n' | tr '+/' 'ab' | head -c 12)
                sed -i "s/^PROXY_USERNAME=.*/PROXY_USERNAME=$new_user/" proxy-config.env
                sed -i "s/^PROXY_PASSWORD=.*/PROXY_PASSWORD=$new_pass/" proxy-config.env
                log_success "已生成新的随机凭据"
                log_info "用户名: $new_user"
                log_info "密码: $new_pass"
                ;;
            8)
                log_info "配置文件位置:"
                echo "  $(pwd)/proxy-config.env"
                echo "  $(pwd)/proxy-config.json"
                ;;
            9)
                break
                ;;
            *)
                log_error "无效选择，请重试"
                ;;
        esac

        if [ "$config_choice" != "9" ]; then
            echo
            log_info "更新后的配置:"
            cat proxy-config.env
            echo
        fi
    done
}

# 查看代理状态（增强版，包含服务器IP）
show_proxy_status() {
    log_header "📊 查看代理状态"
    echo

    log_info "检查代理状态..."

    # 检查代理进程状态
    if check_status; then
        echo

        # 显示配置信息
        if [ -f "proxy-config.env" ]; then
            source proxy-config.env
            log_info "代理配置信息:"
            echo "  端口: $PROXY_PORT"
            echo "  用户名: $PROXY_USERNAME"
            echo "  密码: $PROXY_PASSWORD"
            echo "  IP白名单: $([ "$ENABLE_WHITELIST" = true ] && echo "启用" || echo "禁用")"
            if [ "$ENABLE_WHITELIST" = true ] && [ -n "$WHITELIST_ITEMS" ]; then
                echo "  允许的IP: $WHITELIST_ITEMS"
            fi
            echo

            # 获取并显示服务器IP
            log_info "服务器IP信息:"
            external_ip=$(get_external_ip)
            if [ -n "$external_ip" ]; then
                echo "  外部IP: $external_ip"
                echo "  本地访问: http://$PROXY_USERNAME:$PROXY_PASSWORD@127.0.0.1:$PROXY_PORT"
                echo "  外部访问: http://$PROXY_USERNAME:$PROXY_PASSWORD@$external_ip:$PROXY_PORT"
            else
                echo "  外部IP: 无法获取"
                echo "  本地访问: http://$PROXY_USERNAME:$PROXY_PASSWORD@127.0.0.1:$PROXY_PORT"
            fi
            echo

            # 显示端口监听状态
            log_info "端口监听状态:"
            if netstat -tuln 2>/dev/null | grep -q ":$PROXY_PORT " || ss -tuln 2>/dev/null | grep -q ":$PROXY_PORT "; then
                log_success "端口 $PROXY_PORT 正在监听"
            else
                log_warning "端口 $PROXY_PORT 未在监听"
            fi
        else
            log_warning "配置文件不存在"
        fi
    else
        log_info "代理未运行"
    fi

    echo
    wait_for_key
}

show_system_info() {
    log_header "📋 查看系统信息"
    echo

    # 显示系统信息
    log_info "系统信息:"
    echo "  操作系统: $(uname -s)"
    echo "  架构: $(uname -m)"
    echo "  Node.js: $(command -v node >/dev/null && node --version || echo "未安装")"
    echo "  Xray: $(command -v xray >/dev/null && xray version | head -n1 || echo "未安装")"
    echo

    # 显示代理状态
    log_info "代理状态:"
    check_status || echo "  代理未运行"
    echo

    # 显示配置信息
    if [ -f "proxy-config.env" ]; then
        log_info "当前配置:"
        source proxy-config.env
        echo "  端口: $PROXY_PORT"
        echo "  用户名: $PROXY_USERNAME"
        echo "  密码: $PROXY_PASSWORD"
        echo "  IP白名单: $([ "$ENABLE_WHITELIST" = true ] && echo "启用" || echo "禁用")"
        if [ "$ENABLE_WHITELIST" = true ] && [ -n "$WHITELIST_ITEMS" ]; then
            echo "  允许的IP: $WHITELIST_ITEMS"
        fi

        # 获取外部IP
        local external_ip
        external_ip=$(get_external_ip)

        echo "  代理URL (本地): http://$PROXY_USERNAME:$PROXY_PASSWORD@127.0.0.1:$PROXY_PORT"
        echo "  代理URL (外部): http://$PROXY_USERNAME:$PROXY_PASSWORD@$external_ip:$PROXY_PORT"
    else
        echo "  未发现配置文件"
    fi

    wait_for_key
}

# 显示帮助信息
show_help() {
    log_header "❓ 显示帮助信息"
    echo

    cat << 'EOF'
📖 Xray HTTP 代理一体化脚本 - 帮助信息

🎯 主要功能：
  • 基于 Xray 核心的 HTTP 代理服务器
  • 支持账号密码自动生成
  • 支持客户端IP白名单控制
  • 完美集成 Playwright 自动化测试
  • 交互式配置向导
  • 实时白名单管理

🚀 快速开始：
  1. 选择选项 1 安装 Xray 核心
  2. 选择选项 2 进行交互式配置
  3. 选择选项 3 启动代理服务
  4. 选择选项 6 管理白名单（可选）
  5. 选择选项 7 测试 Playwright 集成

🛡️ 安全特性：
  • IP白名单控制客户端访问（入站限制）
  • 代理本身可访问所有网站（无出站限制）
  • 支持单个IP和CIDR网段格式
  • 用户名密码认证
  • 随机端口生成（10000-65535）

📋 配置选项：
  • 端口：可自定义代理监听端口或使用随机端口
  • 认证：支持自定义或自动生成用户名密码
  • 白名单：可选择启用IP白名单功能并动态管理
  • 模式：支持前台和后台运行

🔧 命令行使用：
  # 快速启动（使用随机端口）
  $0 --start

  # 启用IP白名单
  $0 --start --whitelist "127.0.0.1,192.168.1.0/24"

  # 自定义认证
  $0 --start --port 12345 --username myuser --password mypass

🎛️ 控制中心快捷方式：
  $0 --whitelist          # 直接打开白名单管理
  $0 --configure          # 直接进入配置向导
  $0 --status             # 查看代理状态
  $0 --install            # 安装 Xray

📞 支持信息：
  • GitHub: https://github.com/XTLS/Xray-core
  • 问题反馈：请检查配置文件和日志输出
  • 系统要求：Linux/macOS + Node.js 14+

EOF

    wait_for_key
}

# 启动代理服务
start_proxy_service() {
    log_header "🚀 启动代理服务"
    echo

    # 检查是否已有配置
    if [ -f "proxy-config.env" ]; then
        # 验证配置文件
        if ! validate_config "proxy-config.env" true; then
            log_warning "配置文件存在问题"
            validate_config "proxy-config.env" false
            echo
            read -p "是否继续使用此配置？[y/N]: " force_use
            if [[ ! "$force_use" =~ ^[yY] ]]; then
                log_info "请选择其他启动方式或重新配置"
                return 1
            fi
        fi

        log_info "发现已有配置文件，是否使用？"
        read -p "使用已有配置启动？[Y/n]: " use_config
        case "$use_config" in
            [nN]|[nN][oO])
                log_info "请选择启动方式："
                echo "  1) 使用默认参数启动"
                echo "  2) 手动输入参数启动"
                echo "  3) 重新配置"
                read -p "请选择 [1-3]: " start_option

                case "$start_option" in
                    1)
                        log_info "使用默认参数启动代理..."
                        PORT=""
                        USERNAME=""
                        PASSWORD=""
                        DAEMON=true
                        start_proxy
                        ;;
                    2)
                        echo
                        read -p "端口 (留空使用随机端口): " port
                        read -p "用户名 (留空自动生成): " username
                        read -s -p "密码 (留空自动生成): " password
                        echo
                        read -p "IP白名单 (留空禁用): " whitelist

                        PORT="$port"
                        USERNAME="$username"
                        PASSWORD="$password"
                        WHITELIST="$whitelist"
                        DAEMON=true

                        start_proxy
                        ;;
                    3)
                        main_configure
                        return
                        ;;
                    *)
                        log_error "无效选择"
                        return 1
                        ;;
                esac
                ;;
            *)
                # 使用已有配置
                source proxy-config.env
                PORT="$PROXY_PORT"
                USERNAME="$PROXY_USERNAME"
                PASSWORD="$PROXY_PASSWORD"
                DAEMON=true
                if [ "$ENABLE_WHITELIST" = true ] && [ -n "$WHITELIST_ITEMS" ]; then
                    WHITELIST="$WHITELIST_ITEMS"
                fi

                log_info "使用已有配置启动代理..."
                start_proxy
                ;;
        esac
    else
        log_info "未发现配置文件"
        read -p "是否先进行配置？[Y/n]: " do_config
        case "$do_config" in
            [nN]|[nN][oO])
                log_info "使用默认参数启动代理..."
                PORT=""
                USERNAME=""
                PASSWORD=""
                DAEMON=true
                start_proxy
                ;;
            *)
                main_configure
                return
                ;;
        esac
    fi

    wait_for_key
}

# 主循环
main_loop() {
    while true; do
        show_banner
        show_menu

        read -p "请选择功能 [1-16] (或按 q 退出): " choice
        echo

        case "$choice" in
            1)
                install_xray
                ;;
            2)
                main_configure
                ;;
            3)
                start_proxy_service
                ;;
            4)
                log_header "⏹️ 停止代理服务"
                echo
                log_info "正在停止代理服务..."
                stop_proxy
                wait_for_key
                ;;
            5)
                view_edit_config
                ;;
            6)
                show_config_validation
                wait_for_key
                ;;
            7)
                manage_whitelist
                ;;
            8)
                test_playwright
                ;;
            9)
                show_proxy_status
                ;;
            10)
                show_system_info
                ;;
            11)
                restart_proxy_service
                ;;
            12)
                enable_autostart
                ;;
            13)
                disable_autostart
                ;;
            14)
                check_autostart_status
                ;;
            15)
                cleanup_files
                ;;
            16)
                show_help
                ;;
            [qQ]|[qQ][uU][iI][tT])
                log_info "感谢使用 Xray HTTP 代理一体化脚本！"
                exit 0
                ;;
            *)
                log_error "无效选择，请输入 1-16 或 q"
                sleep 2
                ;;
        esac
    done
}

# =============================================================================
# 命令行参数处理
# =============================================================================

# 显示命令行帮助
show_cli_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

用法: $0 [选项]

交互模式（无参数时）:
    $0                          启动交互式主菜单

快速操作:
    $0 --install               安装 Xray 核心
    $0 --configure             交互式配置代理
    $0 --start                 启动代理服务
    $0 --stop                  停止代理服务
    $0 --status                查看代理状态
    $0 --restart               重启代理服务
    $0 --whitelist             管理白名单
    $0 --test                  测试 Playwright 集成
    $0 --info                  查看系统信息
    $0 --cleanup               清理配置文件
    $0 --validate-config       验证配置文件

开机自启动:
    $0 --enable-autostart      启用开机自启动
    $0 --disable-autostart     禁用开机自启动
    $0 --autostart-status      查看自启动状态

启动选项:
    -p, --port PORT            代理端口 (默认随机生成)
    -u, --username USER        用户名 (默认自动生成)
    -P, --password PASS        密码 (默认自动生成)
    -w, --whitelist IPS        IP白名单，用逗号分隔
    -d, --daemon               后台运行
    -c, --config FILE          配置文件路径

其他选项:
    -h, --help                 显示此帮助信息
    -v, --version              显示版本信息

示例:
    $0                                    # 交互模式
    $0 --start                           # 快速启动（随机端口）
    $0 --start -p 8080 -d               # 指定端口后台启动
    $0 --start -w "127.0.0.1,192.168.1.0/24"  # 启用白名单
    $0 --configure                      # 交互式配置
    $0 --whitelist                      # 管理白名单

EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install|install)
                install_xray
                exit 0
                ;;
            --configure|configure)
                main_configure
                exit 0
                ;;
            --start|start)
                DAEMON=true
                shift
                ;;
            --stop|stop)
                stop_proxy
                exit 0
                ;;
            --status|status)
                check_status
                exit $?
                ;;
            --restart|restart)
                restart_proxy_service
                exit 0
                ;;
            --whitelist|whitelist)
                manage_whitelist
                exit 0
                ;;
            --test|test)
                test_playwright
                exit 0
                ;;
            --info|info)
                show_system_info
                exit 0
                ;;
            --cleanup|cleanup)
                cleanup_files
                exit 0
                ;;
            --validate-config|validate-config)
                show_config_validation
                exit 0
                ;;
            --enable-autostart|enable-autostart)
                enable_autostart
                exit 0
                ;;
            --disable-autostart|disable-autostart)
                disable_autostart
                exit 0
                ;;
            --autostart-status|autostart-status)
                check_autostart_status
                exit 0
                ;;
            -p|--port)
                PORT="$2"
                shift 2
                ;;
            -u|--username)
                USERNAME="$2"
                shift 2
                ;;
            -P|--password)
                PASSWORD="$2"
                shift 2
                ;;
            -w|--whitelist)
                WHITELIST="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -d|--daemon)
                DAEMON=true
                shift
                ;;
            -h|--help)
                show_cli_help
                exit 0
                ;;
            -v|--version)
                echo "$SCRIPT_NAME v$SCRIPT_VERSION"
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_cli_help
                exit 1
                ;;
        esac
    done
}

# =============================================================================
# 主函数
# =============================================================================

main() {
    # 解析命令行参数
    parse_args "$@"

    # 如果设置了启动标志，直接启动代理
    if [ "$DAEMON" = true ] && [[ "$*" =~ (--start|start) ]]; then
        start_proxy
        exit $?
    fi

    # 否则进入交互模式
    main_loop
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi