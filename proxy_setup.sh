#!/bin/bash

# 默认配置
DEFAULT_SOCKS_PORT=20000  # SOCKS5 起始端口
DEFAULT_HTTP_PORT=30000   # HTTP 起始端口
DEFAULT_SOCKS_USERNAME="userb"
DEFAULT_SOCKS_PASSWORD="passwordb"
DEFAULT_HTTP_USERNAME="userb"
DEFAULT_HTTP_PASSWORD="passwordb"

IP_ADDRESSES=($(hostname -I))  # 获取所有 IP 地址

install_xray() {
    echo "安装 Xray..."
    apt-get update && apt-get install -y unzip curl
    wget https://github.com/XTLS/Xray-core/releases/download/v1.8.3/Xray-linux-64.zip
    unzip Xray-linux-64.zip
    mv xray /usr/local/bin/xrayL
    chmod +x /usr/local/bin/xrayL

    # 创建 Systemd 服务
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
    systemctl start xrayL.service
    echo "✅ Xray 安装完成."
}

config_xray() {
    mkdir -p /etc/xrayL

    # 配置 JSON
    cat <<EOF >/etc/xrayL/config.json
{
  "inbounds": [
EOF

    # 添加 SOCKS5 代理
    for ((i = 0; i < ${#IP_ADDRESSES[@]}; i++)); do
        PORT=$((DEFAULT_SOCKS_PORT + i))
        echo "    {\"port\": $PORT, \"protocol\": \"socks\", \"listen\": \"0.0.0.0\",
              \"settings\": {\"auth\": \"password\", \"accounts\": [{\"user\": \"$DEFAULT_SOCKS_USERNAME\", \"pass\": \"$DEFAULT_SOCKS_PASSWORD\"}]},
              \"tag\": \"socks_$i\"}," >> /etc/xrayL/config.json
        echo "✅ SOCKS5 代理已添加: socks5://$DEFAULT_SOCKS_USERNAME:$DEFAULT_SOCKS_PASSWORD@${IP_ADDRESSES[i]}:$PORT"
    done

    # 添加 HTTP 代理
    for ((i = 0; i < ${#IP_ADDRESSES[@]}; i++)); do
        PORT=$((DEFAULT_HTTP_PORT + i))
        echo "    {\"port\": $PORT, \"protocol\": \"http\", \"listen\": \"0.0.0.0\",
              \"settings\": {\"accounts\": [{\"user\": \"$DEFAULT_HTTP_USERNAME\", \"pass\": \"$DEFAULT_HTTP_PASSWORD\"}]},
              \"tag\": \"http_$i\"}," >> /etc/xrayL/config.json
        echo "✅ HTTP 代理已添加: http://$DEFAULT_HTTP_USERNAME:$DEFAULT_HTTP_PASSWORD@${IP_ADDRESSES[i]}:$PORT"
    done

    # 删除最后的逗号，避免 JSON 语法错误
    sed -i '$ s/,$//' /etc/xrayL/config.json

    # 继续写出bounds配置
    cat <<EOF >> /etc/xrayL/config.json
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" }
  ]
}
EOF

    systemctl restart xrayL.service
    systemctl --no-pager status xrayL.service
}

main() {
    [ -x "$(command -v xrayL)" ] || install_xray
    config_xray
}

main
