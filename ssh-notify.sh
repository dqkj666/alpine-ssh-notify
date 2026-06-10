#!/bin/bash

###############################################################################
# SSH Login Telegram Notification Script for Alpine Linux
# SSH登录Telegram通知脚本 - 核心脚本
###############################################################################

set -euo pipefail

# 配置文件路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

###############################################################################
# 日志函数
###############################################################################

log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "${ENABLE_LOG:-yes}" == "yes" ]]; then
        echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE:-/var/log/ssh-notify.log}" 2>/dev/null || true
    fi
}

###############################################################################
# 配置加载
###############################################################################

load_config() {
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log "ERROR" "Config file not found: ${CONFIG_FILE}"
        return 1
    fi
    
    # 安全地加载配置文件
    if ! source "${CONFIG_FILE}" 2>/dev/null; then
        log "ERROR" "Failed to load config file"
        return 1
    fi
    
    # 验证必需的配置
    if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]] || [[ -z "${TELEGRAM_CHAT_ID:-}" ]]; then
        log "ERROR" "Missing required config: TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID"
        return 1
    fi
    
    return 0
}

###############################################################################
# 获取公网IP
###############################################################################

get_public_ip() {
    local method="${PUBLIC_IP_METHOD:-ifconfig}"
    local timeout="${TIMEOUT:-10}"
    local ip=""
    local retry=0
    local max_retry=3
    
    while [[ ${retry} -lt ${max_retry} ]]; do
        retry=$((retry + 1))
        
        case "${method}" in
            ifconfig)
                ip=$(curl -s --max-time "${timeout}" --connect-timeout 5 http://ifconfig.me 2>/dev/null || echo "")
                ;;
            ipify)
                ip=$(curl -s --max-time "${timeout}" --connect-timeout 5 https://api.ipify.org 2>/dev/null || echo "")
                ;;
            myip)
                ip=$(curl -s --max-time "${timeout}" --connect-timeout 5 http://myip.ipip.net 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+' || echo "")
                ;;
            *)
                ip=$(curl -s --max-time "${timeout}" --connect-timeout 5 http://ifconfig.me 2>/dev/null || echo "")
                ;;
        esac
        
        # 验证IP格式
        if [[ ${ip} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "${ip}"
            return 0
        fi
    done
    
    log "WARN" "Failed to retrieve public IP after ${max_retry} attempts"
    echo "Unknown"
    return 1
}

###############################################################################
# 获取登录信息
###############################################################################

get_login_info() {
    local ssh_client="${SSH_CLIENT:-}"
    local user="${SSH_USER:-${SUDO_USER:-${PAM_USER:-unknown}}}"
    local login_ip="Unknown"
    local login_port="Unknown"
    
    # 从SSH_CLIENT提取IP和端口 (格式: "192.168.1.100 54321 22")
    if [[ -n "${ssh_client}" ]]; then
        login_ip=$(echo "${ssh_client}" | awk '{print $1}')
        login_port=$(echo "${ssh_client}" | awk '{print $2}')
    fi
    
    echo "${user}|${login_ip}|${login_port}"
}

###############################################################################
# 构建通知消息
###############################################################################

build_message() {
    local user="$1"
    local server_ip="$2"
    local login_ip="$3"
    local login_port="$4"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S %Z')
    
    cat <<EOF
🔐 SSH 登录通知

👤 用户名: ${user}
🌍 服务器IP: ${server_ip}
📍 登录IP: ${login_ip}${login_port:+:$login_port}
🕐 时间: ${timestamp}

_由 alpine-ssh-notify 发送_
EOF
}

###############################################################################
# 发送Telegram通知
###############################################################################

send_telegram_notification() {
    local message="$1"
    local bot_token="${TELEGRAM_BOT_TOKEN}"
    local chat_id="${TELEGRAM_CHAT_ID}"
    local timeout="${TIMEOUT:-10}"
    local retry_count="${RETRY_COUNT:-3}"
    local retry_delay="${RETRY_DELAY:-2}"
    
    local attempt=0
    local http_code=""
    
    while [[ ${attempt} -lt ${retry_count} ]]; do
        attempt=$((attempt + 1))
        
        log "INFO" "Sending Telegram notification (attempt ${attempt}/${retry_count})"
        
        # 准备消息（转义特殊字符）
        local escaped_message=$(echo "${message}" | sed 's/"/\\"/g' | sed "s/\\\\/\\\\\\\\/g")
        
        # 使用curl发送POST请求
        http_code=$(curl -s -w "%{http_code}" -o /tmp/telegram_response.txt \
            --max-time "${timeout}" \
            --connect-timeout 5 \
            -X POST "https://api.telegram.org/bot${bot_token}/sendMessage" \
            -H "Content-Type: application/json" \
            -d @- <<< '{
                "chat_id": '"${chat_id}"',
                "text": "'"${escaped_message}"'"
            }' 2>/dev/null || echo "000")
        
        # 检查响应状态码
        if [[ "${http_code}" == "200" ]]; then
            log "INFO" "Telegram notification sent successfully"
            return 0
        else
            log "WARN" "Telegram API returned HTTP ${http_code}"
            
            if [[ ${attempt} -lt ${retry_count} ]]; then
                log "INFO" "Retrying in ${retry_delay} seconds..."
                sleep "${retry_delay}"
            fi
        fi
    done
    
    log "ERROR" "Failed to send Telegram notification after ${retry_count} attempts"
    return 1
}

###############################################################################
# 测试模式
###############################################################################

test_mode() {
    echo -e "${GREEN}=== SSH Notify Test Mode ===${NC}\n"
    
    if ! load_config; then
        echo -e "${RED}Failed to load configuration${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Testing public IP retrieval...${NC}"
    local server_ip
    server_ip=$(get_public_ip)
    echo -e "${GREEN}✓ Server IP: ${server_ip}${NC}\n"
    
    echo -e "${YELLOW}Building test message...${NC}"
    local test_message=$(build_message "testuser" "${server_ip}" "192.168.1.100" "54321")
    echo -e "${GREEN}✓ Message built:${NC}"
    echo "${test_message}\n"
    
    echo -e "${YELLOW}Sending test notification to Telegram...${NC}"
    if send_telegram_notification "${test_message}"; then
        echo -e "${GREEN}✓ Test notification sent successfully!${NC}"
        exit 0
    else
        echo -e "${RED}✗ Failed to send test notification${NC}"
        exit 1
    fi
}

###############################################################################
# 主函数
###############################################################################

main() {
    # 检查是否在SSH会话中或被PAM调用
    local is_ssh_session=0
    if [[ -n "${SSH_CLIENT:-}" ]] || [[ -n "${SSH_USER:-}" ]] || [[ -n "${PAM_USER:-}" ]]; then
        is_ssh_session=1
    fi
    
    # 加载配置
    if ! load_config; then
        log "ERROR" "Failed to load configuration"
        exit 1
    fi
    
    # 如果没有SSH环境变量，可能不是有效的SSH登录
    if [[ ${is_ssh_session} -eq 0 ]]; then
        log "DEBUG" "Not in SSH session, skipping notification"
        exit 0
    fi
    
    # 获取公网IP
    local server_ip
    server_ip=$(get_public_ip)
    log "INFO" "Server IP: ${server_ip}"
    
    # 获取登录信息
    local login_info
    login_info=$(get_login_info)
    local user=$(echo "${login_info}" | cut -d'|' -f1)
    local login_ip=$(echo "${login_info}" | cut -d'|' -f2)
    local login_port=$(echo "${login_info}" | cut -d'|' -f3)
    
    log "INFO" "SSH login detected for user: ${user}, from: ${login_ip}:${login_port}"
    
    # 检查是否应该跳过该用户的通知
    if [[ -n "${SKIP_USERS:-}" ]]; then
        for skip_user in ${SKIP_USERS}; do
            if [[ "${user}" == "${skip_user}" ]]; then
                log "INFO" "User ${user} is in SKIP_USERS list, skipping notification"
                exit 0
            fi
        done
    fi
    
    # 构建通知消息
    local message
    message=$(build_message "${user}" "${server_ip}" "${login_ip}" "${login_port}")
    
    # 发送通知（后台异步执行，不阻塞SSH登录）
    # 将错误输出重定向到黑洞，避免影响SSH登录
    send_telegram_notification "${message}" &> /dev/null &
    
    exit 0
}

###############################################################################
# 命令行参数处理
###############################################################################

case "${1:-}" in
    --test)
        test_mode
        ;;
    *)
        main "$@"
        ;;
esac
