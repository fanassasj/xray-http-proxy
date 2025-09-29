#!/bin/bash

# Xray HTTP 代理启动脚本

set -e

# 默认配置
DEFAULT_PORT=""  # 将使用随机端口
DEFAULT_USERNAME=""
DEFAULT_PASSWORD=""
DEFAULT_WHITELIST=""
DEFAULT_CONFIG_FILE="xray-proxy-config.json"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# 显示帮助信息
show_help() {
    cat << EOF
Xray HTTP 代理启动脚本

用法: $0 [选项]

选项:
    -p, --port PORT         代理端口 (未指定时自动生成随机端口 10000-65535)
    -u, --username USER     用户名 (未指定时自动生成)
    -P, --password PASS     密码 (未指定时自动生成)
    -w, --whitelist IPS     客户端IP白名单，用逗号分隔 (限制哪些IP可以连接代理)
    -c, --config FILE       配置文件路径 (默认: xray-proxy-config.json)
    -d, --daemon            后台运行
    -s, --stop              停止运行中的代理
    -S, --status            显示代理状态
    -h, --help              显示此帮助信息

示例:
    $0 -d                                        # 使用随机端口启动
    $0 -p 12345 -w "127.0.0.1,192.168.1.0/24"   # 指定端口和白名单
    $0 -u myuser -P mypass -d                    # 自定义认证
    $0 --stop
    $0 --status

注意: 白名单用于限制客户端IP访问，如不设置则允许所有IP连接

EOF
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

# 获取服务器外部IP
get_external_ip() {
    local external_ip
    external_ip=$(curl -s --connect-timeout 5 http://checkip.amazonaws.com 2>/dev/null || \
                 curl -s --connect-timeout 5 http://ipinfo.io/ip 2>/dev/null || \
                 curl -s --connect-timeout 5 http://icanhazip.com 2>/dev/null || \
                 echo "127.0.0.1")
    echo "$external_ip" | tr -d '\n'
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
    "loglevel": "warning"
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

    # 如果有IP白名单，添加路由规则（基于来源IP限制）
    if [ -n "$WHITELIST" ]; then
        # 将逗号分隔的IP转换为 JSON 数组
        local ips_json
        ips_json=$(echo "$WHITELIST" | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/')

        config_content="${config_content},
  \"routing\": {
    \"rules\": [
      {
        \"type\": \"field\",
        \"source\": [$ips_json],
        \"outboundTag\": \"direct\"
      },
      {
        \"type\": \"field\",
        \"network\": \"tcp,udp\",
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

# 停止代理
stop_proxy() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "正在停止代理 (PID: $pid)..."
            kill "$pid"

            # 等待进程结束
            local count=0
            while kill -0 "$pid" 2>/dev/null && [ $count -lt 10 ]; do
                sleep 1
                count=$((count + 1))
            done

            if kill -0 "$pid" 2>/dev/null; then
                log_warning "进程未正常结束，强制终止..."
                kill -9 "$pid"
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
        exit 1
    fi

    # 检查 xray 是否可用
    if ! command -v xray >/dev/null 2>&1; then
        log_error "xray 未安装或不在 PATH 中"
        log_info "请先运行安装脚本: ./install-xray.sh"
        exit 1
    fi

    # 生成配置
    generate_config

    local external_ip
    external_ip=$(get_external_ip)

    log_info "启动 Xray HTTP 代理..."
    log_info "端口: $PORT"
    log_info "用户名: $USERNAME"
    log_info "密码: $PASSWORD"
    log_info "本地访问: http://$USERNAME:$PASSWORD@127.0.0.1:$PORT"
    log_info "外部访问: http://$USERNAME:$PASSWORD@$external_ip:$PORT"
    if [ -n "$WHITELIST" ]; then
        log_info "白名单: $WHITELIST"
    fi

    if [ "$DAEMON" = true ]; then
        # 后台运行
        nohup xray run -config "$CONFIG_FILE" > /dev/null 2>&1 &
        local pid=$!
        echo $pid > "$PID_FILE"
        log_success "代理已在后台启动 (PID: $pid)"

        # 等待一下确保启动成功
        sleep 2
        if ! kill -0 "$pid" 2>/dev/null; then
            log_error "代理启动失败"
            rm -f "$PID_FILE"
            exit 1
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

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
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
            -s|--stop)
                STOP=true
                shift
                ;;
            -S|--status)
                STATUS=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 主函数
main() {
    parse_args "$@"

    if [ "$STATUS" = true ]; then
        check_status
        exit $?
    fi

    if [ "$STOP" = true ]; then
        stop_proxy
        exit 0
    fi

    start_proxy
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi