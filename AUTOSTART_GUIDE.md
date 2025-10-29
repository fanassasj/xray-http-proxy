# Xray HTTP 代理 - 开机自启动指南

## 功能概述

新增的开机自启动功能允许 Xray HTTP 代理在系统启动时自动运行，无需手动启动。

## 支持的方式

### 1. systemd (推荐)
- 适用于: Ubuntu 16.04+, Debian 8+, CentOS 7+, RHEL 7+等现代Linux发行版
- 优点:
  - 更好的进程管理
  - 日志集成到系统日志
  - 自动重启失败的服务
  - 标准化的服务管理

### 2. rc.local (备选)
- 适用于: 不支持systemd的系统
- 优点: 简单、兼容性好
- 缺点: 功能较少，需手动管理

## 使用方法

### 方式一: 交互式菜单

```bash
./xray-http-proxy.sh
```

然后选择:
- **11** - 启用开机自启动
- **12** - 禁用开机自启动
- **13** - 查看自启动状态

### 方式二: 命令行

```bash
# 启用开机自启动
./xray-http-proxy.sh --enable-autostart

# 禁用开机自启动
./xray-http-proxy.sh --disable-autostart

# 查看自启动状态
./xray-http-proxy.sh --autostart-status
```

## systemd 服务管理

启用自启动后，可以使用标准的systemd命令管理服务：

### 基本命令

```bash
# 启动服务
sudo systemctl start xray-http-proxy

# 停止服务
sudo systemctl stop xray-http-proxy

# 重启服务
sudo systemctl restart xray-http-proxy

# 查看服务状态
sudo systemctl status xray-http-proxy

# 查看日志
sudo journalctl -u xray-http-proxy -f

# 查看最近100行日志
sudo journalctl -u xray-http-proxy -n 100
```

### 服务配置

systemd服务文件位置: `/etc/systemd/system/xray-http-proxy.service`

服务特性:
- **Type**: forking (后台运行)
- **Restart**: on-failure (失败时自动重启)
- **RestartSec**: 10s (重启前等待10秒)
- **启动顺序**: 网络服务之后

## 工作原理

### systemd 方式

1. 脚本生成 systemd 服务单元文件
2. 服务文件指向当前脚本的绝对路径
3. 使用 `--start -d` 参数启动代理
4. systemd 负责进程管理和日志

服务文件示例:
```ini
[Unit]
Description=Xray HTTP Proxy Service
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=forking
User=your_username
WorkingDirectory=/path/to/script
ExecStart=/path/to/xray-http-proxy.sh --start -d
ExecStop=/path/to/xray-http-proxy.sh --stop
ExecReload=/path/to/xray-http-proxy.sh --restart
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
```

### rc.local 方式

1. 在 `/etc/rc.local` 中添加启动命令
2. 使用绝对路径调用脚本
3. 系统启动时自动执行

## 前置条件

### 启用自启动前

1. **必须已配置代理**
   ```bash
   ./xray-http-proxy.sh --configure
   ```

2. **确保配置文件存在**
   - `proxy-config.env` 必须存在
   - 包含端口、用户名、密码等配置

3. **需要 sudo 权限**
   - 创建 systemd 服务文件需要 root 权限
   - 会提示输入密码

### 检查系统支持

```bash
# 检查是否支持 systemd
systemctl --version

# 检查 rc.local 是否存在
ls -l /etc/rc.local
```

## 故障排除

### systemd 服务无法启动

```bash
# 查看详细错误
sudo systemctl status xray-http-proxy
sudo journalctl -u xray-http-proxy -n 50

# 检查配置文件
cat /etc/systemd/system/xray-http-proxy.service

# 重新加载 systemd
sudo systemctl daemon-reload
```

### 服务已启用但未运行

```bash
# 手动启动服务
sudo systemctl start xray-http-proxy

# 查看启动日志
sudo journalctl -u xray-http-proxy -f
```

### 配置文件未找到

```bash
# 检查当前目录
pwd
ls -la proxy-config.env

# 确保在脚本所在目录
cd /path/to/xray-http-proxy
./xray-http-proxy.sh --enable-autostart
```

### 权限问题

```bash
# 确保脚本可执行
chmod +x xray-http-proxy.sh

# 检查配置文件权限
ls -l proxy-config.env  # 应该是 -rw------- (600)
```

## 安全建议

1. **配置文件权限**: 脚本会自动设置 `proxy-config.env` 为 600 权��
2. **服务用户**: systemd 服务以当前用户身份运行
3. **日志位置**:
   - systemd: 系统日志 (`journalctl`)
   - 脚本日志: `xray-proxy.log`

## 卸载自启动

### systemd

```bash
# 方法1: 使用脚本
./xray-http-proxy.sh --disable-autostart

# 方法2: 手动卸载
sudo systemctl disable xray-http-proxy
sudo systemctl stop xray-http-proxy
sudo rm /etc/systemd/system/xray-http-proxy.service
sudo systemctl daemon-reload
```

### rc.local

```bash
# 方法1: 使用脚本
./xray-http-proxy.sh --disable-autostart

# 方法2: 手动编辑
sudo nano /etc/rc.local
# 删除包含 xray-http-proxy.sh 的行
```

## 注意事项

1. **脚本路径**: 移动脚本位置后需重新配置自启动
2. **配置更新**: 修改配置后无需重新设置自启动
3. **多实例**: 目前不支持多个代理实例同时自启动
4. **网络依赖**: 服务会等待网络就绪后启动

## 示例工作流程

### 完整设置流程

```bash
# 1. 配置代理
./xray-http-proxy.sh --configure

# 2. 测试启动
./xray-http-proxy.sh --start -d

# 3. 检查状态
./xray-http-proxy.sh --status

# 4. 启用自启动
./xray-http-proxy.sh --enable-autostart

# 5. 验证自启动状态
./xray-http-proxy.sh --autostart-status

# 6. (可选) 重启系统测试
sudo reboot
```

### 验证自启动

```bash
# 重启后执行
./xray-http-proxy.sh --status

# 或使用 systemctl
sudo systemctl status xray-http-proxy
```

## 高级配置

### 自定义 systemd 服务

如需修改服务配置:

```bash
# 编辑服务文件
sudo nano /etc/systemd/system/xray-http-proxy.service

# 重新加载
sudo systemctl daemon-reload

# 重启服务
sudo systemctl restart xray-http-proxy
```

### 修改重启策略

在服务文件的 `[Service]` 部分:
- `Restart=always` - 总是重启
- `Restart=on-failure` - 仅失败时重启（默认）
- `Restart=no` - 不自动重启

---

更多信息请参考主文档 `README.md`
