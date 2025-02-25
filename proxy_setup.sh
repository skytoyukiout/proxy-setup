#!/bin/bash
# Xray 代理安装脚本 - 支持 HTTP & SOCKS5 代理
# 允许用户自定义用户名 & 密码
# 适用于 Ubuntu / Debian

set -e  # 遇到错误立即退出

# 默认端口
SOCKS5_START_PORT=20000
HTTP_START_PORT=30000

# 让用户输入代理的用户名和密码
read -p "Enter Proxy Username: " PROXY_USER
read -s -p "Enter Proxy Password: " PROXY_PASS

# 确保用户名和密码不为空
if [[ -z "$PROXY_USER" || -z "$PROXY_PASS" ]]; then
    echo "\n❌ Error: Username or password cannot be empty!"
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

# 获取 VPS 所有公网 IP
IP_LIST=$(hostname -I | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
if [ -z "$IP_LIST" ]; then
    echo "❌ No public IPs detected! Exiting..."
    exit 1
fi

echo "✅ Found the following Public IPs:"
echo "$IP_LIST"

# 生成 Xray 配置文件
config_xray() {
    echo "配置 Xray..."
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
    CONFIG_JSON+="]}"
    echo -e "$CONFIG_JSON" > /etc/xrayL/config.json
}

# 启动 Xray
start_xray() {
    echo "启动 Xray..."
    systemctl restart xrayL.service || systemctl start xrayL.service
    sleep 2
    systemctl status xrayL.service --no-pager
}

# 开启防火墙端口
echo "开启防火墙端口..."
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
