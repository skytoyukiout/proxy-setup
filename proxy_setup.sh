#!/bin/bash

DEFAULT_SOCKS_START_PORT=20000
DEFAULT_HTTP_START_PORT=30000
DEFAULT_SOCKS_USERNAME="userb"
DEFAULT_SOCKS_PASSWORD="passwordb"
DEFAULT_HTTP_USERNAME="userh"
DEFAULT_HTTP_PASSWORD="passwordh"
DEFAULT_WS_PATH="/ws"
DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid)

IP_ADDRESSES=($(hostname -I))

install_dependencies() {
    echo "安装依赖..."
    apt update && apt install -y unzip net-tools
}

install_xray() {
    echo "安装 Xray..."
    wget -qO xray.zip https://github.com/XTLS/Xray-core/releases/download/v1.8.3/Xray-linux-64.zip
    unzip xray.zip -d xray_tmp && mv xray_tmp/xray /usr/local/bin/xrayL
    chmod +x /usr/local/bin/xrayL && rm -rf xray.zip xray_tmp

    cat <<EOF >/etc/systemd/system/xrayL.service
[Unit]
Description=XrayL Service
After=network.target

[Service]
ExecStart=/usr/local/bin/xrayL -c /etc/xrayL/config.json
Restart=always
RestartSec=5s
User=nobody
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable xrayL.service
    systemctl restart xrayL.service
    echo "Xray 安装完成."
}

check_port() {
    local port=$1
    if netstat -tulnp | grep -q ":$port "; then
        echo "端口 $port 已被占用，退出..."
        exit 1
    fi
}

config_xray() {
    mkdir -p /etc/xrayL
    
    read -p "输入 SOCKS5 代理用户名 (默认 $DEFAULT_SOCKS_USERNAME): " SOCKS_USERNAME
    SOCKS_USERNAME=${SOCKS_USERNAME:-$DEFAULT_SOCKS_USERNAME}
    read -p "输入 SOCKS5 代理密码 (默认 $DEFAULT_SOCKS_PASSWORD): " SOCKS_PASSWORD
    SOCKS_PASSWORD=${SOCKS_PASSWORD:-$DEFAULT_SOCKS_PASSWORD}
    read -p "输入 HTTP 代理用户名 (默认 $DEFAULT_HTTP_USERNAME): " HTTP_USERNAME
    HTTP_USERNAME=${HTTP_USERNAME:-$DEFAULT_HTTP_USERNAME}
    read -p "输入 HTTP 代理密码 (默认 $DEFAULT_HTTP_PASSWORD): " HTTP_PASSWORD
    HTTP_PASSWORD=${HTTP_PASSWORD:-$DEFAULT_HTTP_PASSWORD}
    
    config_content="{\n  \"inbounds\": ["
    
    for ((i = 0; i < ${#IP_ADDRESSES[@]}; i++)); do
        SOCKS_PORT=$((DEFAULT_SOCKS_START_PORT + i))
        HTTP_PORT=$((DEFAULT_HTTP_START_PORT + i))
        check_port $SOCKS_PORT
        check_port $HTTP_PORT
        
        config_content+="\n    {\n      \"port\": $SOCKS_PORT,\n      \"protocol\": \"socks\",\n      \"settings\": {\n        \"auth\": \"password\",\n        \"accounts\": [{\n          \"user\": \"$SOCKS_USERNAME\",\n          \"pass\": \"$SOCKS_PASSWORD\"\n        }]\n      },\n      \"tag\": \"socks_$((i+1))\"\n    },"
        
        config_content+="\n    {\n      \"port\": $HTTP_PORT,\n      \"protocol\": \"http\",\n      \"settings\": {\n        \"accounts\": [{\n          \"user\": \"$HTTP_USERNAME\",\n          \"pass\": \"$HTTP_PASSWORD\"\n        }]\n      },\n      \"tag\": \"http_$((i+1))\"\n    },"
    done
    
    config_content=${config_content%,}  # 移除最后的逗号
    config_content+="\n  ],\n  \"outbounds\": [{\"protocol\": \"freedom\", \"tag\": \"direct\"}]\n}"

    echo -e "$config_content" >/etc/xrayL/config.json
    systemctl restart xrayL.service
    echo "Xray 代理 (SOCKS5 + HTTP) 配置完成"
}

main() {
    install_dependencies
    [ -x "/usr/local/bin/xrayL" ] || install_xray
    config_xray
}

main
