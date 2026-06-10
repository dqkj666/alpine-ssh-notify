#!/bin/bash

###############################################################################
# Alpine SSH Login Telegram Notification - Helper Functions Library
# 辅助函数库 - 提供通用的函数支持
###############################################################################

set -euo pipefail

###############################################################################
# 颜色和格式化函数
###############################################################################

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 文本样式
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${PURPLE}🐛 DEBUG: $1${NC}"
    fi
}

print_header() {
    echo -e "\n${CYAN}${BOLD}=== $1 ===${NC}\n"
}

print_subheader() {
    echo -e "${CYAN}▶ $1${NC}"
}

print_separator() {
    echo -e "${CYAN}────────────────────────────────────────────────────${NC}"
}

###############################################################################
# 系统检查函数
###############################################################################

check_command() {
    local cmd="$1"
    if ! command -v "${cmd}" &> /dev/null; then
        return 1
    fi
    return 0
}

check_file() {
    local file="$1"
    if [[ ! -f "${file}" ]]; then
        return 1
    fi
    return 0
}

check_dir() {
    local dir="$1"
    if [[ ! -d "${dir}" ]]; then
        return 1
    fi
    return 0
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        return 1
    fi
    return 0
}

check_alpine() {
    if grep -q "Alpine" /etc/os-release 2>/dev/null; then
        return 0
    fi
    return 1
}

###############################################################################
# 网络检查函数
###############################################################################

check_internet() {
    local timeout=${1:-5}
    if timeout "${timeout}" curl -s https://api.telegram.org > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

check_telegram_token() {
    local token="$1"
    if curl -s "https://api.telegram.org/bot${token}/getMe" | grep -q '"ok":true'; then
        return 0
    fi
    return 1
}

###############################################################################
# 字符串处理函数
###############################################################################

trim() {
    local string="$1"
    echo "${string}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

urlencode() {
    local string="$1"
    echo -n "${string}" | od -An -tx1 | tr ' ' % | tr -d '\n'
}

escape_json() {
    local string="$1"
    echo "${string}" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/g' | tr -d '\n'
}

###############################################################################
# IP地址函数
###############################################################################

validate_ipv4() {
    local ip="$1"
    if [[ ${ip} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    fi
    return 1
}

get_ipv4() {
    local method="${1:-ifconfig}"
    local timeout="${2:-10}"
    
    case "${method}" in
        ifconfig)
            curl -s --max-time "${timeout}" --connect-timeout 5 http://ifconfig.me 2>/dev/null || echo ""
            ;;
        ipify)
            curl -s --max-time "${timeout}" --connect-timeout 5 https://api.ipify.org 2>/dev/null || echo ""
            ;;
        myip)
            curl -s --max-time "${timeout}" --connect-timeout 5 http://myip.ipip.net 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+' || echo ""
            ;;
        *)
            echo ""
            ;;
    esac
}

###############################################################################
# 日期时间函数
###############################################################################

get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

get_timestamp_iso() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

get_epoch() {
    date '+%s'
}

###############################################################################
# 文件操作函数
###############################################################################

backup_file() {
    local file="$1"
    if [[ -f "${file}" ]]; then
        local backup="${file}.backup.$(get_epoch)"
        cp "${file}" "${backup}"
        print_info "已创建备份: ${backup}"
        return 0
    fi
    return 1
}

create_temp_file() {
    mktemp -t ssh-notify-XXXXXX 2>/dev/null || mktemp /tmp/ssh-notify-XXXXXX
}

###############################################################################
# 配置文件函数
###############################################################################

load_config() {
    local config_file="$1"
    if [[ ! -f "${config_file}" ]]; then
        print_error "配置文件未找到: ${config_file}"
        return 1
    fi
    
    if ! source "${config_file}" 2>/dev/null; then
        print_error "加载配置文件失败"
        return 1
    fi
    
    return 0
}

validate_config() {
    local required_vars=("$@")
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("${var}")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        print_error "缺失必需配置: ${missing_vars[*]}"
        return 1
    fi
    
    return 0
}

###############################################################################
# 日志函数
###############################################################################

log_to_file() {
    local level="$1"
    local message="$2"
    local log_file="${3:-/var/log/ssh-notify.log}"
    local timestamp=$(get_timestamp)
    
    if [[ -w "${log_file}" ]] || [[ -w "$(dirname "${log_file}")" ]]; then
        echo "[${timestamp}] [${level}] ${message}" >> "${log_file}" 2>/dev/null || true
    fi
}

###############################################################################
# Telegram函数
###############################################################################

send_telegram_message() {
    local token="$1"
    local chat_id="$2"
    local message="$3"
    local timeout="${4:-10}"
    
    local escaped_message=$(echo "${message}" | sed 's/"/\\"/g' | sed "s/\\\\/\\\\\\\\/g")
    
    local response=$(curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        -H "Content-Type: application/json" \
        --max-time "${timeout}" \
        --connect-timeout 5 \
        -d @- <<< '{
            "chat_id": '"${chat_id}"',
            "text": "'"${escaped_message}"'"
        }' 2>/dev/null)
    
    if echo "${response}" | grep -q '"ok":true'; then
        return 0
    fi
    
    return 1
}

get_telegram_bot_info() {
    local token="$1"
    local timeout="${2:-10}"
    
    curl -s "https://api.telegram.org/bot${token}/getMe" \
        --max-time "${timeout}" \
        --connect-timeout 5 \
        2>/dev/null
}

###############################################################################
# 系统服务函数
###############################################################################

restart_ssh_service() {
    if command -v rc-service &> /dev/null; then
        print_info "重启 SSH 服务 (OpenRC)..."
        rc-service sshd restart > /dev/null 2>&1
    elif command -v systemctl &> /dev/null; then
        print_info "重启 SSH 服务 (systemd)..."
        systemctl restart sshd > /dev/null 2>&1
    else
        print_error "无法确定系统初始化系统"
        return 1
    fi
    
    return 0
}

get_ssh_status() {
    if command -v rc-service &> /dev/null; then
        rc-service sshd status
    elif command -v systemctl &> /dev/null; then
        systemctl status sshd
    fi
}

###############################################################################
# 权限函数
###############################################################################

set_permissions() {
    local file="$1"
    local perms="${2:-755}"
    
    if [[ -e "${file}" ]]; then
        chmod "${perms}" "${file}"
        return 0
    fi
    
    return 1
}

check_file_readable() {
    local file="$1"
    if [[ -r "${file}" ]]; then
        return 0
    fi
    return 1
}

check_file_writable() {
    local file="$1"
    if [[ -w "${file}" ]]; then
        return 0
    fi
    return 1
}

###############################################################################
# 包管理函数
###############################################################################

install_package() {
    local package="$1"
    
    if check_command apk; then
        apk add --no-cache "${package}"
    elif check_command apt-get; then
        apt-get update && apt-get install -y "${package}"
    elif check_command yum; then
        yum install -y "${package}"
    else
        print_error "无法确定包管理器"
        return 1
    fi
}

###############################################################################
# 验证函数
###############################################################################

is_valid_email() {
    local email="$1"
    if [[ ${email} =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    fi
    return 1
}

is_valid_url() {
    local url="$1"
    if [[ ${url} =~ ^https?://[^[:space:]] ]]; then
        return 0
    fi
    return 1
}

###############################################################################
# 导出函数（如果被sourced）
###############################################################################

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f print_info print_success print_warn print_error print_debug
    export -f check_command check_file check_dir check_root check_alpine
    export -f check_internet check_telegram_token
    export -f trim urlencode escape_json
    export -f validate_ipv4 get_ipv4
    export -f get_timestamp get_timestamp_iso get_epoch
    export -f backup_file create_temp_file
    export -f load_config validate_config
    export -f log_to_file
    export -f send_telegram_message get_telegram_bot_info
    export -f restart_ssh_service get_ssh_status
    export -f set_permissions check_file_readable check_file_writable
    export -f install_package
    export -f is_valid_email is_valid_url
fi
