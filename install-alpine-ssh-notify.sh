#!/bin/bash

###############################################################################
# Alpine SSH Login Telegram Notification - One-Click Installer
# 一键安装脚本：自动下载、安装并配置SSH登录Telegram通知
###############################################################################

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
INSTALL_DIR="/opt/alpine-ssh-notify"
GITHUB_REPO="https://raw.githubusercontent.com/dqkj666/alpine-ssh-notify/main"
LOG_FILE="/var/log/ssh-notify.log"

###############################################################################
# 帮助函数
###############################################################################

print_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║   Alpine SSH Login Telegram Notification Installer            ║
║   基于Alpine的SSH登录Telegram通知脚本 - 一键安装              ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

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

print_step() {
    echo -e "${YELLOW}\n>>> $1${NC}"
}

###############################################################################
# 检查和安装依赖
###############################################################################

check_system() {
    print_step "Step 1: 检查系统环境"
    
    # 检查是否是Alpine Linux
    if ! grep -q "Alpine" /etc/os-release 2>/dev/null; then
        print_warn "This script is designed for Alpine Linux, but may work on other systems"
    else
        print_success "Alpine Linux detected"
    fi
    
    # 检查root权限
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        echo "Please run: sudo bash $0"
        exit 1
    fi
    print_success "Root privileges confirmed"
}

install_dependencies() {
    print_step "Step 2: 安装依赖"
    
    local required_tools=("curl" "bash")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "${tool}" &> /dev/null; then
            missing_tools+=("${tool}")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_info "Installing missing tools: ${missing_tools[*]}"
        apk update
        apk add --no-cache "${missing_tools[@]}"
        print_success "Dependencies installed"
    else
        print_success "All dependencies already installed"
    fi
}

###############################################################################
# 下载脚本文件
###############################################################################

download_files() {
    print_step "Step 3: 下载脚本文件"
    
    # 创建安装目录
    if [[ ! -d "${INSTALL_DIR}" ]]; then
        print_info "Creating directory: ${INSTALL_DIR}"
        mkdir -p "${INSTALL_DIR}"
    fi
    
    # 定义要下载的文件
    local files=("ssh-notify.sh" "config.example" "test.sh")
    
    for file in "${files[@]}"; do
        print_info "Downloading ${file}..."
        
        if curl -sfL "${GITHUB_REPO}/${file}" -o "${INSTALL_DIR}/${file}"; then
            chmod +x "${INSTALL_DIR}/${file}"
            print_success "Downloaded: ${file}"
        else
            print_error "Failed to download: ${file}"
            print_error "URL: ${GITHUB_REPO}/${file}"
            exit 1
        fi
    done
    
    # 复制config.example为config（如果不存在）
    if [[ ! -f "${INSTALL_DIR}/config" ]]; then
        cp "${INSTALL_DIR}/config.example" "${INSTALL_DIR}/config"
        chmod 600 "${INSTALL_DIR}/config"
        print_success "Created config file"
    else
        print_warn "Config file already exists, skipping"
    fi
}

###############################################################################
# 交互式配置
###############################################################################

interactive_config() {
    print_step "Step 4: 交互式配置"
    
    echo ""
    echo "请输入Telegram配置信息"
    echo "═════════════════════════════════════════"
    echo ""
    
    # Bot Token
    while true; do
        echo -e "${YELLOW}请输入Telegram Bot Token:${NC}"
        echo "(格式: 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11)"
        read -p "Bot Token: " BOT_TOKEN
        
        if [[ -z "${BOT_TOKEN}" ]]; then
            print_error "Bot Token cannot be empty"
            continue
        fi
        
        # 基本验证
        if [[ ${BOT_TOKEN} =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
            print_success "Bot Token accepted"
            break
        else
            print_error "Invalid Bot Token format"
        fi
    done
    
    # Chat ID
    while true; do
        echo ""
        echo -e "${YELLOW}请输入Telegram Chat ID:${NC}"
        echo "(格式: 数字，例如: 987654321)"
        echo "获取Chat ID的方法:"
        echo "  1. 给你的bot发送任意消息"
        echo "  2. 访问: https://api.telegram.org/bot<TOKEN>/getUpdates"
        echo "  3. 查找返回JSON中的 \"id\" 字段"
        read -p "Chat ID: " CHAT_ID
        
        if [[ -z "${CHAT_ID}" ]]; then
            print_error "Chat ID cannot be empty"
            continue
        fi
        
        if [[ ${CHAT_ID} =~ ^-?[0-9]+$ ]]; then
            print_success "Chat ID accepted"
            break
        else
            print_error "Invalid Chat ID format"
        fi
    done
    
    # 公网IP获取方式
    echo ""
    echo -e "${YELLOW}选择公网IP获取方式 (默认: ifconfig):${NC}"
    echo "  1) ifconfig  (http://ifconfig.me)"
    echo "  2) ipify     (https://api.ipify.org)"
    echo "  3) myip      (http://myip.ipip.net)"
    read -p "选择 [1-3] (默认1): " IP_METHOD_CHOICE
    IP_METHOD_CHOICE=${IP_METHOD_CHOICE:-1}
    
    case ${IP_METHOD_CHOICE} in
        1) PUBLIC_IP_METHOD="ifconfig" ;;
        2) PUBLIC_IP_METHOD="ipify" ;;
        3) PUBLIC_IP_METHOD="myip" ;;
        *) PUBLIC_IP_METHOD="ifconfig" ;;
    esac
    print_success "Public IP method: ${PUBLIC_IP_METHOD}"
    
    # 日志级别
    echo ""
    echo -e "${YELLOW}选择日志级别 (默认: INFO):${NC}"
    echo "  1) DEBUG (详细调试信息)"
    echo "  2) INFO  (普通信息)"
    echo "  3) WARN  (仅警告错误)"
    read -p "选择 [1-3] (默认2): " LOG_LEVEL_CHOICE
    LOG_LEVEL_CHOICE=${LOG_LEVEL_CHOICE:-2}
    
    case ${LOG_LEVEL_CHOICE} in
        1) LOG_LEVEL="DEBUG" ;;
        2) LOG_LEVEL="INFO" ;;
        3) LOG_LEVEL="WARN" ;;
        *) LOG_LEVEL="INFO" ;;
    esac
    print_success "Log level: ${LOG_LEVEL}"
    
    # 更新配置文件
    print_info "Updating configuration..."
    
    # 使用sed安全地更新配置文件
    sed -i "s|TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=\"${BOT_TOKEN}\"|" "${INSTALL_DIR}/config"
    sed -i "s|TELEGRAM_CHAT_ID=.*|TELEGRAM_CHAT_ID=\"${CHAT_ID}\"|" "${INSTALL_DIR}/config"
    sed -i "s|PUBLIC_IP_METHOD=.*|PUBLIC_IP_METHOD=\"${PUBLIC_IP_METHOD}\"|" "${INSTALL_DIR}/config"
    sed -i "s|LOG_LEVEL=.*|LOG_LEVEL=\"${LOG_LEVEL}\"|" "${INSTALL_DIR}/config"
    
    print_success "Configuration updated"
}

###############################################################################
# 测试配置
###############################################################################

test_configuration() {
    print_step "Step 5: 测试配置"
    
    echo ""
    echo "正在测试Telegram连接..."
    
    # 加载配置
    source "${INSTALL_DIR}/config"
    
    # 测试公网IP获取
    print_info "Testing public IP retrieval..."
    PUBLIC_IP=$(curl -s --max-time 5 http://ifconfig.me 2>/dev/null || echo "")
    
    if [[ -n "${PUBLIC_IP}" ]]; then
        print_success "Public IP retrieved: ${PUBLIC_IP}"
    else
        print_warn "Could not retrieve public IP (network may be unavailable)"
    fi
    
    # 测试Telegram API
    print_info "Testing Telegram API..."
    
    local test_message="✅ Alpine SSH Notify Installation Test\n\nServer IP: ${PUBLIC_IP:-Unknown}\nTime: $(date '+%Y-%m-%d %H:%M:%S')"
    
    local response=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -H "Content-Type: application/json" \
        -d '{
            "chat_id": '"${TELEGRAM_CHAT_ID}"',
            "text": "✅ Alpine SSH Notify Test Message\n\nServer: '"${PUBLIC_IP:-Unknown}"'\nTime: '"$(date '+%Y-%m-%d %H:%M:%S')"'"
        }')
    
    if echo "${response}" | grep -q '"ok":true'; then
        print_success "Telegram test message sent successfully!"
        echo "Check your Telegram account for the test message"
    else
        print_error "Failed to send test message"
        print_error "Response: ${response}"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Verify Bot Token is correct"
        echo "  2. Verify Chat ID is correct"
        echo "  3. Check network connectivity"
        echo "  4. Make sure bot is started in Telegram"
        return 1
    fi
}

###############################################################################
# PAM配置
###############################################################################

configure_pam() {
    print_step "Step 6: 配置PAM模块"
    
    local PAM_CONFIG="/etc/pam.d/sshd"
    local PAM_LINE="session optional pam_exec.so /opt/alpine-ssh-notify/ssh-notify.sh"
    
    if [[ ! -f "${PAM_CONFIG}" ]]; then
        print_error "PAM SSH config file not found: ${PAM_CONFIG}"
        return 1
    fi
    
    if grep -q "${PAM_LINE}" "${PAM_CONFIG}"; then
        print_success "PAM already configured"
        return 0
    fi
    
    # 备份原配置
    cp "${PAM_CONFIG}" "${PAM_CONFIG}.backup.$(date +%s)"
    print_info "Created backup: ${PAM_CONFIG}.backup"
    
    # 添加PAM配置
    echo "${PAM_LINE}" >> "${PAM_CONFIG}"
    print_success "PAM configuration added"
}

###############################################################################
# 权限设置和日志初始化
###############################################################################

setup_permissions() {
    print_step "Step 7: 设置权限"
    
    # ��置脚本权限
    chmod 755 "${INSTALL_DIR}/ssh-notify.sh"
    chmod 755 "${INSTALL_DIR}/test.sh"
    chmod 600 "${INSTALL_DIR}/config"
    chmod 755 "${INSTALL_DIR}"
    
    print_success "Script permissions set"
    
    # 创建日志文件
    print_info "Initializing log file: ${LOG_FILE}"
    touch "${LOG_FILE}"
    chmod 666 "${LOG_FILE}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] SSH Notify initialized" >> "${LOG_FILE}"
    
    print_success "Log file initialized"
}

###############################################################################
# 重启SSH服务
###############################################################################

restart_ssh() {
    print_step "Step 8: 重启SSH服务"
    
    print_warn "This will restart SSH service. Active connections may be interrupted."
    read -p "Continue? [y/N]: " -n 1 -r CONTINUE
    echo ""
    
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        print_warn "SSH service restart skipped"
        print_warn "Please restart SSH manually for changes to take effect:"
        echo "  rc-service sshd restart    # OpenRC"
        echo "  systemctl restart sshd     # systemd"
        return 0
    fi
    
    if command -v rc-service &> /dev/null; then
        print_info "Restarting SSH (OpenRC)..."
        rc-service sshd restart || {
            print_error "Failed to restart SSH service"
            return 1
        }
    elif command -v systemctl &> /dev/null; then
        print_info "Restarting SSH (systemd)..."
        systemctl restart sshd || {
            print_error "Failed to restart SSH service"
            return 1
        }
    else
        print_error "Could not determine init system"
        return 1
    fi
    
    print_success "SSH service restarted"
}

###############################################################################
# 完成总结
###############################################################################

print_summary() {
    print_step "Installation Complete!"
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         Alpine SSH Notify Successfully Installed!              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo "📁 Installation Directory: ${INSTALL_DIR}"
    echo "📝 Log File: ${LOG_FILE}"
    echo ""
    
    echo "📋 Installed Files:"
    echo "  • ssh-notify.sh       - Main notification script"
    echo "  • config              - Configuration file"
    echo "  • config.example      - Configuration template"
    echo "  • test.sh             - Test script"
    echo ""
    
    echo "🚀 Usage:"
    echo "  • Test notification: ${INSTALL_DIR}/test.sh"
    echo "  • Edit config: nano ${INSTALL_DIR}/config"
    echo "  • View logs: tail -f ${LOG_FILE}"
    echo "  • Uninstall: ${INSTALL_DIR}/uninstall.sh"
    echo ""
    
    echo "✨ Next Steps:"
    echo "  1. SSH login from another machine to trigger notification"
    echo "  2. Check Telegram for the login notification"
    echo "  3. Monitor logs: tail -f ${LOG_FILE}"
    echo ""
    
    echo "📱 Test your setup:"
    echo "  ssh user@your-server-ip"
    echo ""
    
    echo "🆘 Troubleshooting:"
    echo "  • If no notification received:"
    echo "    1. Check Bot Token and Chat ID in config"
    echo "    2. Run: ${INSTALL_DIR}/test.sh"
    echo "    3. Check logs: tail -f ${LOG_FILE}"
    echo ""
}

###############################################################################
# 主函数
###############################################################################

main() {
    print_banner
    
    # 执行各个步骤
    check_system
    install_dependencies
    download_files
    interactive_config
    
    # 可选的测试
    echo ""
    read -p "是否现在测试Telegram配置? [Y/n]: " -n 1 -r TEST
    echo ""
    if [[ ! $TEST =~ ^[Nn]$ ]]; then
        test_configuration || print_warn "Test failed, but installation will continue"
    fi
    
    configure_pam
    setup_permissions
    
    # 可选的SSH重启
    echo ""
    read -p "是否现在重启SSH服务? [Y/n]: " -n 1 -r RESTART
    echo ""
    if [[ ! $RESTART =~ ^[Nn]$ ]]; then
        restart_ssh
    fi
    
    print_summary
}

# 运行主函数
main "$@"
