#!/bin/bash
# 自动检测 VPS 上的公网 IP，并创建 SOCKS5 和 HTTP 代理（端口递增）
# 适用于 Ubuntu/Debian，确保 SOCKS5 和 HTTP 代理同时可用
# 修复日志管理、错误处理、服务状态检查，并增强安全性

set -e  # 遇到错误立即退出

# 用户输入代理的用户名和密码
read -p "Enter Proxy Username: " PROXY_USER
read -s -p "Enter Proxy Password: " PROXY_PASS
echo ""

# 确保用户名不为空
if [[ -z "$PROXY_USER" ]]; then
    echo "❌ Error: Username cannot be empty!"
    exit 1
fi

# 确保系统更新并安装必要软件
echo "[1/6] Updating system and installing required packages..."
apt update -y && apt install -y dante-server tinyproxy net-tools curl ufw || { echo "Package installation failed!"; exit 1; }

# 获取 VPS 上的所有公网 IP
echo "[2/6] Detecting Public IPs..."
IP_LIST=$(ip -o -4 addr show | awk '{print $4}' | cut -d'/' -f1 | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | grep -v "127.0.0.1")

if [ -z "$IP_LIST" ]; then
    echo "❌ No public IPs detected! Exiting..."
    exit 1
fi

echo "✅ Found the following Public IPs:"
echo "$IP_LIST"

# 设置起始端口
SOCKS5_PORT=20000
HTTP_PORT=30000

# 生成 Dante（SOCKS5）配置文件
echo "[3/6] Configuring Dante (SOCKS5)..."
DANTE_CONF="/etc/danted.conf"
echo "logoutput: /var/log/danted.log" > $DANTE_CONF

for ip in $IP_LIST; do
    echo "internal: $ip port = $SOCKS5_PORT" >> $DANTE_CONF
    echo "external: $ip" >> $DANTE_CONF
    SOCKS5_PORT=$((SOCKS5_PORT + 1))
done

echo "
method: username
user.privileged: root
user.unprivileged: nobody
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect
}
" >> $DANTE_CONF

# 生成 TinyProxy（HTTP 代理）配置文件
echo "[4/6] Configuring TinyProxy (HTTP)..."
TINYPROXY_CONF="/etc/tinyproxy.conf"
echo "PidFile \"/var/run/tinyproxy.pid\"" > $TINYPROXY_CONF
echo "LogFile \"syslog\"" >> $TINYPROXY_CONF  # 使用 syslog 以避免日志权限问题
echo "MaxClients 100" >> $TINYPROXY_CONF
echo "Allow 0.0.0.0/0" >> $TINYPROXY_CONF
echo "BasicAuth $PROXY_USER $PROXY_PASS" >> $TINYPROXY_CONF
echo "Timeout 600" >> $TINYPROXY_CONF

echo "Listen 0.0.0.0" >> $TINYPROXY_CONF

echo "Port 30000" >> $TINYPROXY_CONF  # 仅绑定一个端口

# 添加代理用户
echo "[5/6] Adding Proxy User..."
if id "$PROXY_USER" &>/dev/null; then
    echo "User $PROXY_USER already exists, skipping creation."
else
    # 创建用户，但不创建 home 目录
    useradd -M -s /bin/false "$PROXY_USER" || { echo "❌ Failed to add user!"; exit 1; }
fi

# 设置用户密码
echo "$PROXY_USER:$PROXY_PASS" | chpasswd

# 开启防火墙端口
echo "Opening firewall ports..."
ufw allow 20000 || true
ufw allow 30000 || true
ufw reload || true

# 重启代理服务
echo "Restarting services..."
systemctl restart danted || { echo "Failed to restart Dante!"; exit 1; }
systemctl enable danted || true
systemctl restart tinyproxy || { echo "Failed to restart TinyProxy!"; exit 1; }
systemctl enable tinyproxy || true

# 检测 HTTP 代理是否正常运行
echo "Testing HTTP Proxy..."
sleep 2  # 等待 tinyproxy 启动
if curl --proxy http://$PROXY_USER:$PROXY_PASS@127.0.0.1:30000 -I http://google.com 2>/dev/null | grep -q "HTTP"; then
    echo "✅ HTTP Proxy is working!"
else
    echo "❌ HTTP Proxy test failed! Restarting service..."
    systemctl restart tinyproxy
    sleep 5
    if curl --proxy http://$PROXY_USER:$PROXY_PASS@127.0.0.1:30000 -I http://google.com 2>/dev/null | grep -q "HTTP"; then
        echo "✅ HTTP Proxy recovered and working!"
    else
        echo "❌ HTTP Proxy still failed! Check logs."
    fi
fi

# 输出代理信息
echo "======================================"
echo "✅ Proxy Setup Completed!"
echo "SOCKS5 Proxy: socks5://$PROXY_USER:$PROXY_PASS@$(hostname -I | awk '{print $1}'):20000"
echo "HTTP Proxy: http://$PROXY_USER:$PROXY_PASS@$(hostname -I | awk '{print $1}'):30000"
echo "======================================"
