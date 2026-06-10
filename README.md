# Alpine SSH登录Telegram通知脚本

这是一个为Alpine Linux设计的SSH登录实时通知系统。当用户成功SSH登录到服务器时，会自动发送通知到Telegram机器人，包含服务器公网IP、登录来源IP等关键信息。

## 🌟 功能特性

- ✅ 实时SSH登录监听（通过PAM模块）
- ✅ 推送通知包含：
  - 服务器公网IP
  - 登录来源IP
  - 登录用户名
  - 登录时间
  - 登录方式
- ✅ 轻量级设计，适配Alpine Linux
- ✅ 无需重型依赖（仅需curl）
- ✅ 后台异步执行，不影响SSH性能
- ✅ 支持HTTPS安全传输
- ✅ 完整的日志记录和错误处理

## 📋 系统要求

- Alpine Linux 3.12+
- OpenSSH Server
- curl（用于HTTPS请求）
- Telegram Bot Token 和 Chat ID

## 🚀 快速安装

### 1. 准备Telegram Bot

1. 在Telegram中找到 `@BotFather`
2. 创建新bot：发送 `/newbot` 并按提示操作
3. 获取 **Bot Token**（格式：`123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`）
4. 获取你的 **Chat ID**：
   - 发送消息给bot
   - 访问 `https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates`
   - 从JSON中查找 `"id"` 字段

### 2. 克隆仓库

```bash
cd /opt
git clone https://github.com/dqkj666/alpine-ssh-notify.git
cd alpine-ssh-notify
```

### 3. 配置

```bash
cp config.example config
nano config
```

编辑以下关键变量：
```bash
TELEGRAM_BOT_TOKEN="your_bot_token_here"
TELEGRAM_CHAT_ID="your_chat_id_here"
```

### 4. 安装

```bash
sudo chmod +x install.sh
sudo ./install.sh
```

安装脚本会自动：
- 创建必要的目录和权限
- 修改PAM配置
- 重启SSH服务

### 5. 测试

```bash
# 测试通知功能
./test.sh

# 或从另一台机器SSH登录
ssh user@your-server-ip

# 查看日志
tail -f /var/log/ssh-notify.log
```

## 📁 文件说明

| 文件 | 说明 |
|------|------|
| `ssh-notify.sh` | 核心通知脚本 |
| `config.example` | 配置文件模板 |
| `install.sh` | 自动安装脚本 |
| `uninstall.sh` | 卸载脚本 |
| `test.sh` | 测试脚本 |
| `README.md` | 本文档 |

## ⚙️ 配置说明

### config 文件

```bash
# Telegram配置
TELEGRAM_BOT_TOKEN="your_bot_token"      # Bot Token
TELEGRAM_CHAT_ID="123456789"             # Chat ID

# 公网IP获取方式
PUBLIC_IP_METHOD="ifconfig"              # 可选：ifconfig, ipify, myip

# 日志配置
LOG_FILE="/var/log/ssh-notify.log"       # 日志文件位置
ENABLE_LOG="yes"                         # 启用日志
LOG_LEVEL="INFO"                         # 日志级别：INFO, DEBUG, ERROR

# 超时配置
TIMEOUT="10"                             # API请求超时（秒）
RETRY_COUNT="3"                          # 失败重试次数
```

### 环境变量

脚本自动从SSH环境变量获取：
- `SSH_CLIENT` - 登录来源IP和端口
- `SSH_USER` 或 `SUDO_USER` - 登录用户名
- `PAM_USER` - PAM模块传入的用户名

## 📝 通知格式示例

```
🔐 SSH登录通知

👤 用户名: ubuntu
🌍 服务器IP: 123.45.67.89
📍 登录IP: 192.168.1.100
🕐 时间: 2024-01-15 14:30:45 UTC+8
🔐 方式: password

[由 alpine-ssh-notify 发送]
```

## 🔧 高级配置

### 修改通知格式

编辑 `ssh-notify.sh` 中的 `build_message()` 函数：

```bash
build_message() {
    local user="$1"
    local server_ip="$2"
    local login_ip="$3"
    local timestamp="$4"
    
    cat <<EOF
🔐 SSH登录通知
...
EOF
}
```

### 自定义公网IP获取

在 `config` 中修改 `PUBLIC_IP_METHOD`：

```bash
PUBLIC_IP_METHOD="custom"
CUSTOM_IP_CMD="curl -s https://api.example.com/ip"
```

### 只通知特定用户

编辑 `ssh-notify.sh`，修改用户过滤：

```bash
# 只通知这些用户
NOTIFY_USERS="admin root ubuntu"
```

## 🐛 故障排除

### 通知未送达

**检查清单：**

1. 验证Bot Token和Chat ID
```bash
curl -X POST https://api.telegram.org/bot<TOKEN>/sendMessage \
  -d chat_id=<CHAT_ID> \
  -d text="Test"
```

2. 查看日志
```bash
tail -f /var/log/ssh-notify.log
```

3. 测试脚本
```bash
./test.sh
```

### SSH登录变慢

- 检查日志中的超时信息
- 减少重试次数：`RETRY_COUNT="1"`
- 增加超时时间：`TIMEOUT="15"`

### PAM配置问题

查看sshd日志：
```bash
tail -f /var/log/auth.log
# 或
logread -f
```

## 🔐 安全建议

- ⚠️ `config` 文件包含敏感信息，权限应为 `600`
- ⚠️ 不要在版本控制中提交 `config` 文件
- ✅ 为Telegram Bot创建专用账户（不是主账户）
- ✅ 使用HTTPS安全传输（脚本已默认配置）
- ✅ 定期检查日志，监控异常登录

## 📦 依赖说明

**必需：**
- `bash` - Shell解释器
- `curl` - HTTP客户端

**可选：**
- `jq` - JSON解析（用于test.sh）

**Alpine安装依赖：**
```bash
apk add bash curl jq
```

## 🛠️ 卸载

```bash
sudo ./uninstall.sh
```

脚本会：
- 移除PAM配置
- 删除脚本文件
- 重启SSH服务
- 清理日志

## 📊 日志示例

```
2024-01-15 14:30:45 [INFO] SSH login detected for user: ubuntu
2024-01-15 14:30:46 [INFO] Server IP: 123.45.67.89
2024-01-15 14:30:46 [INFO] Login IP: 192.168.1.100:54321
2024-01-15 14:30:47 [INFO] Telegram notification sent successfully
```

## 🤝 贡献

欢迎提交Issue和Pull Request！

## 📄 许可证

MIT License

---

**提示：** 首次使用建议先在测试环境验证，确保通知正常工作后再用于生产环境。

有问题？查看 [故障排除](#-故障排除) 部分或提交Issue！
