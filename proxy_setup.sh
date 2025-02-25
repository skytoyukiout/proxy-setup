#!/bin/bash
# 使用 Xray 作为 HTTP 和 SOCKS5 代理服务器，支持多 IP 监听
# 自动检测 VPS 上的公网 IP，并创建 SOCKS5 和 HTTP 代理（端口递增）
# 适用于 Ubuntu/Debian，确保 SOCKS5 和 HTTP 代理同时可用

set -e  # 遇到错误立即退出

# 默认端口
SOCKS5_START_PORT=20000
HTTP_START_PORT=30000

# 用户输入代理的用户名和密码
read -p "Enter Proxy Username: " PROXY_USER
read -s -p "Enter Proxy Password: " PROXY_PASS
echo ""

# 确保用户名不为空
if [[ -z "$PROXY_USER" ]]; then
    echo "❌ Error: Username cannot be empty!"
    exit 1
fi

# 安装 Xray
install_xray() {
    echo "安装 Xray..."
    apt-get update -y
    apt-get install unzip -y || yum install unzip -y
    wget https://github.com/XTLS/Xray-core/releases/download/v1.8.3/Xray-linux-64.zip -O /tmp/Xray.zip
    unzip /tmp/Xray.zip -d /usr/local/bin/
    mv /usr/local/bin/xray /usr/local/bin/xrayL
    chmod +x /usr/local/bin/xrayL
    cat <<EOF >/etc/systemd/system/xrayL.service
[Unit]
Description=XrayL Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xrayL -c /etc/xrayL/config.json
Restart=on-failure
User=nobody
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable xrayL.service
    echo "Xray 安装完成."
}

# 获取 VPS 上的所有公网 IP
echo "[1/4] Detecting Public IPs..."
IP_LIST=$(hostname -I | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')

if [ -z "$IP_LIST" ]; then
    echo "❌ No public IPs detected! Exiting..."
    exit 1
fi

echo "✅ Found the following Public IPs:"
echo "$IP_LIST"

# 生成 Xray 配置文件
config_xray() {
    echo "[2/4] Configuring Xray..."
    mkdir -p /etc/xrayL
    CONFIG_JSON="{\"inbounds\": ["
    SOCKS5_PORT=$SOCKS5_START_PORT
    HTTP_PORT=$HTTP_START_PORT
    for ip in $IP_LIST; do
        CONFIG_JSON+="{\"port\": $SOCKS5_PORT, \"protocol\": \"socks\", \"settings\": {\"auth\": \"password\", \"accounts\": [{\"user\": \"$PROXY_USER\", \"pass\": \"$PROXY_PASS\"}]}, \"listen\": \"$ip\"},"
        CONFIG_JSON+="{\"port\": $HTTP_PORT, \"protocol\": \"http\", \"settings\": {\"auth\": \"password\", \"accounts\": [{\"user\": \"$PROXY_USER\", \"pass\": \"$PROXY_PASS\"}]}, \"listen\": \"$ip\"},"
        SOCKS5_PORT=$((SOCKS5_PORT + 1))
        HTTP_PORT=$((HTTP_PORT + 1))
    done
    CONFIG_JSON=${CONFIG_JSON%,}  # 移除最后的逗号
    CONFIG_JSON+=\"]}"  # 结束 inbounds
    echo -e "$CONFIG_JSON" > /etc/xrayL/config.json
}

# 启动 Xray 服务
start_xray() {
    echo "[3/4] Starting Xray..."
    systemctl restart xrayL.service || systemctl start xrayL.service
    sleep 2
    systemctl status xrayL.service --no-pager
}

# 开启防火墙端口
echo "[4/4] Opening firewall ports..."
SOCKS5_PORT=$SOCKS5_START_PORT
HTTP_PORT=$HTTP_START_PORT
for ip in $IP_LIST; do
    ufw allow $SOCKS5_PORT || true
    ufw allow $HTTP_PORT || true
    SOCKS5_PORT=$((SOCKS5_PORT + 1))
    HTTP_PORT=$((HTTP_PORT + 1))
done
ufw reload || true

# 执行安装和配置
install_xray
config_xray
start_xray

echo "======================================"
echo "✅ Proxy Setup Completed!"
echo "SOCKS5 Proxies:"
SOCKS5_PORT=$SOCKS5_START_PORT
for ip in $IP_LIST; do
    echo "  - socks5://$PROXY_USER:$PROXY_PASS@$ip:$SOCKS5_PORT"
    SOCKS5_PORT=$((SOCKS5_PORT + 1))
done

echo "HTTP Proxies:"
HTTP_PORT=$HTTP_START_PORT
for ip in $IP_LIST; do
    echo "  - http://$PROXY_USER:$PROXY_PASS@$ip:$HTTP_PORT"
    HTTP_PORT=$((HTTP_PORT + 1))
done
echo "======================================"
