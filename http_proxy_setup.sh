#!/bin/bash
# 自动检测 VPS 上的公网 IP，并创建 SOCKS5 和 HTTP 代理（端口递增）
# 修复 HTTP 代理可能丢失的问题，确保 TinyProxy 可用

echo "=============================="
echo "  Auto Proxy Setup Script 🚀"
echo "=============================="

# 让用户输入代理的用户名和密码
read -p "Enter Proxy Username: " PROXY_USER
read -s -p "Enter Proxy Password: " PROXY_PASS
echo ""

# 确保系统更新并安装必要软件
echo "[1/5] Updating system and installing required packages..."
apt update -y && apt install -y dante-server tinyproxy net-tools curl

# 获取 VPS 上的所有公网 IP
echo "[2/5] Detecting Public IPs..."
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
echo "[3/5] Configuring Dante (SOCKS5)..."
DANTE_CONF="/etc/danted.conf"

echo "logoutput: stderr" > $DANTE_CONF

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

# 生成 tinyproxy 配置文件
echo "[4/5] Configuring TinyProxy (HTTP)..."
TINYPROXY_CONF="/etc/tinyproxy.conf"
echo "PidFile \"/var/run/tinyproxy.pid\"" > $TINYPROXY_CONF  # 确保 TinyProxy 运行
echo "LogFile \"/var/log/tinyproxy.log\"" >> $TINYPROXY_CONF
echo "MaxClients 100" >> $TINYPROXY_CONF
echo "Allow 0.0.0.0/0" >> $TINYPROXY_CONF
echo "BasicAuth $PROXY_USER $PROXY_PASS" >> $TINYPROXY_CONF

for ip in $IP_LIST; do
    echo "Listen $ip" >> $TINYPROXY_CONF
    echo "Port $HTTP_PORT" >> $TINYPROXY_CONF
    HTTP_PORT=$((HTTP_PORT + 1))
done

# 确保 TinyProxy 允许多个监听 IP
sed -i 's/^#Allow/Allow/' $TINYPROXY_CONF

# 添加代理用户
echo "[5/5] Adding Proxy User..."
useradd -M $PROXY_USER || true
echo "$PROXY_USER:$PROXY_PASS" | chpasswd

# 开启防火墙端口
echo "Opening firewall ports..."
SOCKS5_PORT=20000
HTTP_PORT=30000

for ip in $IP_LIST; do
    ufw allow $SOCKS5_PORT
    ufw allow $HTTP_PORT
    SOCKS5_PORT=$((SOCKS5_PORT + 1))
    HTTP_PORT=$((HTTP_PORT + 1))
done
ufw reload

# 重启代理服务
echo "Restarting services..."
systemctl restart danted
systemctl enable danted
systemctl restart tinyproxy
systemctl enable tinyproxy

# 检测 HTTP 代理是否正常运行
echo "Testing HTTP Proxy..."
sleep 2  # 等待 tinyproxy 启动
HTTP_TEST_IP=$(echo "$IP_LIST" | head -n 1)
HTTP_TEST_PORT=30000
curl --proxy http://$PROXY_USER:$PROXY_PASS@$HTTP_TEST_IP:$HTTP_TEST_PORT -I http://google.com 2>/dev/null | grep HTTP

# 输出代理信息
echo "======================================"
echo "✅ Proxy Setup Completed!"
SOCKS5_PORT=20000
HTTP_PORT=30000

echo "SOCKS5 Proxies:"
for ip in $IP_LIST; do
    echo "  - socks5://$PROXY_USER:$PROXY_PASS@$ip:$SOCKS5_PORT"
    SOCKS5_PORT=$((SOCKS5_PORT + 1))
done

echo "HTTP Proxies:"
for ip in $IP_LIST; do
    echo "  - http://$PROXY_USER:$PROXY_PASS@$ip:$HTTP_PORT"
    HTTP_PORT=$((HTTP_PORT + 1))
done
echo "======================================"
