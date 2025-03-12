#!/bin/bash

# 默认参数
DEFAULT_SOCKS_PORT=22222                         # SOCKS5 端口
DEFAULT_HTTP_PORT=33333                          # HTTP 端口
DEFAULT_VLESS_PORT=44444                         # VLESS 端口
DEFAULT_SOCKS_USERNAME="userb"                    # 默认 SOCKS5 账号
DEFAULT_SOCKS_PASSWORD="passwordb"                # 默认 SOCKS5 密码
DEFAULT_WS_PATH="/ws"                             # 默认 WS 路径
DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid)   # 默认随机 UUID
IP_ADDRESS=$(hostname -I | awk '{print $1}')       # 获取单一 IP

install_xray() {
    echo "安装 Xray..."
    apt-get install unzip -y || yum install unzip -y
    wget https://github.com/XTLS/Xray-core/releases/download/v1.8.3/Xray-linux-64.zip
    unzip Xray-linux-64.zip
    mv xray /usr/local/bin/xrayL
    chmod +x /usr/local/bin/xrayL
    cat <<EOF >/etc/systemd/system/xrayL.service
[Unit]
Description=XrayL Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xrayL -c /etc/xrayL/config.toml
Restart=on-failure
User=nobody
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable xrayL.service
    systemctl start xrayL.service
    echo "Xray 安装完成."
}

config_xray() {
    mkdir -p /etc/xrayL
    read -p "SOCKS 账号 (默认 $DEFAULT_SOCKS_USERNAME): " SOCKS_USERNAME
    SOCKS_USERNAME=${SOCKS_USERNAME:-$DEFAULT_SOCKS_USERNAME}
    read -p "SOCKS 密码 (默认 $DEFAULT_SOCKS_PASSWORD): " SOCKS_PASSWORD
    SOCKS_PASSWORD=${SOCKS_PASSWORD:-$DEFAULT_SOCKS_PASSWORD}
    read -p "UUID (默认随机): " UUID
    UUID=${UUID:-$DEFAULT_UUID}
    read -p "WebSocket 路径 (默认 $DEFAULT_WS_PATH): " WS_PATH
    WS_PATH=${WS_PATH:-$DEFAULT_WS_PATH}

    config_content=""
    
    # SOCKS5 配置
    config_content+="[[inbounds]]\n"
    config_content+="port = $DEFAULT_SOCKS_PORT\n"
    config_content+="protocol = \"socks\"\n"
    config_content+="tag = \"socks\"\n"
    config_content+="[inbounds.settings]\n"
    config_content+="auth = \"password\"\n"
    config_content+="udp = true\n"
    config_content+="ip = \"$IP_ADDRESS\"\n"
    config_content+="[[inbounds.settings.accounts]]\n"
    config_content+="user = \"$SOCKS_USERNAME\"\n"
    config_content+="pass = \"$SOCKS_PASSWORD\"\n\n"
    
    # HTTP 代理配置
    config_content+="[[inbounds]]\n"
    config_content+="port = $DEFAULT_HTTP_PORT\n"
    config_content+="protocol = \"http\"\n"
    config_content+="tag = \"http\"\n"
    config_content+="[inbounds.settings]\n"
    config_content+="ip = \"$IP_ADDRESS\"\n\n"
    
    # VLESS 配置
    config_content+="[[inbounds]]\n"
    config_content+="port = $DEFAULT_VLESS_PORT\n"
    config_content+="protocol = \"vless\"\n"
    config_content+="tag = \"vless\"\n"
    config_content+="[inbounds.settings]\n"
    config_content+="[[inbounds.settings.clients]]\n"
    config_content+="id = \"$UUID\"\n"
    config_content+="flow = \"xtls-rprx-vision\"\n"
    config_content+="[inbounds.streamSettings]\n"
    config_content+="network = \"ws\"\n"
    config_content+="[inbounds.streamSettings.wsSettings]\n"
    config_content+="path = \"$WS_PATH\"\n\n"
    
    echo -e "$config_content" > /etc/xrayL/config.toml
    systemctl restart xrayL.service
    systemctl --no-pager status xrayL.service
    echo "\n配置完成:"
    echo "SOCKS5 端口: $DEFAULT_SOCKS_PORT"
    echo "HTTP 代理端口: $DEFAULT_HTTP_PORT"
    echo "VLESS 端口: $DEFAULT_VLESS_PORT"
    echo "UUID: $UUID"
    echo "WS路径: $WS_PATH"
}

main() {
    [ -x "$(command -v xrayL)" ] || install_xray
    config_xray
}

main
