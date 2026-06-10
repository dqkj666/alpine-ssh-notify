#!/bin/bash

###############################################################################
# Alpine SSH Login Telegram Notification - One-Click Installer
# 一键安装脚本：下载、安装并交互式配置SSH登录Telegram通知
#
# 使用方法:
# curl -fsSL https://raw.githubusercontent.com/dqkj666/alpine-ssh-notify/main/install.sh -o /root/install.sh && chmod +x /root/install.sh && bash /root/install.sh
###############################################################################

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置变量
INSTALL_DIR="/opt/alpine-ssh-notify"
GITHUB_REPO="https://raw.githubusercontent.com/dqkj666/alpine-ssh-notify/main"
LOG_FILE="/var/log/ssh-notify.log"
TEMP_DIR=$(mktemp -d)

trap 'rm -rf ${TEMP_DIR}' EXIT

###############################################################################
# 工具函数
###############################################################################

print_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║        Alpine SSH Login → Telegram Notification                 ║
║                                                                  ║
║        SSH登录实时推送至Telegram机器人                           ║
║        包含: 服务器公网IP、登录来源IP、登录用户名               ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}▶ $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

separator() {
    echo -e "${CYAN}────────────────────────────────────────────────────${NC}"
}

pause_prompt() {
    read -p "$(echo -e ${BLUE})按 Enter 继续...$(echo -e ${NC})" -r
}

###############################################################################
# 检查系统
###############################################################################

check_system() {
    log_step "第 1 步: 检查系统环境"
    
    # 检查是否是Alpine Linux
    if ! grep -q "Alpine" /etc/os-release 2>/dev/null; then
        log_warn "此脚本设计用于 Alpine Linux，但可能在其他系统上工作"
    else
        log_success "检测到 Alpine Linux 系统"
    fi
    
    # 检查root权限
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以 root 权限运行"
        echo ""
        echo "请使用以下命令:"
        echo "  sudo bash $0"
        exit 1
    fi
    log_success "Root 权限检查通过"
    
    # 检查网络连接
    log_info "检查网络连接..."
    if ! timeout 5 curl -s https://api.telegram.org > /dev/null 2>&1; then
        log_warn "无法连接到 Telegram API，请检查网络连接"
    else
        log_success "网络连接正常"
    fi
}

###############################################################################
# 安装依赖
###############################################################################

install_dependencies() {
    log_step "第 2 步: 安装依赖"
    
    local required_tools=("curl" "bash")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "${tool}" &> /dev/null; then
            missing_tools+=("${tool}")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_info "正在安装缺失的工具: ${missing_tools[*]}"
        apk update > /dev/null 2>&1
        apk add --no-cache "${missing_tools[@]}" > /dev/null 2>&1
        log_success "依赖安装完成"
    else
        log_success "所有依赖已安装"
    fi
}

###############################################################################
# 下载脚本
###############################################################################

download_scripts() {
    log_step "第 3 步: 下载脚本文件"
    
    # 创建安装目录
    if [[ ! -d "${INSTALL_DIR}" ]]; then
        log_info "创建安装目录: ${INSTALL_DIR}"
        mkdir -p "${INSTALL_DIR}"
    fi
    
    # 定义要下载的文件
    local files=(
        "ssh-notify.sh"
        "config.example"
        "helper-functions.sh"
        "uninstall.sh"
    )
    
    local failed=0
    
    for file in "${files[@]}"; do
        log_info "正在下载: ${file}"
        
        if ! curl -fsSL "${GITHUB_REPO}/${file}" -o "${INSTALL_DIR}/${file}"; then
            log_error "下载失败: ${file}"
            failed=$((failed + 1))
            continue
        fi
        
        # 设置可执行权限
        if [[ "${file}" == *.sh ]]; then
            chmod +x "${INSTALL_DIR}/${file}"
        fi
        
        log_success "已下载: ${file}"
    done
    
    if [[ ${failed} -gt 0 ]]; then
        log_error "有 ${failed} 个文件下载失败"
        log_error "请检查网络连接和GitHub仓库地址"
        exit 1
    fi
    
    # 从example配置创建config
    if [[ ! -f "${INSTALL_DIR}/config" ]]; then
        cp "${INSTALL_DIR}/config.example" "${INSTALL_DIR}/config"
        chmod 600 "${INSTALL_DIR}/config"
        log_success "创建配置文件"
    fi
}

###############################################################################
# 交互式配置
###############################################################################

interactive_setup() {
    log_step "第 4 步: 交互式配置"
    
    echo -e "${CYAN}请输入 Telegram 配置信息${NC}\n"
    separator
    
    # Bot Token 配置
    local bot_token=""
    while [[ -z "${bot_token}" ]]; do
        echo ""
        echo -e "${YELLOW}1️⃣  请输入 Telegram Bot Token:${NC}"
        echo "   格式示例: 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
        echo ""
        echo "   获取方法:"
        echo "   • 在 Telegram 中搜索 @BotFather"
        echo "   • 发送 /newbot 命令创建机器人"
        echo "   • 复制得到的 Token"
        echo ""
        read -p "Bot Token: " bot_token
        
        if [[ -z "${bot_token}" ]]; then
            log_error "Bot Token 不能为空"
            continue
        fi
        
        if [[ ! ${bot_token} =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
            log_error "Bot Token 格式无效，请重新输入"
            bot_token=""
            continue
        fi
        
        log_success "Bot Token 已接受"
    done
    
    # Chat ID 配置
    separator
    local chat_id=""
    while [[ -z "${chat_id}" ]]; do
        echo ""
        echo -e "${YELLOW}2️⃣  请输入 Telegram Chat ID:${NC}"
        echo "   格式示例: 987654321"
        echo ""
        echo "   获取方法:"
        echo "   • 在 Telegram 中给你的机器人发送任意消息"
        echo "   • 访问: https://api.telegram.org/bot<TOKEN>/getUpdates"
        echo "   • 将 <TOKEN> 替换为你的 Bot Token"
        echo "   • 查看返回的 JSON，找到 \"id\" 字段"
        echo "   • 数字就是你的 Chat ID"
        echo ""
        read -p "Chat ID: " chat_id
        
        if [[ -z "${chat_id}" ]]; then
            log_error "Chat ID 不能为空"
            continue
        fi
        
        if [[ ! ${chat_id} =~ ^-?[0-9]+$ ]]; then
            log_error "Chat ID 格式无效 (应为纯数字)"
            chat_id=""
            continue
        fi
        
        log_success "Chat ID 已接受"
    done
    
    # 公网IP获取方式
    separator
    echo ""
    echo -e "${YELLOW}3️⃣  选择公网IP获取方式 (默认: ifconfig):${NC}"
    echo "   1) ifconfig.me   - 推荐 ⭐"
    echo "   2) api.ipify.org"
    echo "   3) myip.ipip.net - 中国IP"
    echo ""
    read -p "选择 [1-3] (默认 1): " ip_method_choice
    ip_method_choice=${ip_method_choice:-1}
    
    local ip_method="ifconfig"
    case ${ip_method_choice} in
        1) ip_method="ifconfig" ;;
        2) ip_method="ipify" ;;
        3) ip_method="myip" ;;
        *) ip_method="ifconfig" ;;
    esac
    log_success "公网IP获取方式: ${ip_method}"
    
    # 日志级别
    separator
    echo ""
    echo -e "${YELLOW}4️⃣  选择日志级别 (默认: INFO):${NC}"
    echo "   1) DEBUG - 详细调试信息"
    echo "   2) INFO  - 普通信息 ⭐"
    echo "   3) WARN  - 仅警告和错误"
    echo "   4) ERROR - 仅错误信息"
    echo ""
    read -p "选择 [1-4] (默认 2): " log_level_choice
    log_level_choice=${log_level_choice:-2}
    
    local log_level="INFO"
    case ${log_level_choice} in
        1) log_level="DEBUG" ;;
        2) log_level="INFO" ;;
        3) log_level="WARN" ;;
        4) log_level="ERROR" ;;
        *) log_level="INFO" ;;
    esac
    log_success "日志级别: ${log_level}"
    
    # 配置超时时间
    separator
    echo ""
    echo -e "${YELLOW}5️⃣  设置 Telegram API 超时时间 (默认: 10 秒):${NC}"
    echo "   • 网络较差时可以增大这个值"
    echo "   • 推荐范围: 5-20 秒"
    echo ""
    read -p "超时时间 [秒] (默认 10): " timeout
    timeout=${timeout:-10}
    
    if [[ ! ${timeout} =~ ^[0-9]+$ ]] || [[ ${timeout} -lt 1 ]] || [[ ${timeout} -gt 60 ]]; then
        log_warn "超时时间无效，使用默认值 10"
        timeout=10
    fi
    log_success "超时时间: ${timeout} 秒"
    
    # 配置重试次数
    separator
    echo ""
    echo -e "${YELLOW}6️⃣  设置失败重试次数 (默认: 3):${NC}"
    echo "   • 如果发送失败会自动重试"
    echo "   • 推荐: 2-5 次"
    echo ""
    read -p "重试次数 (默认 3): " retry_count
    retry_count=${retry_count:-3}
    
    if [[ ! ${retry_count} =~ ^[0-9]+$ ]] || [[ ${retry_count} -lt 1 ]] || [[ ${retry_count} -gt 10 ]]; then
        log_warn "重试次数无效，使用默认值 3"
        retry_count=3
    fi
    log_success "重试次数: ${retry_count}"
    
    # 保存配置
    separator
    echo ""
    log_info "正在保存配置..."
    
    sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=\"${bot_token}\"|" "${INSTALL_DIR}/config"
    sed -i "s|^TELEGRAM_CHAT_ID=.*|TELEGRAM_CHAT_ID=\"${chat_id}\"|" "${INSTALL_DIR}/config"
    sed -i "s|^PUBLIC_IP_METHOD=.*|PUBLIC_IP_METHOD=\"${ip_method}\"|" "${INSTALL_DIR}/config"
    sed -i "s|^LOG_LEVEL=.*|LOG_LEVEL=\"${log_level}\"|" "${INSTALL_DIR}/config"
    sed -i "s|^TIMEOUT=.*|TIMEOUT=\"${timeout}\"|" "${INSTALL_DIR}/config"
    sed -i "s|^RETRY_COUNT=.*|RETRY_COUNT=\"${retry_count}\"|" "${INSTALL_DIR}/config"
    
    log_success "配置已保存"
}

###############################################################################
# 测试配置
###############################################################################

test_configuration() {
    log_step "第 5 步: 测试 Telegram 连接"
    
    source "${INSTALL_DIR}/config"
    
    echo -e "${CYAN}正在执行配置测试...${NC}\n"
    
    # 测试公网IP
    log_info "测试公网IP获取..."
    local public_ip
    if public_ip=$(curl -s --max-time 5 http://ifconfig.me 2>/dev/null); then
        log_success "公网IP: ${public_ip}"
    else
        log_warn "无法获取公网IP (网络可能不可用)"
        public_ip="Unknown"
    fi
    
    # 测试Telegram API
    log_info "测试 Telegram API 连接..."
    separator
    
    local test_message=$(cat <<EOF
🔐 Alpine SSH Notify - 配置测试

✅ 配置成功！

服务器公网IP: ${public_ip}
测试时间: $(date '+%Y-%m-%d %H:%M:%S')

现在 SSH 登录到此服务器时，将收到登录通知。

---
由 alpine-ssh-notify 发送
EOF
)
    
    local response=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -H "Content-Type: application/json" \
        -d @- <<< '{
            "chat_id": '"${TELEGRAM_CHAT_ID}"',
            "text": "'"$(echo "${test_message}" | sed 's/"/\\"/g' | sed "s/'/\\\\'/g")"'"
        }' 2>/dev/null)
    
    if echo "${response}" | grep -q '"ok":true'; then
        log_success "Telegram 测试消息已发送！"
        echo -e "\n${CYAN}请检查你的 Telegram 账户接收消息${NC}\n"
        return 0
    else
        log_error "发送测试消息失败"
        log_error "响应: ${response}"
        echo ""
        echo -e "${YELLOW}可能的原因:${NC}"
        echo "  1. Bot Token 或 Chat ID 错误"
        echo "  2. 网络连接问题"
        echo "  3. Bot 未在 Telegram 启动"
        echo ""
        read -p "是否继续安装? [Y/n]: " -n 1 -r continue_install
        echo ""
        if [[ $continue_install =~ ^[Nn]$ ]]; then
            log_warn "安装已取消"
            exit 1
        fi
        return 1
    fi
}

###############################################################################
# 配置PAM
###############################################################################

configure_pam() {
    log_step "第 6 步: 配置 PAM 模块"
    
    local pam_config="/etc/pam.d/sshd"
    local pam_line="session optional pam_exec.so /opt/alpine-ssh-notify/ssh-notify.sh"
    
    if [[ ! -f "${pam_config}" ]]; then
        log_error "PAM SSH 配置文件未找到: ${pam_config}"
        return 1
    fi
    
    # 检查是否已配置
    if grep -q "alpine-ssh-notify" "${pam_config}"; then
        log_success "PAM 已配置"
        return 0
    fi
    
    # 备份原配置
    local backup_file="${pam_config}.backup.$(date +%s)"
    cp "${pam_config}" "${backup_file}"
    log_info "已创建备份: ${backup_file}"
    
    # 添加PAM配置
    echo "${pam_line}" >> "${pam_config}"
    log_success "PAM 配置已添加"
}

###############################################################################
# 设置权限
###############################################################################

setup_permissions() {
    log_step "第 7 步: 设置权限"
    
    chmod 755 "${INSTALL_DIR}/ssh-notify.sh"
    chmod 755 "${INSTALL_DIR}/uninstall.sh"
    chmod 600 "${INSTALL_DIR}/config"
    chmod 755 "${INSTALL_DIR}"
    
    log_success "脚本权限设置完成"
    
    # 创建日志文件
    log_info "初始化日志文件: ${LOG_FILE}"
    touch "${LOG_FILE}"
    chmod 666 "${LOG_FILE}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] SSH Notify 已初始化" >> "${LOG_FILE}"
    
    log_success "日志文件已初始化"
}

###############################################################################
# 重启SSH
###############################################################################

restart_ssh() {
    log_step "第 8 步: 重启 SSH 服务"
    
    echo -e "${YELLOW}⚠️  警告: 重启 SSH 服务可能会中断活动连接${NC}\n"
    read -p "是否继续? [Y/n]: " -n 1 -r restart_ssh
    echo ""
    
    if [[ $restart_ssh =~ ^[Nn]$ ]]; then
        log_warn "SSH 重启已跳过"
        echo ""
        echo -e "${YELLOW}请手动重启 SSH 服务使配置生效:${NC}"
        echo "  • rc-service sshd restart    (OpenRC)"
        echo "  • systemctl restart sshd     (systemd)"
        return 0
    fi
    
    if command -v rc-service &> /dev/null; then
        log_info "正在重启 SSH (OpenRC)..."
        if rc-service sshd restart > /dev/null 2>&1; then
            log_success "SSH 服务已重启"
        else
            log_error "SSH 服务重启失败"
            return 1
        fi
    elif command -v systemctl &> /dev/null; then
        log_info "正在重启 SSH (systemd)..."
        if systemctl restart sshd > /dev/null 2>&1; then
            log_success "SSH 服务已重启"
        else
            log_error "SSH 服务重启失败"
            return 1
        fi
    else
        log_error "无法确定系统初始化系统"
        return 1
    fi
}

###############################################################################
# 显示完成信息
###############################################################################

print_summary() {
    clear
    echo -e "${GREEN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║         ✅ Alpine SSH Notify 安装完成！                          ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
    
    cat << EOF
📋 安装信息:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📁 安装目录: ${INSTALL_DIR}
  📝 配置文件: ${INSTALL_DIR}/config
  📄 日志文件: ${LOG_FILE}

📦 已安装文件:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  • ssh-notify.sh       - 主通知脚本
  • config              - 配置文件
  • helper-functions.sh - 辅助函数库
  • uninstall.sh        - 卸载脚本

🚀 使用方法:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  1. 从另一台机器 SSH 登录到此服务器
  2. 你将在 Telegram 中收到登录通知
  3. 通知包含:
     • 登录用户名
     • 登录来源 IP
     • 服务器公网 IP
     • 登录时间

📊 日志查看:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  tail -f ${LOG_FILE}

⚙️  管理命令:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  编辑配置:     nano ${INSTALL_DIR}/config
  重新配置:     bash ${INSTALL_DIR}/ssh-notify.sh --config
  测试通知:     bash ${INSTALL_DIR}/ssh-notify.sh --test
  查看日志:     tail -f ${LOG_FILE}
  卸载:         sudo bash ${INSTALL_DIR}/uninstall.sh

📱 立即测试:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  从另一台机器执行:
    ssh user@$(hostname -I | awk '{print $1}')

  然后查看 Telegram 中的通知消息

🆘 故障排除:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  • 检查配置: cat ${INSTALL_DIR}/config
  • 查看日志: tail -50 ${LOG_FILE}
  • 测试Telegram连接:
    curl https://api.telegram.org/bot<TOKEN>/getMe

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
    
    echo -e "\n${CYAN}感谢使用 Alpine SSH Notify!${NC}\n"
}

###############################################################################
# 主函数
###############################################################################

main() {
    print_banner
    
    # 执行各步骤
    check_system
    pause_prompt
    
    install_dependencies
    pause_prompt
    
    download_scripts
    pause_prompt
    
    interactive_setup
    pause_prompt
    
    # 测试配置
    while true; do
        test_configuration && break
        read -p "是否重新配置? [Y/n]: " -n 1 -r reconfigure
        echo ""
        if [[ $reconfigure =~ ^[Nn]$ ]]; then
            break
        fi
        interactive_setup
    done
    pause_prompt
    
    configure_pam
    pause_prompt
    
    setup_permissions
    pause_prompt
    
    restart_ssh
    pause_prompt
    
    print_summary
    
    log_success "安装脚本已完成！"
}

# 执行主函数
main "$@"
