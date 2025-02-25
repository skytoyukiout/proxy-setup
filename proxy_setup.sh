#!/bin/bash

# 默认端口
SOCKS5_START_PORT=20000
HTTP_START_PORT=30000

# 默认用户名和密码
PROXY_USER="userb"
PROXY_PASS="passwordb"

# 获取 VPS 所有公网 IP
IP_ADDRESSES=($(hostname -I))

install_xray() {
    echo "安装 Xray..."
    apt-get update -y
    apt-get install unzip -y || yum install unzip -y
    wget -O /tmp/Xray.zip https://github.com/XTLS/Xray-core/releases/download/v1.8.3/Xray-linux-64.zip
    unzip /tmp/Xray.zip -d /usr/local/bin/
    mv /usr/local/bin/xray /usr/local/bin/xrayL
    chmod +x /usr/local/bin/xrayL

    # 创建 Systemd 服务
    cat <<EOF >/etc/systemd/system/xrayL.service
[Unit]
Description=XrayL Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xrayL -c /etc/xrayL/config.json
Restart=on-failure
User=root
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable xrayL.service
    echo "Xray 安装完成."
}

config_xray() {
    echo "配置 Xray..."
    mkdir -p /etc/xrayL

    # 生成 JSON 配置
    CONFIG_JSON="{\"inbounds\": ["
    SOCKS5_PORT=$SOCKS5_START_PORT
    HTTP_PORT=$HTTP_START_PORT

    for ip in "${IP_ADDRESSES[@]}"; do
        CONFIG_JSON+="{\"port\": $SOCKS5_PORT, \"protocol\": \"socks\", \"settings\": {\"auth\": \"password\", \"accounts\": [{\"user\": \"$PROXY_USER\", \"pass\": \"$PROXY_PASS\"}], \"udp\": true}, \"listen\": \"$ip\"},"
        CONFIG_JSON+="{\"port\": $HTTP_PORT, \"protocol\": \"http\", \"settings\": {\"auth\": \"password\", \"accounts\": [{\"user\": \"$PROXY_USER\", \"pass\": \"$PROXY_PASS\"}]}, \"listen\": \"$ip\"},"
        SOCKS5_PORT=$((SOCKS5_PORT + 1))
        HTTP_PORT=$((HTTP_PORT + 1))
    done

    CONFIG_JSON=${CONFIG_JSON%,}  # 移除最后的逗号
    CONFIG_JSON+="]}"

    echo -e "$CONFIG_JSON" > /etc/xrayL/config.json

    echo "✅ Xray 配置已生成！"
}

start_xray() {
    echo "启动 Xray..."
    systemctl restart xrayL.service
    sleep 2
    systemctl status xrayL.service --no-pager
}

open_firewall() {
    echo "开放防火墙端口..."
    ufw allow $SOCKS5_START_PORT
    ufw allow $HTTP_START_PORT
    ufw reload || true
}

# 执行安装和配置
install_xray
config_xray
open_firewall
start_xray

echo "======================================"
echo "✅ Proxy Setup Completed!"
echo "SOCKS5 Proxies:"
SOCKS5_PORT=$SOCKS5_START_PORT
for ip in "${IP_ADDRESSES[@]}"; do
    echo "  - socks5://$PROXY_USER:$PROXY_PASS@$ip:$SOCKS5_PORT"
    SOCKS5_PORT=$((SOCKS5_PORT + 1))
done

echo "HTTP Proxies:"
HTTP_PORT=$HTTP_START_PORT
for ip in "${IP_ADDRESSES[@]}"; do
    echo "  - http://$PROXY_USER:$PROXY_PASS@$ip:$HTTP_PORT"
    HTTP_PORT=$((HTTP_PORT + 1))
done

echo "======================================"
