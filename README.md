# Alpine SSH Login → Telegram Notification

一个为 Alpine Linux 设计的轻量级 SSH 登录实时通知脚本。当用户成功 SSH 登录时，自动发送详细信息到 Telegram 机器人。

📱 **[English Version](#english-version)** | 📖 **中文版本**

---

## 🎯 功能特性

### ✨ 核心功能

- 🔐 **实时SSH登录监听** - 通过PAM模块捕获登录事件
- 📱 **即时Telegram推送** - 登录时立即发送通知
- 🌍 **自动获取公网IP** - 支持多种IP获取方式
- 📍 **记录登录源IP** - 完整的登录信息记录
- 👤 **用户和时间信息** - 显示登录用户和精确时间
- 🔄 **自动失败重试** - 网络失败自动重试机制
- 📝 **完整日志记录** - 详细的事件和错误日志
- ⚡ **后台异步执行** - 不影响SSH登录性能

### 🎨 设计特点

- **轻量级** - 仅需bash和curl，无重型依赖
- **Alpine适配** - 完美支持musl libc环境
- **交互式安装** - 一键脚本，按步骤配置
- **安全可靠** - HTTPS加密传输，敏感信息保护
- **易于使用** - 完整文档和故障排除指南

---

## 🚀 一键快速安装

### 前置条件

#### 1️⃣ 创建Telegram机器人

- 在Telegram中搜索 `@BotFather`
- 发送命令 `/newbot`
- 按照提示创建机器人
- **记录你的Bot Token**（格式: `123456:ABC-DEF1234...`）

#### 2️⃣ 获取Telegram Chat ID

- 给你的机器人发送任意消息
- 访问 API 获取 Chat ID:
  ```
  https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
  ```
- 将 `<YOUR_BOT_TOKEN>` 替换为你的实际Token
- 查看返回JSON，找到 `"id"` 字段，这就是你的**Chat ID**

### 📥 安装命令

在你的Alpine系统上执行以下一条命令：

```bash
curl -fsSL https://raw.githubusercontent.com/dqkj666/alpine-ssh-notify/main/install.sh \
  -o /root/install.sh && \
chmod +x /root/install.sh && \
sudo bash /root/install.sh
```

**或使用简化版本：**

```bash
curl -fsSL https://raw.githubusercontent.com/dqkj666/alpine-ssh-notify/main/install.sh | sudo bash
```

### 📋 安装步骤说明

安装脚本会引导你完成以下8个步骤：

| 步骤 | 说明 |
|------|------|
| ✅ 第1步 | 系统检查 - 验证Alpine Linux和root权限 |
| ✅ 第2步 | 依赖安装 - 自动安装curl等必需工具 |
| ✅ 第3步 | 脚本下载 - 从GitHub下载所有项目文件 |
| ⚙️ 第4步 | 交互配置 - 按提示输入Telegram凭证 |
| 🧪 第5步 | 连接测试 - 发送测试消息验证配置 |
| 🔧 第6步 | PAM配置 - 集成到SSH登录流程 |
| 🔑 第7步 | 权限设置 - 设置脚本权限和日志 |
| 🔄 第8步 | SSH重启 - 应用所有配置更改 |

---

## 📱 通知消息示例

当用户SSH登录时，你将收到类似以下格式的Telegram消息：

```
🔐 SSH登录通知

👤 用户名: ubuntu
🌍 服务器IP: 123.45.67.89
📍 登录IP: 192.168.1.100:54321
🕐 时间: 2024-01-15 14:30:45

由 alpine-ssh-notify 发送
```

---

## ⚙️ 配置说明

### 安装过程中的配置选项

#### 1. Telegram Bot Token
```
提示: 请输入 Telegram Bot Token
格式: 123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11
```

#### 2. Telegram Chat ID
```
提示: 请输入 Telegram Chat ID
格式: 987654321 (纯数字)
```

#### 3. 公网IP获取方式
```
选择公网IP获取方式:
1) ifconfig.me    ⭐ 推荐 - 国际通用
2) api.ipify.org  - 国际通用
3) myip.ipip.net  - 中国IP数据库
```

#### 4. 日志级别
```
选择日志级别:
1) DEBUG  - 详细调试信息
2) INFO   ⭐ 推荐 - 普通信息
3) WARN   - 仅警告错误
4) ERROR  - 仅错误信息
```

#### 5. API超时时间
```
设置 Telegram API 超时时间 (默认: 10 秒)
范围: 5-20 秒
网络不稳定时可增大
```

#### 6. 失败重试次数
```
设置失败重试次数 (默认: 3)
范围: 1-10 次
```

### 配置文件编辑

安装完成后，可编辑配置文件进行高级配置：

```bash
nano /opt/alpine-ssh-notify/config
```

主要配置参数：

```bash
# Telegram配置（必需）
TELEGRAM_BOT_TOKEN="your_token"
TELEGRAM_CHAT_ID="your_id"

# 公网IP获取方式
PUBLIC_IP_METHOD="ifconfig"  # ifconfig, ipify, myip

# 日志配置
LOG_FILE="/var/log/ssh-notify.log"
ENABLE_LOG="yes"
LOG_LEVEL="INFO"

# 网络配置
TIMEOUT="10"           # API超时(秒)
RETRY_COUNT="3"        # 重试次数
RETRY_DELAY="2"        # 重试延迟(秒)

# 用户过滤（可选）
SKIP_USERS="root"      # 不通知的用户
# NOTIFY_USERS="admin" # 仅通知指定用户
```

修改后需要重启SSH：
```bash
sudo rc-service sshd restart    # OpenRC
# 或
sudo systemctl restart sshd     # systemd
```

---

## 🧪 测试和验证

### 1. 发送测试消息

```bash
/opt/alpine-ssh-notify/ssh-notify.sh --test
```

预期输出：
```
✓ Server IP: 123.45.67.89
✓ Message built
✓ Test notification sent successfully!
```

### 2. 实际测试SSH登录

从另一台机器SSH登录到你的服务器：

```bash
ssh user@your-server-ip
```

然后检查Telegram是否收到登录通知。

### 3. 查看日志

```bash
# 实时查看日志
tail -f /var/log/ssh-notify.log

# 查看最近50行
tail -50 /var/log/ssh-notify.log

# 查看特定错误
grep ERROR /var/log/ssh-notify.log
```

日志示例：
```
[2024-01-15 14:30:45] [INFO] SSH login detected for user: ubuntu
[2024-01-15 14:30:46] [INFO] Server IP: 123.45.67.89
[2024-01-15 14:30:47] [INFO] Sending Telegram notification
[2024-01-15 14:30:48] [INFO] Notification sent successfully
```

---

## 📁 项目文件结构

```
/opt/alpine-ssh-notify/
├── ssh-notify.sh          # ⭐ 核心通知脚本 (被PAM调用)
├── config                 # 🔒 运行配置 (敏感信息)
├── config.example         # ⚙️ 配置文件模板
├── helper-functions.sh    # 🔧 辅助函数库
└── uninstall.sh          # 🗑️ 卸载脚本
```

日志文件：
```
/var/log/ssh-notify.log   # 📝 所有通知日志
```

---

## 🛠️ 常用命令

### 日常操作

```bash
# 查看实时日志
tail -f /var/log/ssh-notify.log

# 查看日志最后50行
tail -50 /var/log/ssh-notify.log

# 查看所有日志
cat /var/log/ssh-notify.log

# 查看当前配置
cat /opt/alpine-ssh-notify/config

# 编辑配置
nano /opt/alpine-ssh-notify/config

# 发送测试消息
/opt/alpine-ssh-notify/ssh-notify.sh --test

# 重启SSH服务
sudo rc-service sshd restart

# 查看SSH状态
sudo rc-service sshd status
```

### 管理和维护

```bash
# 查看脚本权限
ls -la /opt/alpine-ssh-notify/

# 修复权限（如需要）
sudo chmod 755 /opt/alpine-ssh-notify/ssh-notify.sh
sudo chmod 666 /var/log/ssh-notify.log

# 查看PAM配置
grep alpine-ssh-notify /etc/pam.d/sshd

# 查看SSH PAM配置全部
cat /etc/pam.d/sshd
```

---

## 🐛 故障排除

### ❌ 问题1: 未收到通知

**检查清单：**

1. 验证配置
   ```bash
   cat /opt/alpine-ssh-notify/config | grep TELEGRAM
   ```

2. 测试Telegram API
   ```bash
   curl "https://api.telegram.org/bot<TOKEN>/getMe"
   ```
   （将`<TOKEN>`替换为你的Bot Token）

3. 发送测试消息
   ```bash
   /opt/alpine-ssh-notify/ssh-notify.sh --test
   ```

4. 查看日志
   ```bash
   tail -30 /var/log/ssh-notify.log
   ```

**常见原因和解决方案：**

| 原因 | 解决方案 |
|------|--------|
| Bot Token错误 | 在@BotFather中重新检查Token |
| Chat ID错误 | 重新访问getUpdates API获取ID |
| 网络连接问题 | 检查服务器网络连接：`curl -I https://api.telegram.org` |
| Bot未激活 | 在Telegram中给bot发送消息激活 |
| PAM配置未生效 | 重启SSH: `sudo rc-service sshd restart` |

### ❌ 问题2: SSH登录变慢

**症状：** SSH登录响应缓慢

**解决方案：**

1. 减少API超时时间
   ```bash
   nano /opt/alpine-ssh-notify/config
   # 修改: TIMEOUT="5"  # 从10改为5
   ```

2. 减少重试次数
   ```bash
   # 修改: RETRY_COUNT="1"  # 从3改为1
   ```

3. 重启SSH
   ```bash
   sudo rc-service sshd restart
   ```

### ❌ 问题3: PAM配置错误

**症状：** SSH登录时出现PAM相关错误

**检查和修复：**

```bash
# 查看当前PAM配置
cat /etc/pam.d/sshd | grep alpine

# 查看SSH日志
tail /var/log/auth.log

# 如果配置重复，手动清理
sudo sed -i '/alpine-ssh-notify/d' /etc/pam.d/sshd

# 重新运行安装脚本的PAM部分
echo "session optional pam_exec.so /opt/alpine-ssh-notify/ssh-notify.sh" | \
  sudo tee -a /etc/pam.d/sshd

# 重启SSH
sudo rc-service sshd restart
```

### ❌ 问题4: 权限错误

**症状：** 脚本执行失败，权限拒绝

**修复：**

```bash
# 修复脚本权限
sudo chmod 755 /opt/alpine-ssh-notify/ssh-notify.sh

# 修复日志文件权限
sudo chmod 666 /var/log/ssh-notify.log

# 修复安装目录权限
sudo chmod 755 /opt/alpine-ssh-notify

# 验证权限
ls -la /opt/alpine-ssh-notify/
```

---

## 🔒 安全建议

### 配置文件安全

```bash
# 确保config文件仅所有者可读
sudo chmod 600 /opt/alpine-ssh-notify/config

# 不要在版本控制中提交config
echo "config" >> /opt/alpine-ssh-notify/.gitignore
```

### Telegram安全

- ⚠️ 为Bot创建**专用账户**，不要使用主账户
- ⚠️ **定期检查** Bot日志和通知
- ✅ 使用**HTTPS加密**通信（脚本已默认）
- ✅ **不保存**任何登录凭据，仅记录事件

### 系统安全

- ✅ 定期检查**异常登录**
- ✅ **监控日志**：`tail -f /var/log/ssh-notify.log`
- ✅ **定期更新**系统和脚本
- ✅ **限制SSH访问**（使用防火墙等）

---

## 🔌 卸载

完全卸载Alpine SSH Notify：

```bash
sudo /opt/alpine-ssh-notify/uninstall.sh
```

卸载脚本会：
- ✓ 移除PAM配置
- ✓ 删除脚本文件
- ✓ 重启SSH服务
- ✓ 保留日志文件（可选手动删除）

---

## ❓ 常见问题

**Q: 脚本支持哪些操作系统？**
A: 主要为Alpine Linux设计，但也支持其他使用PAM的Linux系统（Ubuntu、Debian等）

**Q: 对系统性能有影响吗？**
A: 几乎没有。脚本后台异步执行，不阻塞SSH登录

**Q: 可以通知多个Telegram账户吗？**
A: 当前不支持直接配置多个ID，但可以配置一个Telegram群组或频道的ID

**Q: 如何只通知特定用户的登录？**
A: 编辑配置文件，使用 `SKIP_USERS` 或 `NOTIFY_USERS` 参数

**Q: 可以自定义通知消息吗？**
A: 可以，编辑 `ssh-notify.sh` 中的 `build_message()` 函数

**Q: 如何禁用日志记录？**
A: 编辑配置文件，设置 `ENABLE_LOG="no"`

---

## 📊 日志示例

```
[2024-01-15 14:30:45] [INFO] SSH login detected for user: ubuntu
[2024-01-15 14:30:46] [INFO] Server IP: 123.45.67.89
[2024-01-15 14:30:46] [INFO] Login IP: 192.168.1.100:54321
[2024-01-15 14:30:47] [INFO] Sending Telegram notification
[2024-01-15 14:30:48] [INFO] Notification sent successfully
```

---

## 📦 文件说明

| 文件 | 说明 |
|------|------|
| `install.sh` | 一键安装脚本（交互式配置） |
| `ssh-notify.sh` | 核心通知脚本（被PAM调用） |
| `config.example` | 配置文件模板 |
| `uninstall.sh` | 卸载脚本 |
| `helper-functions.sh` | 辅助函数库 |
| `README.md` | 完整文档 |
| `.gitignore` | Git忽略配置 |

---

## 🤝 贡献

欢迎提交Issue和Pull Request！

如有问题或建议，请访问：
https://github.com/dqkj666/alpine-ssh-notify

---

## 📄 许可证

MIT License

---

## 🙏 致谢

感谢所有使用和反馈的用户！

---

<div id="english-version"></div>

# English Version

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/dqkj666/alpine-ssh-notify/main/install.sh | sudo bash
```

## Features

- 🔐 Real-time SSH login monitoring via PAM
- 📱 Instant Telegram notifications
- 🌍 Automatic public IP detection
- 📍 Login source IP tracking
- 👤 User and timestamp logging
- 🔄 Automatic retry on failure
- 📝 Comprehensive logging
- ⚡ Async execution (no performance impact)

## Setup Requirements

1. Create Telegram bot via @BotFather
2. Get your Bot Token
3. Get your Chat ID from getUpdates API
4. Run installation script and follow prompts

## Configuration

Edit `/opt/alpine-ssh-notify/config`:
```bash
TELEGRAM_BOT_TOKEN="your_token_here"
TELEGRAM_CHAT_ID="your_chat_id_here"
```

## Testing

```bash
# Send test notification
/opt/alpine-ssh-notify/ssh-notify.sh --test

# SSH login from another machine
ssh user@your-server-ip

# View logs
tail -f /var/log/ssh-notify.log
```

## Uninstall

```bash
sudo /opt/alpine-ssh-notify/uninstall.sh
```

## Support

For issues and questions: https://github.com/dqkj666/alpine-ssh-notify

---

**License**: MIT | **中文文档**: 见上方
